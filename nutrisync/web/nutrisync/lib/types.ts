// web/nutrisync/lib/types.ts

export type Location = {
  latitude: number | null;
  longitude: number | null;
};

export type Measurement = {
  // ✅ kompatibel: backend bisa kirim "id" atau "_id"
  id?: string;
  _id?: string;

  user?: string | null;
  timestamp?: string | null;

  n?: number | null;
  p?: number | null;
  k?: number | null;

  ph?: number | null;
  ec?: number | null;
  temp?: number | null;
  hum?: number | null;

  location?: Location | null;
  location_name?: string | null;

  // ✅ fitur baru: keterangan dari Flutter
  note?: string | null;
  
  // ✅ fitur baru: Grouping Projek
  project_name?: string | null;

  // opsional kalau backend mengirim
  created_at?: string | null;
};

export type DashboardResponse = {
  // kompatibel: bisa snake_case atau camelCase
  total_count?: number;
  totalCount?: number;

  latest?: Measurement | null;

  data_list?: Measurement[];
  dataList?: Measurement[];
};

export function getMeasurementId(m: Measurement): string {
  return (m.id ?? m._id ?? "").toString();
}

export function safeNumber(v: number | null | undefined, decimals = 1): string {
  if (v === null || v === undefined) return "N/A";
  if (Number.isNaN(v)) return "N/A";
  // Jika bulat, jangan pakai desimal. Jika pecahan, pakai fixed.
  if (Number.isInteger(v)) return String(v);
  return v.toFixed(decimals);
}