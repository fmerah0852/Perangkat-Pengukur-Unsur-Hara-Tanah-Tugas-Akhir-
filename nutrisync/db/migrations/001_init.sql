-- Aktifkan generator UUID (lebih mirip ObjectId versi string)
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS measurements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  user_name TEXT,

  n DOUBLE PRECISION,
  p DOUBLE PRECISION,
  k DOUBLE PRECISION,

  ph DOUBLE PRECISION,
  ec DOUBLE PRECISION,
  temp DOUBLE PRECISION,
  hum DOUBLE PRECISION,

  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  location_name TEXT,

 
  timestamp_text TEXT,
  timestamp_ts TIMESTAMPTZ,

  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index untuk mempercepat sorting "terbaru"
CREATE INDEX IF NOT EXISTS idx_measurements_sort
ON measurements ((COALESCE(timestamp_ts, created_at)));
