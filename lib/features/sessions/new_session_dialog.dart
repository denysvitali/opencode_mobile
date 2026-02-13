import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/sessions_provider.dart';

class NewSessionDialog extends StatefulWidget {
  const NewSessionDialog({super.key, required this.ref});

  final WidgetRef ref;

  @override
  State<NewSessionDialog> createState() => _NewSessionDialogState();
}

class _NewSessionDialogState extends State<NewSessionDialog> {
  bool _isLoading = false;

  Future<void> _createSession() async {
    setState(() => _isLoading = true);

    try {
      final session = await widget.ref.read(sessionsProvider.notifier).createSession();

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
    // Auto-create session on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isLoading) {
        _createSession();
      }
    });

    return AlertDialog(
      title: const Text('New Session'),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Creating session...'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
