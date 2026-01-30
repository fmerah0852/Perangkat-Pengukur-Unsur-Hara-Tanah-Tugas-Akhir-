import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider extends ChangeNotifier {
  String? _username;
  String? _serverUrl;

  String? get username => _username;
  String? get serverUrl => _serverUrl;

  bool get isLoggedIn => (_username != null && _username!.trim().isNotEmpty);

  AuthProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _username = prefs.getString('username');
    _serverUrl = prefs.getString('server_url');
    notifyListeners();
  }

  Future<void> login({
    required String username,
    required String serverUrl,
  }) async {
    final u = username.trim();
    final s = serverUrl.trim();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', u);
    await prefs.setString('server_url', s);

    _username = u;
    _serverUrl = s;
    notifyListeners();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('username');
    await prefs.remove('server_url'); // Hapus URL juga jika logout (opsional)

    _username = null;
    _serverUrl = null;
    notifyListeners();
  }
}