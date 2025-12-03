// lib/pages/dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../ble_provider.dart';
import '../widgets/stat_card.dart'; // Widget kartu kustom

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Gunakan 'Consumer' untuk mendengarkan perubahan dari BleProvider
    return Consumer<BleProvider>(
      builder: (context, provider, child) {
        
        final data = provider.currentData;
        final status = provider.connectionStatus;
        final isConnected = provider.connectedDevice != null;

        return Scaffold(
          appBar: AppBar(
            title: const Text("NutriSync Dashboard"),
            centerTitle: true,
            actions: [
              // Tombol Scan/Status Bluetooth
              IconButton(
                icon: Icon(
                  isConnected ? Icons.bluetooth_connected : Icons.bluetooth_searching,
                  color: isConnected ? Colors.blueAccent : Colors.grey,
                ),
                onPressed: () {
                  provider.scanAndConnect();
                },
              ),
            ],
            // Menampilkan status koneksi di bawah AppBar
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(24.0),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  status,
                  style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                ),
              ),
            ),
          ),
        body: Column(
            children: [
              // 1. Buat GridView-nya bisa di-scroll dan mengisi ruang
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: GridView(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, // 2 kolom
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.2, // Atur rasio kartu
                    ),
                    children: [
                      // --- (Semua StatCard Anda tetap di sini) ---
                      StatCard(
                        title: "Temp°C",
                        value: data.temp.toStringAsFixed(1),
                        icon: Icons.thermostat,
                        color: Colors.orange,
                      ),
                      StatCard(
                        title: "Humidity%",
                        value: data.hum.toStringAsFixed(1),
                        icon: Icons.water_drop,
                        color: Colors.blue,
                      ),
                      StatCard(
                        title: "EC µS/cm",
                        value: data.ec.toStringAsFixed(0),
                        icon: Icons.bolt,
                        color: Colors.green,
                      ),
                      StatCard(
                        title: "PH pH",
                        value: data.ph.toStringAsFixed(1),
                        icon: Icons.science,
                        color: Colors.pink,
                      ),
                      StatCard(
                        title: "N mg/kg",
                        value: data.n.toStringAsFixed(0),
                        icon: Icons.grass,
                        color: Colors.red.shade700,
                      ),
                      StatCard(
                        title: "P mg/kg",
                        value: data.p.toStringAsFixed(0),
                        icon: Icons.local_florist,
                        color: Colors.indigo,
                      ),
                      StatCard(
                        title: "K mg/kg",
                        value: data.k.toStringAsFixed(0),
                        icon: Icons.eco,
                        color: Colors.purple,
                      ),
                      StatCard(
                        title: "Fertility mg/kg",
                        value: "-",
                        icon: Icons.agriculture,
                        color: Colors.yellow.shade700,
                      ),
                    ],
                  ),
                ),
              ),
              
              // --- 2. TAMBAHKAN TOMBOL SIMPAN DI BAWAH GRID ---
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save_alt),
                    label: const Text("Simpan Data Ini ke Riwayat"),
                    onPressed: isConnected ? () { // Hanya bisa diklik jika terhubung
                      
                      // Panggil fungsi baru di provider
                      provider.saveCurrentDataToHistory();
                      
                      // Beri notifikasi ke pengguna
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Data saat ini disimpan ke Riwayat."),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 2),
                        ),
                      );

                    } : null, // Tombol nonaktif jika tidak terhubung
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}