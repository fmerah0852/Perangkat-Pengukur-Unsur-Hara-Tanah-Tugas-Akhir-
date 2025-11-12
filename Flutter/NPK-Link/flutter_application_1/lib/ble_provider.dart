// lib/ble_provider.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'sensor_data.dart';
import 'package:geolocator/geolocator.dart';

// --- Konfigurasi dari kode ESP32 Anda ---
const String DEVICE_NAME = "ESP32_NPK_DUMMY";
const String SERVICE_UUID = "4fafc201-1fb5-459e-8fcc-c2c68c192200";
const String CHARACTERISTIC_UUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";
// GANTI DENGAN URL API DARI KUBERNETES/WEB SERVER ANDA
const String SERVER_URL = "http://guestbook.test/api/data"; // Contoh

class BleProvider with ChangeNotifier {
  BluetoothDevice? _connectedDevice;
  SensorData _currentData = SensorData.initial();
  final List<SensorData> _historyList = []; // Untuk menyimpan riwayat
  String _connectionStatus = "Disconnected";
  bool _isSyncing = false; // Status untuk tombol sync
  StreamSubscription<List<int>>? _dataSubscription;

  BluetoothDevice? get connectedDevice => _connectedDevice;
  SensorData get currentData => _currentData;
  List<SensorData> get historyList => _historyList;
  String get connectionStatus => _connectionStatus;
  bool get isSyncing => _isSyncing;

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
  Future<Map<String, dynamic>> _getCurrentLocation() async {
  bool serviceEnabled;
  LocationPermission permission;

  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    throw Exception('Location services are disabled.');
  }

  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      throw Exception('Location permissions are denied');
    }
  }

  if (permission == LocationPermission.deniedForever) {
    throw Exception('Location permissions are permanently denied.');
  } 

  Position position = await Geolocator.getCurrentPosition(
    desiredAccuracy: LocationAccuracy.high
  );

  return {
    'latitude': position.latitude,
    'longitude': position.longitude
  };
}

  Future<void> _discoverServices() async {
    if (_connectedDevice == null) return;
    
    _updateStatus("Discovering services...");
    try {
      List<BluetoothService> services = await _connectedDevice!.discoverServices();
      for (BluetoothService service in services) {
        if (service.uuid.toString() == SERVICE_UUID) {
          for (BluetoothCharacteristic characteristic in service.characteristics) {
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
  
  // Fungsi terpisah untuk memproses data
  void _onDataReceived(List<int> value) {
     String jsonString = utf8.decode(value);
     // print("Data Diterima: $jsonString"); // Untuk debug
      _currentData = SensorData.fromJsonString(jsonString);
      _historyList.add(_currentData); // Simpan ke riwayat
      notifyListeners(); // Beri tahu UI
  }

  Future<void> _subscribeToCharacteristic(BluetoothCharacteristic characteristic) async {
    await characteristic.setNotifyValue(true);
    _dataSubscription = characteristic.value.listen(_onDataReceived);
  }

  // --- Halaman 2: Fungsi Sync ke Server ---
  Future<String> syncDataToServer() async {
  if (_historyList.isEmpty) {
    return "Tidak ada data baru untuk dikirim.";
  }

  _isSyncing = true;
  notifyListeners();

  try {
    // 1. Ambil Lokasi GPS
    final Map<String, dynamic> location = await _getCurrentLocation();

    // 2. Ubah list data menjadi JSON array (sekarang menyertakan lokasi)
    String jsonBody = jsonEncode(
      _historyList.map((data) => data.toJson(location)).toList() // <-- Berikan lokasi
    );

    // 3. Kirim ke server
    final response = await http.post(
      Uri.parse(SERVER_URL),
      headers: {'Content-Type': 'application/json'},
      body: jsonBody,
    ).timeout(const Duration(seconds: 10));

    _isSyncing = false;
    if (response.statusCode == 200) {
      _historyList.clear(); 
      notifyListeners();
      return "Sinkronisasi berhasil!";
    } else {
      notifyListeners();
      return "Gagal mengirim: ${response.statusCode} ${response.body}";
    }
  } catch (e) {
    _isSyncing = false;
    notifyListeners();
    return "Error: $e"; // Ini akan menampilkan error jika izin lokasi ditolak
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
}