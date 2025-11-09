from flask import Flask, request, jsonify, render_template
from flask_cors import CORS
from sqlalchemy import create_engine, text
import datetime

app = Flask(__name__)
CORS(app)

# === DATABASE ===
engine = create_engine("sqlite:///measurements.db", echo=False)

# Buat tabel jika belum ada
with engine.begin() as conn:
    conn.execute(text("""
        CREATE TABLE IF NOT EXISTS measurements (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            device_id TEXT,
            ts INTEGER,
            n REAL, p REAL, k REAL,
            lat REAL, lon REAL
        )
    """))

# === API ENDPOINT ===
@app.post("/api/measurements")
def upload():
    data = request.get_json(force=True)
    items = data.get("items", [])
    with engine.begin() as conn:
        for it in items:
            conn.execute(text("""
                INSERT INTO measurements (device_id, ts, n, p, k, lat, lon)
                VALUES (:device_id, :ts, :n, :p, :k, :lat, :lon)
            """), it)
    return jsonify({"status": "ok"}), 200

@app.get("/api/measurements")
def get_all():
    with engine.connect() as conn:
        result = conn.execute(text("SELECT * FROM measurements ORDER BY ts DESC"))
        rows = [dict(r._mapping) for r in result]
    return jsonify(rows)

# === DASHBOARD WEB ===
@app.get("/")
def dashboard():
    with engine.connect() as conn:
        result = conn.execute(text("SELECT * FROM measurements ORDER BY ts DESC LIMIT 100"))
        rows = [dict(r._mapping) for r in result]

        # Format waktu biar lebih enak dibaca
        for r in rows:
            r["time_str"] = datetime.datetime.fromtimestamp(r["ts"]/1000).strftime("%Y-%m-%d %H:%M:%S")

    return render_template("dashboard.html", data=rows)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
