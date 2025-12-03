import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../ble_provider.dart';
import '../auth_provider.dart';

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
          // Hitung berapa banyak data yang dipilih
          final int selectedCount =
              provider.historyList.where((d) => d.isSelected).length;

          return Column(
            children: [
              // --- Bar Tombol Sync & Hapus ---
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        icon: provider.isSyncing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.cloud_upload),
                        label: Text(
                          provider.isSyncing
                              ? "Mengirim..."
                              : "Sync $selectedCount Data Terpilih",
                        ),
                        onPressed: selectedCount == 0 || provider.isSyncing
                            ? null
                            : () async {
                        // 1. Ambil username dari AuthProvider
                        String user = Provider.of<AuthProvider>(context, listen: false).currentUser;

                        // 2. Kirim username ke fungsi sync
                        final result = await provider.syncDataToServer(user);
                        
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
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 45,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.delete_outline),
                        label: Text(
                          selectedCount == 0
                              ? "Hapus Data Terpilih"
                              : "Hapus $selectedCount Data Terpilih",
                        ),
                        onPressed: selectedCount == 0 || provider.isSyncing
                            ? null
                            : () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text("Konfirmasi"),
                                    content: Text(
                                        "Yakin ingin menghapus $selectedCount data terpilih?"),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(),
                                        child: const Text("Batal"),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          provider.deleteSelectedHistory();
                                          Navigator.of(ctx).pop();
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  "Data terpilih berhasil dihapus"),
                                            ),
                                          );
                                        },
                                        child: const Text(
                                          "Hapus",
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                      ),
                    ),
                  ],
                ),
              ),

              const Text(
                "Riwayat Data (Disimpan di HP)",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),

              // --- List Riwayat ---
              Expanded(
                child: provider.historyList.isEmpty
                    ? const Center(
                        child: Text(
                          "Belum ada data riwayat.\nSimpan data di halaman Dashboard.",
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        itemCount: provider.historyList.length,
                        itemBuilder: (context, index) {
                          final data = provider.historyList[index];
                          final String formattedTime =
                              DateFormat.yMd().add_Hms().format(data.timestamp);

                          return CheckboxListTile(
                            value: data.isSelected,
                            onChanged: (bool? newValue) {
                              provider.toggleItemSelection(index);
                            },
                            title: Text(
                              "N:${data.n.toStringAsFixed(0)}, "
                              "P:${data.p.toStringAsFixed(0)}, "
                              "K:${data.k.toStringAsFixed(0)}",
                            ),
                            subtitle: Text(
                              "$formattedTime - "
                              "pH: ${data.ph.toStringAsFixed(1)}, "
                              "T: ${data.temp.toStringAsFixed(1)}°C",
                            ),
                            activeColor: Colors.deepPurple,
                            // (Opsional) tombol hapus 1 data
                            secondary: IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () {
                                provider.deleteByIndex(index);
                              },
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
