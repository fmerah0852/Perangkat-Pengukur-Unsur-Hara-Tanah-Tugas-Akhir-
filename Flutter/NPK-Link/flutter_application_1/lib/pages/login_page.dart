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
  final TextEditingController _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Opsional: Pre-fill URL jika sudah pernah login sebelumnya
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.serverUrl != null) {
        _urlController.text = auth.serverUrl!;
      }
      if (auth.username != null) {
        _userController.text = auth.username!;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView( // Tambahkan scroll agar tidak overflow saat keyboard muncul
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 60),
              const Icon(Icons.eco, size: 80, color: Colors.green),
              const SizedBox(height: 20),
              const Text(
                "NutriSync Login",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
              // INPUT NAMA
              TextField(
                controller: _userController,
                decoration: const InputDecoration(
                  labelText: "Masukkan Nama / NIM",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
              // INPUT URL SERVER
              TextField(
                controller: _urlController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: "Server URL (API Endpoint)",
                  hintText: "https://your-api.ngrok-free.app/api/data",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  final user = _userController.text;
                  final url = _urlController.text;

                  if (user.isNotEmpty && url.isNotEmpty) {
                    // Simpan user & URL ke provider
                    Provider.of<AuthProvider>(context, listen: false)
                        .login(username: user, serverUrl: url);
                    
                    // Pindah ke Dashboard
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const MainNavigator()),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Nama dan Server URL harus diisi!")),
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
      ),
    );
  }
}