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

  // lokasi yang disimpan saat tombol "Simpan Data" ditekan
  final double? latitude;
  final double? longitude;

  bool isSelected;
  String? note;

  SensorData({
    required this.timestamp,
    this.temp = 0.0,
    this.hum = 0.0,
    this.ec = 0.0,
    this.ph = 0.0,
    this.n = 0.0,
    this.p = 0.0,
    this.k = 0.0,
    this.latitude,
    this.longitude,
    this.isSelected = false,
    this.note,
  });

  /// Membuat object dari data JSON string (dari BLE)
  factory SensorData.fromJsonString(String jsonString) {
    try {
      final Map<String, dynamic> json = jsonDecode(jsonString);
      return SensorData(
        timestamp: DateTime.now(),
        temp: (json['temp'] as num?)?.toDouble() ?? 0.0,
        hum: (json['hum'] as num?)?.toDouble() ?? 0.0,
        ec: (json['ec'] as num?)?.toDouble() ?? 0.0,
        ph: (json['ph'] as num?)?.toDouble() ?? 0.0,
        n: (json['n'] as num?)?.toDouble() ?? 0.0,
        p: (json['p'] as num?)?.toDouble() ?? 0.0,
        k: (json['k'] as num?)?.toDouble() ?? 0.0,
        latitude: null,
        longitude: null,
      );
    } catch (e) {
      // ignore: avoid_print
      print("Error parsing JSON: $e");
      return SensorData.initial();
    }
  }

  factory SensorData.initial() => SensorData(timestamp: DateTime.now());

  /// JSON untuk server
  /// ✅ UPDATE: Menambahkan parameter projectName
  Map<String, dynamic> toJson(String username, {String? projectName}) {
    final String cleanedNote = (note ?? '').trim();
    final String cleanedProject = (projectName ?? '').trim();

    return {
      'timestamp': timestamp.toUtc().toIso8601String(),
      'temp': temp,
      'hum': hum,
      'ec': ec,
      'ph': ph,
      'n': n,
      'p': p,
      'k': k,
      'location': {
        'latitude': latitude,
        'longitude': longitude,
      },
      'user': username,
      // Jika project name diisi, kirim ke server
      if (cleanedProject.isNotEmpty) 'project_name': cleanedProject,
      if (cleanedNote.isNotEmpty) 'note': cleanedNote,
    };
  }

  /// JSON untuk penyimpanan lokal (SharedPreferences)
  Map<String, dynamic> toLocalJson() {
    final String cleanedNote = (note ?? '').trim();

    return {
      'timestamp': timestamp.toIso8601String(),
      'temp': temp,
      'hum': hum,
      'ec': ec,
      'ph': ph,
      'n': n,
      'p': p,
      'k': k,
      'latitude': latitude,
      'longitude': longitude,
      'isSelected': isSelected,
      if (cleanedNote.isNotEmpty) 'note': cleanedNote,
    };
  }

  factory SensorData.fromLocalJson(Map<String, dynamic> json) {
    final String? rawNote = json['note'] as String?;
    final String? cleaned =
        rawNote == null ? null : rawNote.trim().isEmpty ? null : rawNote.trim();

    final latRaw = json['latitude'];
    final lonRaw = json['longitude'];

    final double? lat = latRaw is num ? latRaw.toDouble() : null;
    final double? lon = lonRaw is num ? lonRaw.toDouble() : null;

    return SensorData(
      timestamp: DateTime.parse(json['timestamp'] as String),
      temp: (json['temp'] as num).toDouble(),
      hum: (json['hum'] as num).toDouble(),
      ec: (json['ec'] as num).toDouble(),
      ph: (json['ph'] as num).toDouble(),
      n: (json['n'] as num).toDouble(),
      p: (json['p'] as num).toDouble(),
      k: (json['k'] as num).toDouble(),
      latitude: lat,
      longitude: lon,
      isSelected: json['isSelected'] as bool? ?? false,
      note: cleaned,
    );
  }
}