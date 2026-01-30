// lib/widgets/sync_dialog.dart
import 'package:flutter/material.dart';

class SyncDialog extends StatefulWidget {
  final String? initialNote;

  const SyncDialog({
    super.key,
    this.initialNote,
  });

  @override
  State<SyncDialog> createState() => _SyncDialogState();
}

class _SyncDialogState extends State<SyncDialog> {
  late final TextEditingController _projectController;
  late final TextEditingController _noteController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _projectController = TextEditingController();
    _noteController = TextEditingController(text: widget.initialNote ?? '');
  }

  @override
  void dispose() {
    _projectController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Buat Projek & Sync"),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Masukkan nama projek untuk mengelompokkan data yang dipilih, lalu tambahkan catatan jika perlu.",
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            // INPUT NAMA PROJEK
            TextFormField(
              controller: _projectController,
              decoration: const InputDecoration(
                labelText: 'Nama Projek (Wajib)',
                hintText: 'Cth: Lahan Jagung Blok A',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.folder),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Nama projek tidak boleh kosong';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // INPUT NOTE
            TextFormField(
              controller: _noteController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Catatan (Opsional)',
                hintText: 'Kondisi tanah agak basah...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              // Kembalikan map berisi nama projek dan note
              Navigator.of(context).pop({
                'projectName': _projectController.text.trim(),
                'note': _noteController.text.trim(),
              });
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
          ),
          child: const Text('Kirim Data'),
        ),
      ],
    );
  }
}