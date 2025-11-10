// lib/pages/history_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../ble_provider.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("History & Sync"),
      ),
      body: Consumer<BleProvider>(
        builder: (context, provider, child) {
          return Column(
            children: [
              // --- Tombol Sync ---
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    icon: provider.isSyncing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white))
                        : const Icon(Icons.cloud_upload),
                    label: Text(provider.isSyncing
                        ? "Mengirim..."
                        : "Sync ke Server (${provider.historyList.length} data)"),
                    onPressed: provider.historyList.isEmpty || provider.isSyncing
                        ? null // Nonaktifkan tombol jika tidak ada data atau sedang sync
                        : () async {
                            // Panggil fungsi sync dan tampilkan hasilnya
                            final result = await provider.syncDataToServer();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(result)),
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ),

              // --- Judul List ---
              const Text(
                "Riwayat Data (Disimpan di HP)",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              
              // --- List Riwayat ---
              Expanded(
                child: provider.historyList.isEmpty
                    ? const Center(
                        child: Text("Belum ada data riwayat.\nHubungkan ke sensor."),
                      )
                    : ListView.builder(
                        reverse: true, // Tampilkan data terbaru di atas
                        itemCount: provider.historyList.length,
                        itemBuilder: (context, index) {
                          final data = provider.historyList[index];
                          // Format tanggal
                          final String formattedTime =
                              DateFormat.yMd().add_Hms().format(data.timestamp);

                          return ListTile(
                            leading: const Icon(Icons.show_chart),
                            title: Text(
                              "N:${data.n.toStringAsFixed(0)}, P:${data.p.toStringAsFixed(0)}, K:${data.k.toStringAsFixed(0)}",
                            ),
                            subtitle: Text(
                              "$formattedTime - pH: ${data.ph.toStringAsFixed(1)}, T: ${data.temp.toStringAsFixed(1)}°C",
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}