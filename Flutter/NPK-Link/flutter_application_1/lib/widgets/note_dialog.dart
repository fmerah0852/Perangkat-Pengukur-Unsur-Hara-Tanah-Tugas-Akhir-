import 'package:flutter/material.dart';

class NoteDialog extends StatefulWidget {
  final String title;
  final String? initialValue;
  final String? helperText;

  const NoteDialog({
    super.key,
    required this.title,
    this.initialValue,
    this.helperText,
  });

  @override
  State<NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<NoteDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue ?? '');
  }

  @override
  void dispose() {
    _controller.dispose(); // ✅ dispose di sini (aman)
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        maxLines: 3,
        decoration: InputDecoration(
          hintText: 'Tulis catatan...',
          helperText: widget.helperText,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
