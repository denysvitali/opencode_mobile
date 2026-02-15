import 'package:flutter/material.dart';

import '../../../core/models/message.dart';
import '../../../core/providers/chat_provider.dart';
import 'message_bubble.dart';

class MessageList extends StatefulWidget {
  final List<Message> messages;
  final List<PendingMessage> pendingMessages;
  final ScrollController scrollController;
  final void Function(String pendingId)? onRetry;
  final void Function(String pendingId)? onDismiss;

  const MessageList({
    super.key,
    required this.messages,
    this.pendingMessages = const [],
    required this.scrollController,
    this.onRetry,
    this.onDismiss,
  });

  @override
  State<MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<MessageList> {
  @override
  Widget build(BuildContext context) {
    if (widget.messages.isEmpty && widget.pendingMessages.isEmpty) {
      return _EmptyState();
    }

    // Build list with date separators and grouped messages
    final items = <Widget>[];

    // Add pending messages first (they appear at the bottom since list is reversed)
    for (int i = 0; i < widget.pendingMessages.length; i++) {
      final pending = widget.pendingMessages[i];
      items.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: _PendingMessageBubble(
            pending: pending,
            onRetry: widget.onRetry,
            onDismiss: widget.onDismiss,
          ),
        ),
      );
    }

    for (int i = 0; i < widget.messages.length; i++) {
      final message = widget.messages[widget.messages.length - 1 - i];
      final isLast = i == widget.messages.length - 1;
      final nextMessage = isLast ? null : widget.messages[widget.messages.length - 2 - i];
      final prevMessage = i == 0 ? null : widget.messages[widget.messages.length - i];

      // Check if we need a date separator
      final messageDate = _getDateKey(message.createdAt);
      final prevDate = prevMessage != null ? _getDateKey(prevMessage.createdAt) : null;

      if (prevDate != messageDate) {
        items.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: DateSeparator(date: message.createdAt),
          ),
        );
      }

      // Determine if message should show avatar/timestamp (grouping)
      final showAvatar = nextMessage?.role != message.role || prevDate != messageDate;
      final showTimestamp = nextMessage?.role != message.role || prevDate != messageDate;
      final isGrouped = !showAvatar && nextMessage != null && nextMessage.role == message.role;

      items.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: MessageBubble(
            message: message,
            showAvatar: showAvatar,
            showTimestamp: showTimestamp,
            isGrouped: isGrouped,
          ),
        ),
      );
    }

    return ListView(
      reverse: true,
      controller: widget.scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      children: items,
    );
  }

  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month}-${date.day}';
  }
}

class DateSeparator extends StatelessWidget {
  final DateTime date;

  const DateSeparator({super.key, required this.date});

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return 'Today';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else if (now.difference(date).inDays < 7) {
      const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      return days[date.weekday - 1];
    } else {
      return '${_monthName(date.month)} ${date.day}, ${date.year}';
    }
  }

  String _monthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          _formatDate(date),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated icon container
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.smart_toy_outlined,
                size: 56,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Start a conversation',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Send a message to begin chatting\nwith the AI assistant',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            // Quick suggestions
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _SuggestionChip(
                  icon: Icons.code,
                  label: 'Help with code',
                  onTap: () {},
                ),
                _SuggestionChip(
                  icon: Icons.bug_report,
                  label: 'Debug an issue',
                  onTap: () {},
                ),
                _SuggestionChip(
                  icon: Icons.description,
                  label: 'Explain code',
                  onTap: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SuggestionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingMessageBubble extends StatelessWidget {
  final PendingMessage pending;
  final void Function(String pendingId)? onRetry;
  final void Function(String pendingId)? onDismiss;

  const _PendingMessageBubble({
    required this.pending,
    this.onRetry,
    this.onDismiss,
  });

  String _formatTimestamp(DateTime dateTime) {
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 48, right: 0, top: 8, bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: pending.error != null
                        ? Theme.of(context).colorScheme.errorContainer
                        : Theme.of(context).colorScheme.primary.withOpacity(0.8),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        pending.text,
                        style: const TextStyle(color: Colors.white),
                      ),
                      if (pending.isSending) ...[
                        const SizedBox(height: 8),
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (pending.error != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 14,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            pending.error!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton.icon(
                        onPressed: onRetry != null ? () => onRetry!(pending.id) : null,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Retry'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: onDismiss != null ? () => onDismiss!(pending.id) : null,
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('Dismiss'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 4, right: 4),
                    child: Text(
                      _formatTimestamp(pending.createdAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.5),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person,
              size: 18,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
