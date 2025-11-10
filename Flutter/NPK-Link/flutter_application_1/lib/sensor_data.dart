// lib/sensor_data.dart
import 'dart:convert';

class SensorData {
  final DateTime timestamp; // DITAMBAHKAN
  final double temp;
  final double hum;
  final double ec;
  final double ph;
  final double n;
  final double p;
  final double k;

  SensorData({
    required this.timestamp, // DITAMBAHKAN
    this.temp = 0.0,
    this.hum = 0.0,
    this.ec = 0.0,
    this.ph = 0.0,
    this.n = 0.0,
    this.p = 0.0,
    this.k = 0.0,
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
    );
  }
  
  // Fungsi untuk mengubah data menjadi JSON (untuk dikirim ke server)
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(), // Format standar untuk server
      'temp': temp,
      'hum': hum,
      'ec': ec,
      'ph': ph,
      'n': n,
      'p': p,
      'k': k,
    };
  }
}