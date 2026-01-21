// web/nutrisync/app/detail/[id]/page.tsx
import Link from "next/link";
import { notFound } from "next/navigation";
import type { Measurement } from "@/lib/types";
import { getMeasurementId } from "@/lib/types";
import MeasurementMap from "@/components/MeasurementMap";

const API_BASE =
  process.env.API_BASE_URL ||
  process.env.NEXT_PUBLIC_API_BASE_URL ||
  "http://localhost:8080";

async function getMeasurement(id: string): Promise<Measurement | null> {
  const res = await fetch(`${API_BASE}/api/measurements/${id}`, {
    cache: "no-store",
  });

  if (res.status === 404) return null;
  if (!res.ok) throw new Error(`Failed to fetch measurement: ${res.status}`);

  return res.json();
}

function fmtTime(ts?: string | null) {
  if (!ts) return "Tidak tersedia";
  const d = new Date(ts);
  if (Number.isNaN(d.getTime())) return ts;

  try {
    return new Intl.DateTimeFormat("id-ID", {
      dateStyle: "full",
      timeStyle: "medium",
    }).format(d);
  } catch {
    return d.toLocaleString();
  }
}

function fmtNum(v: number | null | undefined, maxFractionDigits = 1): string {
  if (v === null || v === undefined) return "N/A";
  if (Number.isNaN(v)) return "N/A";

  try {
    return new Intl.NumberFormat("id-ID", { maximumFractionDigits: maxFractionDigits }).format(v);
  } catch {
    return String(v);
  }
}

export default async function DetailPage({
  params,
}: {
  params: { id: string };
}) {
  const data = await getMeasurement(params.id);
  if (!data) notFound();

  const id = getMeasurementId(data);

  const lat = data.location?.latitude ?? null;
  const lon = data.location?.longitude ?? null;
  const hasCoord =
    typeof lat === "number" &&
    typeof lon === "number" &&
    !Number.isNaN(lat) &&
    !Number.isNaN(lon);

  const noteText = data.note?.trim() ? data.note.trim() : "Tidak ada";

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
          <div className="header-title__main">Detail Pengukuran</div>
          <div className="header-title__sub">
            Informasi lengkap satu data pengukuran
          </div>
        </div>

        <div className="header-actions">
          <Link className="btn" href="/">
            Kembali
          </Link>
        </div>
      </header>

      <main className="main-content">
        <div className="container">
          <div className="detail-grid">
            {/* KIRI: ringkasan + nilai sensor */}
            <section className="card card--pad">
              <h1 className="detail-title">Data Lengkap Pengukuran</h1>

              <dl className="kv">
                <div className="kv-row">
                  <dt>Oleh User</dt>
                  <dd>{data.user || "Tidak tersedia"}</dd>
                </div>

                <div className="kv-row">
                  <dt>ID Pengukuran</dt>
                  <dd className="kv-mono">{id || "Tidak tersedia"}</dd>
                </div>

                <div className="kv-row">
                  <dt>Waktu</dt>
                  <dd>{fmtTime(data.timestamp)}</dd>
                </div>
              </dl>

              <div className="note-box">
                <div className="note-label">Keterangan</div>
                <div className="note-text">{noteText}</div>
              </div>

              <div className="detail-section">
                <h2 className="section-title">Nilai NPK</h2>

                <div className="stats-grid stats-grid--3">
                  <div className="stat-card">
                    <div className="stat-label">Nitrogen (N)</div>
                    <div className="stat-value">{fmtNum(data.n, 1)}</div>
                    <div className="stat-unit">mg/kg</div>
                  </div>

                  <div className="stat-card">
                    <div className="stat-label">Phosfor (P)</div>
                    <div className="stat-value">{fmtNum(data.p, 1)}</div>
                    <div className="stat-unit">mg/kg</div>
                  </div>

                  <div className="stat-card">
                    <div className="stat-label">Kalium (K)</div>
                    <div className="stat-value">{fmtNum(data.k, 1)}</div>
                    <div className="stat-unit">mg/kg</div>
                  </div>
                </div>
              </div>

              <div className="detail-section">
                <h2 className="section-title">Sensor Lain</h2>

                <div className="stats-grid stats-grid--4">
                  <div className="stat-card">
                    <div className="stat-label">pH</div>
                    <div className="stat-value">{fmtNum(data.ph, 1)}</div>
                    <div className="stat-unit">pH</div>
                  </div>

                  <div className="stat-card">
                    <div className="stat-label">EC</div>
                    <div className="stat-value">{fmtNum(data.ec, 1)}</div>
                    <div className="stat-unit">µS/cm</div>
                  </div>

                  <div className="stat-card">
                    <div className="stat-label">Suhu</div>
                    <div className="stat-value">{fmtNum(data.temp, 1)}</div>
                    <div className="stat-unit">°C</div>
                  </div>

                  <div className="stat-card">
                    <div className="stat-label">Kelembaban</div>
                    <div className="stat-value">{fmtNum(data.hum, 0)}</div>
                    <div className="stat-unit">%</div>
                  </div>
                </div>
              </div>
            </section>

            {/* KANAN: lokasi + map */}
            <aside className="card card--pad">
              <div className="card-header">
                <h2 className="section-title">Lokasi</h2>
                <span className="muted">{hasCoord ? "Ada koordinat" : "Tidak ada koordinat"}</span>
              </div>

              <div className="location-name">
                {data.location_name || "Tidak tersedia"}
              </div>

              <div className="location-coord muted">
                Koordinat:{" "}
                {hasCoord ? (
                  <span className="kv-mono">
                    {lat}, {lon}
                  </span>
                ) : (
                  "-"
                )}
              </div>

              {hasCoord ? (
                <>
                  <div className="detail-map">
                    <MeasurementMap points={[data]} />
                  </div>

                  <div className="actions-row">
                    <a
                      className="btn btn-primary btn-link"
                      href={`https://www.google.com/maps?q=${lat},${lon}`}
                      target="_blank"
                      rel="noreferrer"
                    >
                      Buka Google Maps
                    </a>

                    <Link className="btn btn-link" href="/">
                      Kembali ke Dashboard
                    </Link>
                  </div>
                </>
              ) : (
                <div className="alert" style={{ marginTop: 12 }}>
                  Data ini tidak memiliki latitude/longitude, jadi peta tidak ditampilkan.
                </div>
              )}
            </aside>
          </div>
        </div>
      </main>
    </div>
  );
}
