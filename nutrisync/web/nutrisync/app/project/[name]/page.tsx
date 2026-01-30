"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useParams } from "next/navigation";
import type { Measurement, DashboardResponse } from "@/lib/types";
import { safeNumber, getMeasurementId } from "@/lib/types";

// Helpers
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
    return new Intl.DateTimeFormat("id-ID", { dateStyle: "medium", timeStyle: "medium" }).format(new Date(ts));
  } catch { return ts; }
}

const avg = (arr: number[]) => (arr.length === 0 ? 0 : arr.reduce((a, b) => a + b, 0) / arr.length);

export default function ProjectDetailPage() {
  const params = useParams();
  const projectName = decodeURIComponent(params.name as string);

  const [items, setItems] = useState<Measurement[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function loadData() {
      try {
        const base = resolveApiBase();
        const res = await fetch(`${base}/api/measurements`, { cache: "no-store" });
        if (!res.ok) throw new Error("Gagal");
        
        const json = await res.json();
        let allData: Measurement[] = [];
        if (Array.isArray(json)) allData = json;
        else if (json && typeof json === 'object') {
           const obj = json as DashboardResponse;
           allData = (obj.dataList ?? obj.data_list) || [];
        }

        // 1. Ambil HANYA data milik projek ini
        const projectItems = allData.filter(m => m.project_name?.trim() === projectName);

        // 2. Urutkan dari terbaru
        projectItems.sort((a, b) => {
          const tA = a.timestamp ? Date.parse(a.timestamp) : 0;
          const tB = b.timestamp ? Date.parse(b.timestamp) : 0;
          return tB - tA;
        });

        setItems(projectItems);
      } catch (e) {
        console.error(e);
      } finally {
        setLoading(false);
      }
    }
    loadData();
  }, [projectName]);

  // HITUNG RATA-RATA UNTUK BAGIAN ATAS
  const stats = {
    ph: avg(items.map(i => i.ph ?? 0).filter(v => v > 0)),
    n: avg(items.map(i => i.n ?? 0)),
    p: avg(items.map(i => i.p ?? 0)),
    k: avg(items.map(i => i.k ?? 0)),
    ec: avg(items.map(i => i.ec ?? 0)),
    temp: avg(items.map(i => i.temp ?? 0)),
  };

  if (loading) return <div className="main-content"><div className="container">Memuat Data Projek...</div></div>;

  return (
    <div className="main-content">
      <div className="container">
        
        {/* Tombol Kembali */}
        <div style={{marginBottom: 16}}>
          <Link href="/" className="btn" style={{textDecoration: 'none', display: 'inline-flex', alignItems: 'center', gap: 6}}>
            <span className="material-icons-outlined" style={{fontSize: 16}}>arrow_back</span> 
            Kembali ke Dashboard
          </Link>
        </div>

        {/* HEADER PROJEK & STATISTIK RATA-RATA */}
        <section className="card card--pad" style={{marginBottom: 24, borderTop: '4px solid #0ea5e9'}}>
          <h1 className="detail-title" style={{color: '#0f172a'}}>📁 Projek: {projectName}</h1>
          <div className="muted">Terdapat {items.length} data pengukuran dalam projek ini.</div>
          
          <div style={{marginTop: 20}}>
            <h3 style={{fontSize: 16, marginBottom: 10, fontWeight: 'bold'}}>Rata-rata (Global) Projek Ini:</h3>
            <div className="stats-grid stats-grid--4">
              <div className="stat-card">
                <div className="stat-label">Rata-rata pH</div>
                <div className="stat-value" style={{color: '#e11d48'}}>{safeNumber(stats.ph, 2)}</div>
              </div>
              <div className="stat-card">
                <div className="stat-label">Rata-rata N</div>
                <div className="stat-value" style={{color: '#16a34a'}}>{safeNumber(stats.n, 0)}</div>
                <div className="stat-unit">mg/kg</div>
              </div>
              <div className="stat-card">
                <div className="stat-label">Rata-rata P</div>
                <div className="stat-value" style={{color: '#2563eb'}}>{safeNumber(stats.p, 0)}</div>
                <div className="stat-unit">mg/kg</div>
              </div>
              <div className="stat-card">
                <div className="stat-label">Rata-rata K</div>
                <div className="stat-value" style={{color: '#d97706'}}>{safeNumber(stats.k, 0)}</div>
                <div className="stat-unit">mg/kg</div>
              </div>
            </div>
          </div>

          {items[0]?.note && (
             <div className="note-box" style={{marginTop: 15}}>
               <div className="note-label">Catatan Terakhir:</div>
               <div className="note-text">{items[0].note}</div>
             </div>
          )}
        </section>

        {/* TABEL DATA MENTAH (INDIVIDU) */}
        <section className="card card--pad">
          <div className="card-header">
            <h2 className="section-title">Rincian Data Pengukuran (Raw Data)</h2>
          </div>
          <div className="table-scroll">
            <table>
              <thead>
                <tr>
                  <th>Waktu</th>
                  <th>Lokasi</th>
                  <th>pH</th>
                  <th>N</th>
                  <th>P</th>
                  <th>K</th>
                  <th>EC</th>
                  <th>Suhu</th>
                  <th>Aksi</th>
                </tr>
              </thead>
              <tbody>
                {items.map((m, idx) => (
                  <tr key={idx}>
                    <td>{fmtTime(m.timestamp)}</td>
                    <td>{m.location_name || "-"}</td>
                    {/* Nilai Raw per baris */}
                    <td>{safeNumber(m.ph, 1)}</td>
                    <td>{safeNumber(m.n, 0)}</td>
                    <td>{safeNumber(m.p, 0)}</td>
                    <td>{safeNumber(m.k, 0)}</td>
                    <td>{safeNumber(m.ec, 0)}</td>
                    <td>{safeNumber(m.temp, 1)}°C</td>
                    <td>
                      <Link href={`/detail/${getMeasurementId(m)}`} className="detail-btn">
                        Lihat Full
                      </Link>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>

      </div>
    </div>
  );
}