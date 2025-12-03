// lib/auth_provider.dart
import 'package:flutter/material.dart';

class AuthProvider with ChangeNotifier {
  String? _currentUser;

  bool get isLoggedIn => _currentUser != null && _currentUser!.isNotEmpty;
  String get currentUser => _currentUser ?? "Unknown";

  void login(String username) {
    _currentUser = username;
    notifyListeners();
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }
}