"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import Link from "next/link";
import type { DashboardResponse, Measurement } from "@/lib/types";
import { getMeasurementId, safeNumber } from "@/lib/types";
import MeasurementMap from "@/components/MeasurementMap";

/**
 * Kenapa sebelumnya 404?
 * Kalau fetch pakai "/api/measurements", Next.js akan cari route internal Next (yang tidak ada),
 * sehingga response 404.
 *
 * Solusi: arahkan fetch ke backend Golang (port 8080) secara aman.
 * - Kalau NEXT_PUBLIC_API_BASE_URL ada -> pakai itu
 * - Kalau tidak -> otomatis pakai hostname yang sama dengan web, tapi port 8080
 *   (contoh: web di http://localhost:3000 => api di http://localhost:8080)
 */
function resolveApiBase(): string {
  const envBase = (process.env.NEXT_PUBLIC_API_BASE_URL ?? "").trim();
  if (envBase) return envBase.replace(/\/$/, "");

  if (typeof window !== "undefined") {
    const { protocol, hostname } = window.location;
    return `${protocol}//${hostname}:8080`;
  }

  return "http://localhost:8080";
}

function fmtTime(ts?: string | null) {
  if (!ts) return "-";
  const d = new Date(ts);
  if (Number.isNaN(d.getTime())) return ts;
  try {
    return new Intl.DateTimeFormat("id-ID", {
      dateStyle: "medium",
      timeStyle: "short",
    }).format(d);
  } catch {
    return d.toLocaleString();
  }
}

function getTimeMs(m: Measurement): number {
  const ts = m.timestamp ?? m.created_at ?? null;
  if (!ts) return 0;
  const ms = Date.parse(ts);
  return Number.isNaN(ms) ? 0 : ms;
}

function normalizeMeasurements(json: any): { items: Measurement[]; total?: number } {
  // Backend bisa balikin array langsung
  if (Array.isArray(json)) return { items: json };

  // atau wrapper object
  if (json && typeof json === "object") {
    const obj = json as DashboardResponse;
    const list = (obj.dataList ?? obj.data_list) as any;
    const total = (obj.totalCount ?? obj.total_count) as any;

    return {
      items: Array.isArray(list) ? list : [],
      total: typeof total === "number" ? total : undefined,
    };
  }

  return { items: [] };
}

function useDebouncedValue<T>(value: T, delay = 250) {
  const [debounced, setDebounced] = useState(value);
  useEffect(() => {
    const t = setTimeout(() => setDebounced(value), delay);
    return () => clearTimeout(t);
  }, [value, delay]);
  return debounced;
}

export default function DashboardPage() {
  const abortRef = useRef<AbortController | null>(null);

  const [data, setData] = useState<Measurement[]>([]);
  const [serverTotal, setServerTotal] = useState<number | null>(null);

  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  const [q, setQ] = useState("");
  const qDebounced = useDebouncedValue(q, 250);

  const [onlyHasLocation, setOnlyHasLocation] = useState(false);

  async function load(isRefresh = false) {
    abortRef.current?.abort();
    const controller = new AbortController();
    abortRef.current = controller;

    try {
      if (isRefresh) setRefreshing(true);
      else setLoading(true);

      setErr(null);

      const base = resolveApiBase();
      const res = await fetch(`${base}/api/measurements`, {
        cache: "no-store",
        signal: controller.signal,
      });

      if (!res.ok) {
        // bantu debug cepat: tampilkan URL yang dipanggil
        throw new Error(`Fetch failed: ${res.status} (${base}/api/measurements)`);
      }

      const json = await res.json();
      const normalized = normalizeMeasurements(json);

      setData(normalized.items);
      setServerTotal(typeof normalized.total === "number" ? normalized.total : null);
    } catch (e: any) {
      if (e?.name === "AbortError") return;
      setErr(e?.message ?? String(e));
      setData([]);
      setServerTotal(null);
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }

  useEffect(() => {
    load(false);
    return () => abortRef.current?.abort();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const sorted = useMemo(() => {
    const copy = [...data];
    copy.sort((a, b) => getTimeMs(b) - getTimeMs(a));
    return copy;
  }, [data]);

  const filtered = useMemo(() => {
    const s = qDebounced.trim().toLowerCase();

    return sorted.filter((m) => {
      if (onlyHasLocation) {
        const lat = m.location?.latitude;
        const lon = m.location?.longitude;
        if (!(typeof lat === "number" && typeof lon === "number")) return false;
      }

      if (!s) return true;

      const id = (getMeasurementId(m) || "").toLowerCase();
      const user = (m.user ?? "").toLowerCase();
      const time = (m.timestamp ?? "").toLowerCase();
      const loc = (m.location_name ?? "").toLowerCase();
      const note = (m.note ?? "").toLowerCase();

      const n = String(m.n ?? "").toLowerCase();
      const p = String(m.p ?? "").toLowerCase();
      const k = String(m.k ?? "").toLowerCase();

      return (
        id.includes(s) ||
        user.includes(s) ||
        time.includes(s) ||
        loc.includes(s) ||
        note.includes(s) ||
        n.includes(s) ||
        p.includes(s) ||
        k.includes(s)
      );
    });
  }, [sorted, qDebounced, onlyHasLocation]);

  const latest = filtered[0] ?? null;

  const pointsWithCoord = useMemo(() => {
    return filtered.filter(
      (m) =>
        typeof m.location?.latitude === "number" &&
        typeof m.location?.longitude === "number"
    );
  }, [filtered]);

  const totalShown = serverTotal ?? data.length;

  return (
    <div className="grid-container">
      <aside className="sidebar">
        <div className="sidebar-title">NutriSync</div>
        <ul className="sidebar-menu">
          <li className="active">
            <span className="material-icons-outlined">dashboard</span>
            Dashboard
          </li>
        </ul>
      </aside>

      <header className="header">
        <div className="header-title">
          <div className="header-title__main">Dashboard</div>
          <div className="header-title__sub">
            Monitoring pengukuran NPK, pH, EC, suhu, kelembapan
          </div>
        </div>

        <div className="header-actions">
          <button className="btn" onClick={() => load(true)} disabled={loading || refreshing}>
            {refreshing ? "Refreshing..." : "Refresh"}
          </button>
        </div>
      </header>

      <main className="main-content">
        <div className="container">
          {/* KPI */}
          <div className="kpi-grid">
            <div className="kpi-card">
              <div className="kpi-icon">
                {/* pakai icon yang pasti ada */}
                <span className="material-icons-outlined">storage</span>
              </div>
              <div className="kpi-text">
                <h3>Total Data</h3>
                <div className="value">{totalShown}</div>
              </div>
            </div>

            <div className="kpi-card">
              <div className="kpi-icon">
                <span className="material-icons-outlined">filter_alt</span>
              </div>
              <div className="kpi-text">
                <h3>Hasil Filter</h3>
                <div className="value">{filtered.length}</div>
              </div>
            </div>

            <div className="kpi-card">
              <div className="kpi-icon">
                <span className="material-icons-outlined">update</span>
              </div>
              <div className="kpi-text">
                <h3>Data Terbaru</h3>
                <div className="value">{latest ? "Ada" : "Tidak ada"}</div>
              </div>
            </div>

            <div className="kpi-card">
              <div className="kpi-icon">
                <span className="material-icons-outlined">schedule</span>
              </div>
              <div className="kpi-text">
                <h3>Waktu Terbaru</h3>
                <div className="value value-sm">{latest ? fmtTime(latest.timestamp) : "-"}</div>
              </div>
            </div>
          </div>

          {/* Filter */}
          <section className="card card--pad">
            <div className="filter-row">
              <div className="filter-search">
                <input
                  value={q}
                  onChange={(e) => setQ(e.target.value)}
                  className="input"
                  placeholder="Cari (nama / waktu / lokasi / NPK / keterangan)"
                  aria-label="Cari data"
                />
                {q ? (
                  <button className="btn" onClick={() => setQ("")}>
                    Clear
                  </button>
                ) : null}
              </div>

              <label className="filter-toggle">
                <input
                  type="checkbox"
                  checked={onlyHasLocation}
                  onChange={(e) => setOnlyHasLocation(e.target.checked)}
                />
                Hanya yang punya lokasi
              </label>
            </div>

            <div className="muted filter-info">
              Menampilkan <strong>{filtered.length}</strong> dari{" "}
              <strong>{totalShown}</strong> data • Titik berkoordinat:{" "}
              <strong>{pointsWithCoord.length}</strong>
            </div>
          </section>

          {/* Map */}
          <section className="card card--pad">
            <div className="card-header">
              <h2 className="section-title">Peta Sebaran Titik Pengukuran</h2>
              <div className="muted">{pointsWithCoord.length} titik</div>
            </div>
            <MeasurementMap points={pointsWithCoord} />
          </section>

          {/* Table */}
          <section className="card card--pad">
            <div className="card-header">
              <h2 className="section-title">Riwayat Pengukuran</h2>
              {loading ? <span className="muted">Memuat...</span> : null}
            </div>

            {err ? (
              <div className="alert alert-error">
                <strong>Gagal mengambil data.</strong>
                <div style={{ marginTop: 6 }}>{err}</div>
                <div style={{ marginTop: 10 }}>
                  <button className="btn" onClick={() => load(true)}>
                    Coba lagi
                  </button>
                </div>
              </div>
            ) : filtered.length === 0 ? (
              <div className="alert">
                Tidak ada data untuk ditampilkan.
              </div>
            ) : (
              <div className="table-scroll">
                <table>
                  <thead>
                    <tr>
                      <th>Nama</th>
                      <th>Waktu</th>
                      <th>Lokasi</th>
                      <th>N</th>
                      <th>P</th>
                      <th>K</th>
                      <th>Aksi</th>
                    </tr>
                  </thead>
                  <tbody>
                    {filtered.map((m, idx) => {
                      const id = getMeasurementId(m);
                      const key = id || `${m.timestamp ?? "row"}-${idx}`;

                      return (
                        <tr key={key}>
                          <td>{m.user || "Tidak tersedia"}</td>
                          <td>{fmtTime(m.timestamp)}</td>
                          <td>{m.location_name || "Tidak tersedia"}</td>
                          <td>{safeNumber(m.n)}</td>
                          <td>{safeNumber(m.p)}</td>
                          <td>{safeNumber(m.k)}</td>
                          <td>
                            {id ? (
                              <Link className="detail-btn" href={`/detail/${id}`}>
                                Lihat
                              </Link>
                            ) : (
                              <span className="muted">-</span>
                            )}
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            )}
          </section>
        </div>
      </main>
    </div>
  );
}
