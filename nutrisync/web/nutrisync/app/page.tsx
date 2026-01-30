"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import Link from "next/link";
import type { DashboardResponse, Measurement } from "@/lib/types";
import { getMeasurementId, safeNumber } from "@/lib/types";
import MeasurementMap from "@/components/MeasurementMap";

// --- Helpers ---
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
  try {
    return new Intl.DateTimeFormat("id-ID", {
      dateStyle: "medium",
      timeStyle: "short",
    }).format(new Date(ts));
  } catch { return ts; }
}

function getTimeMs(m: Measurement): number {
  const ts = m.timestamp ?? m.created_at ?? null;
  return ts ? Date.parse(ts) : 0;
}

// Helper hitung rata-rata
const avg = (arr: number[]) => (arr.length === 0 ? null : arr.reduce((a, b) => a + b, 0) / arr.length);

// Tipe untuk baris tabel
type DashboardRow = {
  type: "single" | "project";
  id: string; // ID data atau Nama Project
  title: string;
  subtitle: string;
  timestamp: string | null;
  
  // Nilai (bisa raw atau avg)
  n: number | null;
  p: number | null;
  k: number | null;
  ph: number | null;
  
  // Lokasi (Strict number agar tidak error di map/perhitungan)
  location: { latitude: number; longitude: number } | null;
  location_name: string;

  // Khusus project
  count: number;
};

export default function DashboardPage() {
  const abortRef = useRef<AbortController | null>(null);
  const [rawData, setRawData] = useState<Measurement[]>([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [q, setQ] = useState("");

  // Load Data
  async function load(isRefresh = false) {
    abortRef.current?.abort();
    const controller = new AbortController();
    abortRef.current = controller;

    try {
      if (isRefresh) setRefreshing(true); else setLoading(true);
      const base = resolveApiBase();
      const res = await fetch(`${base}/api/measurements`, { cache: "no-store", signal: controller.signal });
      if (!res.ok) throw new Error("Gagal mengambil data");
      
      const json = await res.json();
      let items: Measurement[] = [];
      if (Array.isArray(json)) items = json;
      else if (json && typeof json === "object") {
        const obj = json as DashboardResponse;
        items = (obj.dataList ?? obj.data_list) || [];
      }
      setRawData(items);
    } catch (e: any) {
      if (e.name !== "AbortError") console.error(e);
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }

  useEffect(() => { load(); }, []);

  // --- LOGIKA UTAMA PENGELOMPOKAN ---
  const tableData = useMemo<DashboardRow[]>(() => {
    const groups: Record<string, Measurement[]> = {};
    const singles: Measurement[] = [];

    // 1. Pisahkan: Masuk grup projek atau single?
    for (const m of rawData) {
      const pName = m.project_name?.trim();
      if (pName) {
        if (!groups[pName]) groups[pName] = [];
        groups[pName].push(m);
      } else {
        singles.push(m);
      }
    }

    const rows: DashboardRow[] = [];

    // 2. Masukkan Single Data ke baris
    for (const m of singles) {
      // ✅ FIX: Cek tipe data number secara eksplisit & buat object baru
      // Ini mengatasi error "Type 'Location | null' is not assignable..."
      const hasLoc = 
        typeof m.location?.latitude === 'number' && 
        typeof m.location?.longitude === 'number';

      rows.push({
        type: "single",
        id: getMeasurementId(m),
        title: m.user || "User Tanpa Nama",
        subtitle: "Individual",
        timestamp: m.timestamp || null,
        n: m.n ?? null,
        p: m.p ?? null,
        k: m.k ?? null,
        ph: m.ph ?? null,
        // Jika valid, buat object baru {lat, lon}. Jika tidak, null.
        location: hasLoc 
          ? { latitude: m.location!.latitude!, longitude: m.location!.longitude! } 
          : null,
        location_name: m.location_name || "",
        count: 1,
      });
    }

    // 3. Masukkan Group Project (DIRATA-RATA) ke baris
    for (const [name, items] of Object.entries(groups)) {
      // Ambil data terbaru untuk timestamp
      const sorted = [...items].sort((a, b) => getTimeMs(b) - getTimeMs(a));
      const latest = sorted[0];

      // Hitung Rata-rata
      const avgN = avg(items.map(i => i.n ?? 0));
      const avgP = avg(items.map(i => i.p ?? 0));
      const avgK = avg(items.map(i => i.k ?? 0));
      const avgPh = avg(items.map(i => i.ph ?? 0));

      // Hitung Rata-rata Lokasi (untuk map)
      const locs = items.filter(i => 
        typeof i.location?.latitude === 'number' && 
        typeof i.location?.longitude === 'number'
      );
      
      let avgLoc = null;
      if (locs.length > 0) {
        avgLoc = {
          latitude: locs.reduce((s, i) => s + (i.location!.latitude!), 0) / locs.length,
          longitude: locs.reduce((s, i) => s + (i.location!.longitude!), 0) / locs.length,
        };
      }

      rows.push({
        type: "project",
        id: name, // ID baris adalah nama projek
        title: name,
        subtitle: `Projek (${items.length} Data)`,
        timestamp: latest.timestamp || null,
        n: avgN, 
        p: avgP,
        k: avgK,
        ph: avgPh,
        location: avgLoc,
        location_name: items[0].location_name || "Beragam",
        count: items.length,
      });
    }

    // 4. Urutkan gabungan (Projek & Single) berdasarkan waktu terbaru
    return rows.sort((a, b) => {
      const tA = a.timestamp ? Date.parse(a.timestamp) : 0;
      const tB = b.timestamp ? Date.parse(b.timestamp) : 0;
      return tB - tA;
    });
  }, [rawData]);

  // Filter Pencarian
  const filtered = useMemo(() => {
    const s = q.trim().toLowerCase();
    if (!s) return tableData;
    return tableData.filter(row => 
      row.title.toLowerCase().includes(s) || 
      row.location_name.toLowerCase().includes(s)
    );
  }, [tableData, q]);

  // Siapkan data untuk Peta
  const mapPoints = useMemo(() => {
    return filtered.filter(r => r.location).map(r => ({
      id: r.id,
      user: r.type === "project" ? `Projek: ${r.title}` : r.title,
      location_name: r.location_name,
      timestamp: r.timestamp,
      n: r.n, p: r.p, k: r.k, ph: r.ph,
      location: r.location, // Ini aman karena r.location sudah dipastikan {lat: number, lon: number}
      note: r.type === "project" ? "Titik Tengah (Rata-rata)" : undefined
    } as Measurement));
  }, [filtered]);

  return (
    <div className="grid-container">
      <aside className="sidebar">
        <div className="sidebar-title">NutriSync</div>
        <ul className="sidebar-menu">
          <li className="active"><span className="material-icons-outlined">dashboard</span>Dashboard</li>
        </ul>
      </aside>

      <header className="header">
        <div className="header-title">
          <div className="header-title__main">Dashboard Monitoring</div>
          <div className="header-title__sub">Ringkasan Projek & Data Individual</div>
        </div>
        <div className="header-actions">
          <button className="btn" onClick={() => load(true)} disabled={loading || refreshing}>
            {refreshing ? "Refreshing..." : "Refresh"}
          </button>
        </div>
      </header>

      <main className="main-content">
        <div className="container">
          
          {/* KPI Cards */}
          <div className="kpi-grid">
            <div className="kpi-card">
              <div className="kpi-icon"><span className="material-icons-outlined">folder</span></div>
              <div className="kpi-text">
                <h3>Total Item</h3>
                <div className="value">{tableData.length}</div>
              </div>
            </div>
            <div className="kpi-card">
              <div className="kpi-icon"><span className="material-icons-outlined">analytics</span></div>
              <div className="kpi-text">
                <h3>Projek Aktif</h3>
                <div className="value">{tableData.filter(d => d.type === 'project').length}</div>
              </div>
            </div>
          </div>

          {/* Map */}
          <section className="card card--pad">
            <h2 className="section-title">Peta Sebaran</h2>
            <MeasurementMap points={mapPoints} />
          </section>

          {/* TABEL UTAMA */}
          <section className="card card--pad">
            <div className="filter-row" style={{marginBottom: 16}}>
               <input value={q} onChange={e => setQ(e.target.value)} className="input" placeholder="Cari Projek / User..." />
            </div>

            <div className="table-scroll">
              <table>
                <thead>
                  <tr>
                    <th>Nama / Projek</th>
                    <th>Tipe</th>
                    <th>Waktu (Terbaru)</th>
                    <th>pH (Avg)</th>
                    <th>N (Avg)</th>
                    <th>P (Avg)</th>
                    <th>K (Avg)</th>
                    <th>Aksi</th>
                  </tr>
                </thead>
                <tbody>
                  {filtered.length === 0 ? (
                    <tr><td colSpan={8} style={{textAlign:'center', padding: 20}}>Tidak ada data</td></tr>
                  ) : filtered.map((row, idx) => (
                    <tr key={idx} style={row.type === 'project' ? {backgroundColor: '#f0f9ff'} : {}}>
                      <td>
                        <div style={{fontWeight: 'bold', color: row.type === 'project' ? '#0284c7' : '#334155'}}>
                          {row.type === 'project' && <span className="material-icons-outlined" style={{fontSize: 14, verticalAlign: 'middle', marginRight: 5}}>folder</span>}
                          {row.title}
                        </div>
                        <div style={{fontSize: 11, color: '#64748b'}}>{row.location_name}</div>
                      </td>
                      <td>
                        {row.type === 'project' 
                          ? <span style={{fontSize: 11, background: '#0ea5e9', color: 'white', padding: '2px 8px', borderRadius: 10}}>PROJEK ({row.count})</span>
                          : <span style={{fontSize: 11, color: '#94a3b8'}}>Single</span>
                        }
                      </td>
                      <td>{fmtTime(row.timestamp)}</td>
                      
                      {/* Nilai Avg / Raw */}
                      <td>{safeNumber(row.ph, 1)}</td>
                      <td>{safeNumber(row.n, 0)}</td>
                      <td>{safeNumber(row.p, 0)}</td>
                      <td>{safeNumber(row.k, 0)}</td>

                      <td>
                        {row.type === 'project' ? (
                          <Link href={`/project/${encodeURIComponent(row.id)}`} className="btn" style={{fontSize: 12, padding: '6px 12px'}}>
                            Buka Projek
                          </Link>
                        ) : (
                          <Link href={`/detail/${row.id}`} className="detail-btn">
                            Detail
                          </Link>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </section>

        </div>
      </main>
    </div>
  );
}