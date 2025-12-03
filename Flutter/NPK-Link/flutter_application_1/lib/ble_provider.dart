// lib/ble_provider.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io'; // untuk SocketException

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sensor_data.dart';

// --- Konfigurasi dari kode ESP32 Anda ---
const String DEVICE_NAME = "ESP32_NPK_DUMMY";
const String SERVICE_UUID = "4fafc201-1fb5-459e-8fcc-c2c68c192200";
const String CHARACTERISTIC_UUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

// URL API DARI KUBERNETES/WEB SERVER

const String SERVER_URL = "https://dioeciously-excogitable-karry.ngrok-free.dev/api/data";

class BleProvider with ChangeNotifier {
  BluetoothDevice? _connectedDevice;
  SensorData _currentData = SensorData.initial();
  final List<SensorData> _historyList = []; // Untuk menyimpan riwayat lokal
  String _connectionStatus = "Disconnected";
  bool _isSyncing = false; // Status untuk tombol sync
  StreamSubscription<List<int>>? _dataSubscription;

  static const String _historyPrefsKey = 'sensor_history';

  BluetoothDevice? get connectedDevice => _connectedDevice;
  SensorData get currentData => _currentData;
  List<SensorData> get historyList => _historyList;
  String get connectionStatus => _connectionStatus;
  bool get isSyncing => _isSyncing;

  /// Dipanggil sekali saat app mulai (di main.dart)
  Future<void> init() async {
    await _loadHistoryFromStorage();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
  }

  Future<void> scanAndConnect() async {
    await _requestPermissions();

    // Mencegah scan ganda jika sedang sibuk
    if (FlutterBluePlus.isScanningNow) return;

    _updateStatus("Scanning...");

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

      FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult r in results) {
          if (r.device.platformName == DEVICE_NAME) {
            FlutterBluePlus.stopScan();
            _connectToDevice(r.device);
            break;
          }
        }
      });
    } catch (e) {
      _updateStatus("Scan error: $e");
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    _updateStatus("Connecting...");

    device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.connected) {
        _connectedDevice = device;
        _updateStatus("Connected");
        _discoverServices();
      } else if (state == BluetoothConnectionState.disconnected) {
        _connectedDevice = null;
        _updateStatus("Disconnected");
        _dataSubscription?.cancel();
        _currentData = SensorData.initial();
        notifyListeners();
      }
    });

    try {
      await device.connect(autoConnect: false);
    } catch (e) {
      if (e.toString() != "already connected") {
        _updateStatus("Connection error: $e");
      }
    }
  }

  /// Ambil lokasi, tapi JANGAN pernah lempar error ke atas.
  /// Kalau gagal / timeout / permission ditolak → kembalikan latitude/longitude = null.
  Future<Map<String, dynamic>> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services are disabled. Kirim tanpa lokasi.');
        return {
          'latitude': null,
          'longitude': null,
        };
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permissions are denied. Kirim tanpa lokasi.');
          return {
            'latitude': null,
            'longitude': null,
          };
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('Location permissions permanently denied. Kirim tanpa lokasi.');
        return {
          'latitude': null,
          'longitude': null,
        };
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 20),
      );

      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
      };
    } on TimeoutException catch (e) {
      print('Timeout ambil lokasi: $e. Kirim tanpa lokasi.');
      return {
        'latitude': null,
        'longitude': null,
      };
    } catch (e) {
      print('Error ambil lokasi: $e. Kirim tanpa lokasi.');
      return {
        'latitude': null,
        'longitude': null,
      };
    }
  }

  Future<void> _discoverServices() async {
    if (_connectedDevice == null) return;

    _updateStatus("Discovering services...");
    try {
      List<BluetoothService> services =
          await _connectedDevice!.discoverServices();
      for (BluetoothService service in services) {
        if (service.uuid.toString() == SERVICE_UUID) {
          for (BluetoothCharacteristic characteristic
              in service.characteristics) {
            if (characteristic.uuid.toString() == CHARACTERISTIC_UUID) {
              _updateStatus("Connected"); // Sukses
              _subscribeToCharacteristic(characteristic);

              // Baca nilai terakhir (jika ada)
              final initialValue = await characteristic.read();
              if (initialValue.isNotEmpty) {
                _onDataReceived(initialValue);
              }
              return;
            }
          }
        }
      }
      _updateStatus("Sensor characteristic not found");
    } catch (e) {
      _updateStatus("Service discovery error: $e");
    }
  }

  // Fungsi terpisah untuk memproses data dari ESP32
  void _onDataReceived(List<int> value) {
    String jsonString = utf8.decode(value);

    _currentData = SensorData.fromJsonString(jsonString);
    notifyListeners(); // Update UI dashboard
  }

  Future<void> _subscribeToCharacteristic(
      BluetoothCharacteristic characteristic) async {
    await characteristic.setNotifyValue(true);
    _dataSubscription = characteristic.value.listen(_onDataReceived);
  }

  /// Sync data yang DIPILIH ke server
  Future<String> syncDataToServer(String username) async {
    final List<SensorData> selectedItems =
        _historyList.where((data) => data.isSelected).toList();

    if (selectedItems.isEmpty) {
      return "Tidak ada data yang dipilih.";
    }

    _isSyncing = true;
    notifyListeners();

    // Hitung estimasi waktu (hanya untuk log, bukan timeout beneran)
    const int baseSeconds = 10;
    const int extraPerItem = 5;
    int estimatedSeconds = baseSeconds + selectedItems.length * extraPerItem;
    if (estimatedSeconds < 10) estimatedSeconds = 10;
    if (estimatedSeconds > 60) estimatedSeconds = 60;

    try {
      final Map<String, dynamic> location = await _getCurrentLocation();

      // Encode data dengan menyertakan LOKASI dan USERNAME
      final List<Map<String, dynamic>> payloadList = selectedItems
          .map((data) => data.toJson(location, username))
          .toList();

      String jsonBody = jsonEncode(payloadList);

      final uri = Uri.parse(SERVER_URL);
      print(
          "🔁 Sync ke $uri, items: ${selectedItems.length}, estimasi proses server: ~${estimatedSeconds}s");
      print("📦 Payload: $jsonBody");

      // ⛔ TANPA .timeout DI SINI – biarkan error asli muncul
      final http.Response response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',},
        body: jsonBody,
      );

      print(
          "✅ Response status: ${response.statusCode}, body: ${response.body}");

      if (response.statusCode == 200) {
        // Hapus data yang sudah terkirim
        _historyList.removeWhere((data) => data.isSelected);
        await _saveHistoryToStorage();
        notifyListeners();
        return "Sinkronisasi ${selectedItems.length} data berhasil!";
      } else {
        return "Gagal mengirim: ${response.statusCode} ${response.body}";
      }
    } on SocketException catch (e) {
      print("🌐 SocketException saat sync: $e");
      return "Tidak bisa terhubung ke server ($SERVER_URL): $e";
    } on TimeoutException catch (e) {
      print("⏱ TimeoutException (di luar HTTP.post): $e");
      return "Timeout: server tidak merespons dalam waktu wajar.\n"
          "Coba kirim lebih sedikit data atau pastikan koneksi stabil.";
    } on FormatException catch (e) {
      print("🧩 FormatException (JSON): $e");
      return "Error format data saat mengirim (JSON): $e";
    } catch (e) {
      print("❌ Error umum saat sync: $e");
      return "Error saat sync: $e";
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  void _updateStatus(String status) {
    _connectionStatus = status;
    notifyListeners();
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    _connectedDevice?.disconnect();
    super.dispose();
  }

  // --- FUNGSI UNTUK RIWAYAT ---

  /// Simpan data sensor saat ini ke riwayat lokal (HP)
  void saveCurrentDataToHistory() {
    if (_currentData.temp == 0.0 &&
        _currentData.n == 0.0 &&
        _currentData.ec == 0.0) {
      print("Data sensor masih kosong, tidak disimpan.");
      return;
    }

    _historyList.insert(0, _currentData);
    print("Data disimpan ke riwayat. Total riwayat: ${_historyList.length}");
    _saveHistoryToStorage();
    notifyListeners();
  }

  /// Toggle checkbox item riwayat
  void toggleItemSelection(int index) {
    if (index < 0 || index >= _historyList.length) return;

    _historyList[index].isSelected = !_historyList[index].isSelected;
    _saveHistoryToStorage();
    notifyListeners();
  }

  /// Hapus semua data yang dipilih
  void deleteSelectedHistory() {
    _historyList.removeWhere((data) => data.isSelected);
    _saveHistoryToStorage();
    notifyListeners();
  }

  /// Hapus 1 data berdasarkan index
  void deleteByIndex(int index) {
    if (index < 0 || index >= _historyList.length) return;
    _historyList.removeAt(index);
    _saveHistoryToStorage();
    notifyListeners();
  }

  // --- PERSISTENCE: SIMPAN & LOAD RIWAYAT KE STORAGE ---

  Future<void> _loadHistoryFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_historyPrefsKey);
    if (raw == null) return;

    try {
      final List decoded = jsonDecode(raw) as List;
      _historyList
        ..clear()
        ..addAll(
          decoded
              .map(
                (e) => SensorData.fromLocalJson(
                  e as Map<String, dynamic>,
                ),
              )
              .toList(),
        );
      notifyListeners();
    } catch (e) {
      print("Gagal load history dari storage: $e");
    }
  }

  Future<void> _saveHistoryToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final String raw = jsonEncode(
      _historyList.map((d) => d.toLocalJson()).toList(),
    );
    await prefs.setString(_historyPrefsKey, raw);
  }
}
