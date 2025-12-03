// lib/pages/login_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth_provider.dart';
import '../main.dart'; // Untuk akses MainNavigator

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _userController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.eco, size: 80, color: Colors.green),
            const SizedBox(height: 20),
            const Text(
              "NutriSync Login",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _userController,
              decoration: const InputDecoration(
                labelText: "Masukkan Nama / NIM",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (_userController.text.isNotEmpty) {
                  // Simpan user ke provider
                  Provider.of<AuthProvider>(context, listen: false)
                      .login(_userController.text);
                  
                  // Pindah ke Dashboard
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const MainNavigator()),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text("MASUK", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}