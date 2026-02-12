import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/session.dart';
import '../../core/providers/sessions_provider.dart';

class NewSessionDialog extends StatefulWidget {
  final WidgetRef ref;

  const NewSessionDialog({super.key, required this.ref});

  @override
  State<NewSessionDialog> createState() => _NewSessionDialogState();
}

class _NewSessionDialogState extends State<NewSessionDialog> {
  final _titleController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _createSession() async {
    setState(() => _isLoading = true);

    try {
      final session = await widget.ref.read(sessionsProvider.notifier).createSession(
        title: _titleController.text.trim().isNotEmpty
            ? _titleController.text.trim()
            : null,
      );

      if (mounted) {
        Navigator.of(context).pop(session);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create session: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Session'),
      content: TextField(
        controller: _titleController,
        decoration: const InputDecoration(
          labelText: 'Title (optional)',
          hintText: 'Enter a title for this session',
        ),
        autofocus: true,
        onSubmitted: (_) => _createSession(),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _createSession,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}
