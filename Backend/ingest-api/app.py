import os
from flask import Flask, request, jsonify, render_template
from pymongo import MongoClient, DESCENDING
from bson import ObjectId

app = Flask(__name__)

# --- Konfigurasi MongoDB (Sama seperti sebelumnya) ---
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
# ----------------------------------------------------


# --- Endpoint 1: Menerima Data dari Flutter (Sama seperti sebelumnya) ---
@app.route('/api/data', methods=['POST'])
def receive_data():
    try:
        data_list = request.get_json()
        if not isinstance(data_list, list):
            return jsonify({"error": "Expected a list of data points"}), 400

        result = collection.insert_many(data_list)
        return jsonify({"status": "success", "received": len(result.inserted_ids)}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# --- Endpoint 2: Halaman Dashboard (Web untuk Dosen) ---
@app.route('/', methods=['GET'])
def get_dashboard():
    try:
        # 1. Ambil semua data, urutkan dari yang terbaru
        all_data = list(collection.find().sort("timestamp", DESCENDING))
        
        # 2. Ambil data terbaru (untuk kartu KPI)
        latest_data = {}
        if all_data:
            latest_data = all_data[0] # Ambil data pertama (terbaru)

        # 3. Ambil total data
        total_count = len(all_data)

        # 4. Konversi _id ke string untuk tabel
        for item in all_data:
            item['_id'] = str(item['_id'])
            
        # 5. Kirim semua data ke template baru 'dashboard.html'
        return render_template(
            'dashboard.html', 
            data_list=all_data,
            latest=latest_data, # Data terbaru untuk KPI
            total_count=total_count # Total data untuk KPI
        )
    except Exception as e:
        return str(e)

# --- Endpoint 3: Halaman Detail (Web untuk Dosen) ---
@app.route('/detail/<id>', methods=['GET'])
def get_measurement_detail(id):
    try:
        data = collection.find_one({"_id": ObjectId(id)})
        if not data:
            return "Data not found", 404
            
        return render_template('detail.html', data=data)
    except Exception as e:
        return str(e)


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)