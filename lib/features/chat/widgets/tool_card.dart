import 'package:flutter/material.dart';

import '../../core/models/message.dart';

class ToolCard extends StatelessWidget {
  final MessagePart part;

  const ToolCard({super.key, required this.part});

  @override
  Widget build(BuildContext context) {
    final toolName = part.toolName ?? 'Unknown';
    final state = part.toolState ?? 'pending';
    final input = part.toolInput ?? '';
    final output = part.toolOutput ?? '';

    final (icon, color) = _getIconAndColor(context, toolName);
    final stateColor = _getStateColor(context, state);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        toolName,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: stateColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            state,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: stateColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (part.isToolRunning)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          if (input.isNotEmpty) ...[
            const Divider(height: 1),
            _ExpandableSection(
              title: 'Input',
              content: input,
              icon: Icons.input,
            ),
          ],
          if (output.isNotEmpty) ...[
            const Divider(height: 1),
            _ExpandableSection(
              title: 'Output',
              content: output,
              icon: Icons.output,
            ),
          ],
        ],
      ),
    );
  }

  (IconData, Color) _getIconAndColor(BuildContext context, String toolName) {
    return switch (toolName.toLowerCase()) {
      'bash' => (Icons.terminal, Colors.orange),
      'read' => (Icons.description_outlined, Colors.blue),
      'write' => (Icons.edit_outlined, Colors.green),
      'edit' => (Icons.edit, Colors.purple),
      'glob' => (Icons.folder_outlined, Colors.amber),
      'grep' => (Icons.search, Colors.teal),
      'web_fetch' => (Icons.language, Colors.cyan),
      _ => (Icons.build, Theme.of(context).colorScheme.primary),
    };
  }

  Color _getStateColor(BuildContext context, String state) {
    return switch (state) {
      'pending' => Colors.orange,
      'running' => Colors.blue,
      'completed' => Colors.green,
      'error' => Theme.of(context).colorScheme.error,
      _ => Colors.grey,
    };
  }
}

class _ExpandableSection extends StatefulWidget {
  final String title;
  final String content;
  final IconData icon;

  const _ExpandableSection({
    required this.title,
    required this.content,
    required this.icon,
  });

  @override
  State<_ExpandableSection> createState() => _ExpandableSectionState();
}

class _ExpandableSectionState extends State<_ExpandableSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(
                  widget.icon,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                const Spacer(),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).colorScheme.surface,
            child: Text(
              widget.content,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ),
      ],
    );
  }
}
