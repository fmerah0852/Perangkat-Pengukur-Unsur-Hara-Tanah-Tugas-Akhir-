import os
import requests
from flask import Flask, request, jsonify, render_template
from pymongo import MongoClient, DESCENDING
from bson import ObjectId

app = Flask(__name__)

# --- Konfigurasi MongoDB ---
MONGO_HOST = os.environ.get('MONGO_HOST', 'mongo-service')
MONGO_PORT = int(os.environ.get('MONGO_PORT', 27017))
MONGO_USER = os.environ.get('MONGO_USER', 'root')
MONGO_PASS = os.environ.get('MONGO_PASS', 'rootpass')
MONGO_DB = "nutrisync_db"
MONGO_COLLECTION = "measurements"

mongo_uri = f"mongodb://{MONGO_USER}:{MONGO_PASS}@{MONGO_HOST}:{MONGO_PORT}/?authSource=admin"
client = MongoClient(mongo_uri)
db = client[MONGO_DB]
collection = db[MONGO_COLLECTION]


# 🔹 Fungsi untuk mengubah lat,lon menjadi nama tempat
def get_place_name(lat, lon):
    try:
        url = "https://nominatim.openstreetmap.org/reverse"
        params = {
            "format": "jsonv2",
            "lat": lat,
            "lon": lon
        }
        headers = {
            "User-Agent": "nutrisync-ta/1.0"
        }
        resp = requests.get(url, params=params, headers=headers, timeout=5)
        if resp.status_code == 200:
            data = resp.json()
            return data.get("display_name")
    except Exception as e:
        print("Reverse geocode error:", e)
    return None


# --- Endpoint 1: Menerima Data dari Flutter ---
@app.route('/api/data', methods=['POST'])
def receive_data():
    try:
        data_list = request.get_json()

        if not data_list:
            return jsonify({"error": "Empty payload"}), 400

        # Boleh kirim 1 objek atau list objek
        if isinstance(data_list, dict):
            data_list = [data_list]
        elif not isinstance(data_list, list):
            return jsonify({"error": "Expected a list of data points"}), 400

        enriched_list = []
        for data in data_list:
            if not isinstance(data, dict):
                continue

            # 🔹 Normalisasi nama field user
            #    Terima 'user' atau 'username' dari Flutter, tapi di DB disimpan sebagai 'user'
            username = data.get("user") or data.get("username")
            if username:
                data["user"] = username

            # 🔹 Enrich: tambahkan location_name untuk tiap data
            loc = data.get("location") or {}
            lat = loc.get("latitude")
            lon = loc.get("longitude")

            if isinstance(lat, (int, float)) and isinstance(lon, (int, float)):
                place = get_place_name(lat, lon)
                if place:
                    data["location_name"] = place

            enriched_list.append(data)

        if not enriched_list:
            return jsonify({"error": "No valid data points to insert"}), 400

        result = collection.insert_many(enriched_list)
        return jsonify({
            "status": "success",
            "received": len(result.inserted_ids)
        }), 200

    except Exception as e:
        print("Error in /api/data:", e)
        return jsonify({"error": str(e)}), 500


# --- Endpoint 2: Halaman Dashboard ---
@app.route('/', methods=['GET'])
def get_dashboard():
    try:
        all_data = list(collection.find().sort("timestamp", DESCENDING))

        latest_data = {}
        if all_data:
            latest_data = all_data[0]

        total_count = len(all_data)

        # Konversi _id ke string agar aman dipakai di template/link
        for item in all_data:
            item["_id"] = str(item["_id"])

        return render_template(
            'dashboard.html',
            data_list=all_data,
            latest=latest_data,
            total_count=total_count
        )
    except Exception as e:
        print("Error in dashboard:", e)
        return str(e), 500


# --- Endpoint 3: Halaman Detail ---
@app.route('/detail/<id>', methods=['GET'])
def get_measurement_detail(id):
    try:
        data = collection.find_one({"_id": ObjectId(id)})
        if not data:
            return "Data not found", 404

        # konversi _id ke string supaya rapi di HTML
        data["_id"] = str(data["_id"])

        # Pastikan selalu ada field 'user' jika hanya 'username' yang tersimpan
        if "username" in data and "user" not in data:
            data["user"] = data["username"]

        return render_template('detail.html', data=data)
    except Exception as e:
        print("Error in detail:", e)
        return str(e), 500


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
