// lib/ble_provider.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sensor_data.dart';

// --- Konfigurasi dari ESP32 ---
const String DEVICE_NAME = "ESP32_NPK_DUMMY";
const String SERVICE_UUID = "4fafc201-1fb5-459e-8fcc-c2c68c192200";
const String CHARACTERISTIC_UUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

class BleProvider with ChangeNotifier {
  BluetoothDevice? _connectedDevice;
  SensorData _currentData = SensorData.initial();

  final List<SensorData> _historyList = [];
  String _connectionStatus = "Disconnected";

  bool _isSyncing = false;
  bool _isSaving = false;

  StreamSubscription<List<int>>? _dataSubscription;
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;

  static const String _historyPrefsKey = 'sensor_history';

  BluetoothDevice? get connectedDevice => _connectedDevice;
  SensorData get currentData => _currentData;
  List<SensorData> get historyList => _historyList;
  String get connectionStatus => _connectionStatus;

  bool get isSyncing => _isSyncing;
  bool get isSaving => _isSaving;

  // ... (Bagian init, scanAndConnect, _connectToDevice, _getCurrentLocation, _discoverServices, _onDataReceived tidak berubah)
  
  // PERHATIKAN: Saya menyingkat kode di atas agar fokus, pastikan kode fungsi di atas tetap ada
  // Kita langsung ke method init dan bagian bawah

  Future<void> init() async {
    await _loadHistoryFromStorage();
  }
  
  // ... (fungsi-fungsi bluetooth dan lokasi biarkan tetap sama) ...
  // Paste ulang saja fungsi-fungsi: _requestPermissions, scanAndConnect, _connectToDevice, _getCurrentLocation, 
  // _discoverServices, _onDataReceived, _subscribeToCharacteristic dari file lama Anda jika perlu, 
  // atau langsung ganti bagian syncDataToServer di bawah ini:

  Future<void> _requestPermissions() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
  }

  Future<void> scanAndConnect() async {
    await _requestPermissions();
    if (FlutterBluePlus.isScanningNow) return;
    _updateStatus("Scanning...");
    await _scanSub?.cancel();
    _scanSub = null;
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
      _scanSub = FlutterBluePlus.scanResults.listen((results) async {
        for (final r in results) {
          if (r.device.platformName == DEVICE_NAME) {
            await FlutterBluePlus.stopScan();
            await _scanSub?.cancel();
            _scanSub = null;
            await _connectToDevice(r.device);
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
    await _connSub?.cancel();
    _connSub = null;
    _connSub = device.connectionState.listen((state) async {
      if (state == BluetoothConnectionState.connected) {
        _connectedDevice = device;
        _updateStatus("Connected");
        await _discoverServices();
      } else if (state == BluetoothConnectionState.disconnected) {
        _connectedDevice = null;
        _updateStatus("Disconnected");
        await _dataSubscription?.cancel();
        _dataSubscription = null;
        _currentData = SensorData.initial();
        notifyListeners();
      }
    });
    try {
      await device.connect(autoConnect: false);
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (!msg.contains("already connected")) {
        _updateStatus("Connection error: $e");
      }
    }
  }

  Future<Map<String, dynamic>> _getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return {'latitude': null, 'longitude': null};
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return {'latitude': null, 'longitude': null};
      }
      if (permission == LocationPermission.deniedForever) return {'latitude': null, 'longitude': null};
      try {
        final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high, timeLimit: const Duration(seconds: 15));
        return {'latitude': position.latitude, 'longitude': position.longitude};
      } on TimeoutException {
        try {
          final last = await Geolocator.getLastKnownPosition();
          if (last != null) return {'latitude': last.latitude, 'longitude': last.longitude};
        } catch (_) {}
        return {'latitude': null, 'longitude': null};
      }
    } catch (_) {
      return {'latitude': null, 'longitude': null};
    }
  }

  Future<void> _discoverServices() async {
    final device = _connectedDevice;
    if (device == null) return;
    _updateStatus("Discovering services...");
    try {
      final services = await device.discoverServices();
      for (final service in services) {
        if (service.uuid.toString() != SERVICE_UUID) continue;
        for (final ch in service.characteristics) {
          if (ch.uuid.toString() != CHARACTERISTIC_UUID) continue;
          _updateStatus("Connected");
          await _subscribeToCharacteristic(ch);
          final initialValue = await ch.read();
          if (initialValue.isNotEmpty) _onDataReceived(initialValue);
          return;
        }
      }
      _updateStatus("Sensor characteristic not found");
    } catch (e) {
      _updateStatus("Service discovery error: $e");
    }
  }

  void _onDataReceived(List<int> value) {
    try {
      final jsonString = utf8.decode(value, allowMalformed: true).trim();
      if (jsonString.isEmpty) return;
      _currentData = SensorData.fromJsonString(jsonString);
      notifyListeners();
    } catch (e) {
      print("Error decode BLE data: $e");
    }
  }

  Future<void> _subscribeToCharacteristic(BluetoothCharacteristic characteristic) async {
    await _dataSubscription?.cancel();
    _dataSubscription = null;
    await characteristic.setNotifyValue(true);
    _dataSubscription = characteristic.value.listen(_onDataReceived);
  }

  /// ✅ UPDATE: Sync data dengan projectName
  Future<String> syncDataToServer(String username, String baseUrl, String projectName) async {
    final selectedItems = _historyList.where((d) => d.isSelected).toList();
    if (selectedItems.isEmpty) return "Tidak ada data yang dipilih.";

    if (baseUrl.isEmpty) return "URL Server belum diatur. Silakan login ulang.";

    _isSyncing = true;
    notifyListeners();

    try {
      // Masukkan projectName ke setiap item JSON
      final payloadList = selectedItems.map((d) => d.toJson(username, projectName: projectName)).toList();
      final jsonBody = jsonEncode(payloadList);

      final uri = Uri.parse(baseUrl);

      final response = await http.post(
        uri,
        headers: const {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonBody,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _historyList.removeWhere((d) => d.isSelected);
        await _saveHistoryToStorage();
        notifyListeners();
        return "Berhasil membuat projek '$projectName' dengan ${selectedItems.length} data!";
      }

      return "Gagal mengirim: ${response.statusCode} ${response.body}";
    } on SocketException catch (e) {
      return "Tidak bisa terhubung ke server ($baseUrl): $e";
    } on FormatException catch (e) {
      return "Error format data/URL: $e";
    } catch (e) {
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
    _scanSub?.cancel();
    _connSub?.cancel();
    _connectedDevice?.disconnect();
    super.dispose();
  }

  // --- RIWAYAT ---

  bool _isCurrentDataEmpty() {
    return _currentData.temp == 0.0 && _currentData.n == 0.0 && _currentData.ec == 0.0;
  }

  Future<String> saveCurrentDataToHistory() async {
    if (_isCurrentDataEmpty()) return "Data kosong, tidak disimpan.";
    if (_isSaving) return "Sedang menyimpan...";
    _isSaving = true;
    notifyListeners();
    SensorData snapshot;
    String message;
    try {
      final loc = await _getCurrentLocation();
      final latRaw = loc['latitude'];
      final lonRaw = loc['longitude'];
      final double? lat = latRaw is num ? latRaw.toDouble() : null;
      final double? lon = lonRaw is num ? lonRaw.toDouble() : null;
      snapshot = SensorData(
        timestamp: DateTime.now(),
        temp: _currentData.temp,
        hum: _currentData.hum,
        ec: _currentData.ec,
        ph: _currentData.ph,
        n: _currentData.n,
        p: _currentData.p,
        k: _currentData.k,
        latitude: lat,
        longitude: lon,
        isSelected: false,
        note: _currentData.note,
      );
      message = (lat != null && lon != null) ? "Data disimpan beserta lokasi." : "Data disimpan (lokasi tidak tersedia).";
    } catch (e) {
      snapshot = SensorData(
        timestamp: DateTime.now(),
        temp: _currentData.temp,
        hum: _currentData.hum,
        ec: _currentData.ec,
        ph: _currentData.ph,
        n: _currentData.n,
        p: _currentData.p,
        k: _currentData.k,
        latitude: null,
        longitude: null,
        isSelected: false,
        note: _currentData.note,
      );
      message = "Data disimpan, tapi gagal mengambil lokasi: $e";
    }
    _historyList.insert(0, snapshot);
    await _saveHistoryToStorage();
    notifyListeners();
    _isSaving = false;
    notifyListeners();
    return message;
  }

  void toggleItemSelection(int index) {
    if (index < 0 || index >= _historyList.length) return;
    _historyList[index].isSelected = !_historyList[index].isSelected;
    _saveHistoryToStorage();
    notifyListeners();
  }

  void deleteSelectedHistory() {
    _historyList.removeWhere((d) => d.isSelected);
    _saveHistoryToStorage();
    notifyListeners();
  }

  void deleteByIndex(int index) {
    if (index < 0 || index >= _historyList.length) return;
    _historyList.removeAt(index);
    _saveHistoryToStorage();
    notifyListeners();
  }

  void updateNoteByIndex(int index, String? note) {
    if (index < 0 || index >= _historyList.length) return;
    final cleaned = note?.trim();
    _historyList[index].note = (cleaned == null || cleaned.isEmpty) ? null : cleaned;
    _saveHistoryToStorage();
    notifyListeners();
  }

  void setNoteForSelected(String? note) {
    final cleaned = (note ?? '').trim();
    if (cleaned.isEmpty) return;
    bool changed = false;
    for (final d in _historyList) {
      if (d.isSelected) {
        d.note = cleaned;
        changed = true;
      }
    }
    if (changed) {
      _saveHistoryToStorage();
      notifyListeners();
    }
  }

  Future<void> _loadHistoryFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyPrefsKey);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw) as List;
      _historyList..clear()..addAll(decoded.map((e) => SensorData.fromLocalJson(e as Map<String, dynamic>)));
      notifyListeners();
    } catch (e) {
      print("Gagal load history dari storage: $e");
    }
  }

  Future<void> _saveHistoryToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_historyList.map((d) => d.toLocalJson()).toList());
    await prefs.setString(_historyPrefsKey, raw);
  }
}