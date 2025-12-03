// lib/sensor_data.dart
import 'dart:convert';

class SensorData {
  final DateTime timestamp;
  final double temp;
  final double hum;
  final double ec;
  final double ph;
  final double n;
  final double p;
  final double k;
  bool isSelected;

  SensorData({
    required this.timestamp,
    this.temp = 0.0,
    this.hum = 0.0,
    this.ec = 0.0,
    this.ph = 0.0,
    this.n = 0.0,
    this.p = 0.0,
    this.k = 0.0,
    this.isSelected = false,
  });

  // Factory constructor untuk membuat instance dari JSON string ESP32
  factory SensorData.fromJsonString(String jsonString) {
    try {
      final Map<String, dynamic> json = jsonDecode(jsonString);
      return SensorData(
        timestamp: DateTime.now(), // Set timestamp saat data diterima
        temp: (json['temp'] as num?)?.toDouble() ?? 0.0,
        hum: (json['hum'] as num?)?.toDouble() ?? 0.0,
        ec: (json['ec'] as num?)?.toDouble() ?? 0.0,
        ph: (json['ph'] as num?)?.toDouble() ?? 0.0,
        n: (json['n'] as num?)?.toDouble() ?? 0.0,
        p: (json['p'] as num?)?.toDouble() ?? 0.0,
        k: (json['k'] as num?)?.toDouble() ?? 0.0,
        isSelected: false,
      );
    } catch (e) {
      print("Error parsing JSON: $e");
      return SensorData.initial(); // Kembalikan data default jika ada error parsing
    }
  }

  // State awal (data kosong)
  factory SensorData.initial() {
    return SensorData(
      timestamp: DateTime.now(),
      temp: 0.0, hum: 0.0, ec: 0.0, ph: 0.0, n: 0.0, p: 0.0, k: 0.0,
      isSelected: false,
    );
  }
  
  // --- FUNGSI INI YANG DIUBAH ---
  // Fungsi untuk mengubah data menjadi JSON untuk dikirim ke server
  // Sekarang menerima 'location' DAN 'username'
  Map<String, dynamic> toJson(Map<String, dynamic> location, String username) { 
    return {
      'timestamp': timestamp.toIso8601String(),
      'temp': temp,
      'hum': hum,
      'ec': ec,
      'ph': ph,
      'n': n,
      'p': p,
      'k': k,
      'location': location, 
      'user': username, // <--- Username ditambahkan di sini
    };
  }

  // --- Fungsi Lokal (Tidak Perlu Diubah) ---
  // Menyimpan ke penyimpanan lokal HP (SharedPreferences/SQLite)
  Map<String, dynamic> toLocalJson() {
    return {
      'n': n,
      'p': p,
      'k': k,
      'ph': ph,
      'temp': temp,
      'ec': ec,
      'hum': hum,
      'timestamp': timestamp.toIso8601String(),
      'isSelected': isSelected,
    };
  }

  // Memuat dari penyimpanan lokal HP
  factory SensorData.fromLocalJson(Map<String, dynamic> json) {
    return SensorData(
      n: (json['n'] as num).toDouble(),
      p: (json['p'] as num).toDouble(),
      k: (json['k'] as num).toDouble(),
      ph: (json['ph'] as num).toDouble(),
      temp: (json['temp'] as num).toDouble(),
      ec: (json['ec'] as num).toDouble(),
      hum: (json['hum'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      isSelected: json['isSelected'] as bool? ?? false,
    );
  }
}