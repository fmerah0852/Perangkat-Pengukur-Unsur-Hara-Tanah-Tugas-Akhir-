import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../auth_provider.dart';
import '../ble_provider.dart';
import '../sensor_data.dart';
import '../widgets/note_dialog.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<SensorData> _filterHistory(List<SensorData> list, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return list;

    final df = DateFormat.yMd().add_Hms();

    return list.where((d) {
      final ts = df.format(d.timestamp);
      final note = (d.note ?? '').trim();
      final lat = d.latitude?.toStringAsFixed(5) ?? '';
      final lon = d.longitude?.toStringAsFixed(5) ?? '';

      final haystack = <String>[
        ts,
        'n ${d.n}',
        'p ${d.p}',
        'k ${d.k}',
        'ph ${d.ph}',
        'ec ${d.ec}',
        'temp ${d.temp}',
        'hum ${d.hum}',
        'lat $lat lon $lon',
        note,
      ].join(' ').toLowerCase();

      return haystack.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("History & Sync")),
      body: Consumer<BleProvider>(
        builder: (context, provider, child) {
          final allHistory = provider.historyList;
          final filtered = _filterHistory(allHistory, _searchController.text);
          final selectedCount = allHistory.where((d) => d.isSelected).length;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Cari: tanggal, N/P/K, pH, EC, suhu, note, lat/lon...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.trim().isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  height: 50,
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: provider.isSyncing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white),
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
                            final messenger = ScaffoldMessenger.maybeOf(context);
                            final auth = context.read<AuthProvider>();

                            final note = await showDialog<String?>(
                              context: context,
                              builder: (_) => const NoteDialog(
                                title: 'Tambahkan note untuk data terpilih',
                                helperText:
                                    'Note ini dikirim ke API untuk SEMUA data yang dipilih (kosongkan bila tidak perlu).',
                              ),
                            );

                            if (!mounted) return;
                            if (note == null) return;

                            final ble = context.read<BleProvider>();
                            if (note.trim().isNotEmpty) {
                              ble.setNoteForSelected(note);
                            }

                            final user = auth.currentUser;

                            String result;
                            try {
                              result = await ble.syncDataToServer(user);
                            } catch (e) {
                              result = "Sync gagal: $e";
                            }

                            if (!mounted) return;

                            (messenger ?? ScaffoldMessenger.of(context)).showSnackBar(
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
              const Text(
                "Riwayat Data (Disimpan di HP)",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Expanded(
                child: allHistory.isEmpty
                    ? const Center(
                        child: Text(
                          "Belum ada data riwayat.\nSimpan data di halaman Dashboard.",
                          textAlign: TextAlign.center,
                        ),
                      )
                    : (filtered.isEmpty
                        ? const Center(
                            child: Text(
                              "Data tidak ditemukan untuk kata kunci tersebut.",
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, i) {
                              final data = filtered[i];
                              final originalIndex = allHistory.indexOf(data);

                              final formattedTime =
                                  DateFormat.yMd().add_Hms().format(data.timestamp);

                              final noteText = (data.note ?? '').trim();

                              final locText = (data.latitude != null && data.longitude != null)
                                  ? "${data.latitude!.toStringAsFixed(5)}, ${data.longitude!.toStringAsFixed(5)}"
                                  : "-";

                              final subtitle = StringBuffer()
                                ..write(
                                  "$formattedTime - "
                                  "pH: ${data.ph.toStringAsFixed(1)}, "
                                  "T: ${data.temp.toStringAsFixed(1)}°C",
                                )
                                ..write("\nLokasi: $locText");

                              if (noteText.isNotEmpty) {
                                subtitle.write("\nNote: $noteText");
                              }

                              return CheckboxListTile(
                                value: data.isSelected,
                                onChanged: (_) => provider.toggleItemSelection(originalIndex),
                                title: Text(
                                  "N:${data.n.toStringAsFixed(0)}, "
                                  "P:${data.p.toStringAsFixed(0)}, "
                                  "K:${data.k.toStringAsFixed(0)}",
                                ),
                                subtitle: Text(subtitle.toString()),
                                activeColor: Colors.deepPurple,
                                secondary: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: "Edit note",
                                      icon: const Icon(Icons.edit_note),
                                      onPressed: () async {
                                        final updated = await showDialog<String?>(
                                          context: context,
                                          builder: (_) => NoteDialog(
                                            title: 'Edit note',
                                            initialValue: data.note,
                                            helperText:
                                                'Note tersimpan di HP dan ikut terkirim saat Sync.',
                                          ),
                                        );

                                        if (!mounted) return;
                                        if (updated == null) return;

                                        context
                                            .read<BleProvider>()
                                            .updateNoteByIndex(originalIndex, updated);
                                      },
                                    ),
                                    IconButton(
                                      tooltip: "Hapus data",
                                      icon: const Icon(Icons.delete),
                                      onPressed: () => provider.deleteByIndex(originalIndex),
                                    ),
                                  ],
                                ),
                              );
                            },
                          )),
              ),
            ],
          );
        },
      ),
    );
  }
}
