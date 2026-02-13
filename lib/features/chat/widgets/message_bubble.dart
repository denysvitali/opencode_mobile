import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_markdown/flutter_markdown.dart' as md;
import 'package:markdown/markdown.dart' as md_pkg;
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/github.dart';

import '../../../core/models/message.dart';
import 'tool_card.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool showAvatar;
  final bool showTimestamp;
  final bool isGrouped;

  const MessageBubble({
    super.key,
    required this.message,
    this.showAvatar = true,
    this.showTimestamp = true,
    this.isGrouped = false,
  });

  bool get _hasTextOrReasoning {
    return message.parts.any((p) =>
        p.type == MessagePartType.text || p.type == MessagePartType.reasoning);
  }

  bool get _hasErrorParts {
    return message.parts.any((p) => p.type == MessagePartType.error) ||
        message.error != null;
  }

  List<Widget> _buildErrorParts(BuildContext context) {
    final errorParts = message.parts.where((p) => p.type == MessagePartType.error);
    final widgets = <Widget>[];
    for (final part in errorParts) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.error_outline, size: 18,
                  color: Theme.of(context).colorScheme.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  part.error ?? part.text ?? 'Unknown error',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ));
    }
    if (message.error != null && errorParts.isEmpty) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.error_outline, size: 18,
                  color: Theme.of(context).colorScheme.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message.error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ));
    }
    return widgets;
  }

  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      final hour = dateTime.hour;
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '$displayHour:$minute $period';
    }
  }

  String _formatModelInfo(String? modelId, String? providerId) {
    if (modelId != null && providerId != null) {
      return '$providerId/$modelId';
    } else if (modelId != null) {
      return modelId;
    } else if (providerId != null) {
      return providerId;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        left: isUser ? 48 : (showAvatar ? 0 : 48),
        right: isUser ? (showAvatar ? 0 : 48) : 48,
        top: isGrouped ? 2 : 8,
        bottom: 2,
      ),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Assistant avatar
          if (!isUser && showAvatar) ...[
            _Avatar(
              isUser: false,
              isGrouped: isGrouped,
            ),
            const SizedBox(width: 8),
          ],
          // Message content
          Flexible(
            child: Column(
              crossAxisAlignment: isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (_hasTextOrReasoning || message.toolParts.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isUser
                          ? Theme.of(context).colorScheme.primary
                          : isDark
                              ? const Color(0xFF2D2D2D)
                              : Theme.of(context).cardColor,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(isGrouped && !isUser ? 4 : 18),
                        topRight: Radius.circular(18),
                        bottomLeft: Radius.circular(isUser ? 18 : 4),
                        bottomRight: Radius.circular(isGrouped && isUser ? 4 : 18),
                      ),
                      border: !isUser
                          ? Border.all(
                              color: isDark
                                  ? const Color(0xFF3D3D3D)
                                  : Theme.of(context).dividerColor,
                            )
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _buildContent(context, isUser),
                  ),
                if (_hasErrorParts)
                  ..._buildErrorParts(context),
                if (message.toolParts.isNotEmpty)
                  ...message.toolParts.map(
                    (tool) => Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: ToolCard(part: tool),
                    ),
                  ),
                // Timestamp and model info
                if (showTimestamp && !isGrouped)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isUser && (message.modelId != null || message.providerId != null))
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _formatModelInfo(message.modelId, message.providerId),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontSize: 10,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                              ),
                            ),
                          ),
                        Text(
                          _formatTimestamp(message.createdAt),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontSize: 11,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.5),
                              ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // User avatar
          if (isUser && showAvatar) ...[
            const SizedBox(width: 8),
            _Avatar(
              isUser: true,
              isGrouped: isGrouped,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isUser) {
    final textParts = message.parts.where((p) => p.type == MessagePartType.text);
    final reasoningParts = message.parts.where((p) => p.type == MessagePartType.reasoning);

    if (textParts.isEmpty && reasoningParts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (reasoningParts.isNotEmpty)
          ...reasoningParts.map(
            (part) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).dividerColor.withOpacity(0.5),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.psychology,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      part.text ?? '',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (textParts.isNotEmpty)
          md.MarkdownBody(
            data: textParts.map((p) => p.text ?? '').join('\n'),
            styleSheet: md.MarkdownStyleSheet(
              p: TextStyle(
                color: isUser ? Colors.white : null,
              ),
              code: TextStyle(
                backgroundColor: isUser
                    ? Colors.white.withOpacity(0.2)
                    : Theme.of(context).colorScheme.surface,
                color: isUser ? Colors.white : null,
              ),
              codeblockDecoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1E1E1E)
                    : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            builders: {
              'code': _CodeBlockBuilder(isUser),
            },
          ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  final bool isUser;
  final bool isGrouped;

  const _Avatar({
    required this.isUser,
    required this.isGrouped,
  });

  @override
  Widget build(BuildContext context) {
    if (isGrouped) {
      // Show small dot when grouped
      return Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: isUser
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.secondary,
          shape: BoxShape.circle,
        ),
      );
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isUser
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.secondary,
        shape: BoxShape.circle,
      ),
      child: Icon(
        isUser ? Icons.person : Icons.smart_toy,
        size: 18,
        color: Colors.white,
      ),
    );
  }
}

class _CodeBlockBuilder extends MarkdownElementBuilder {
  final bool isUser;

  _CodeBlockBuilder(this.isUser);

  @override
  Widget? visitElementAfter(md_pkg.Element element, TextStyle? preferredStyle) {
    final language = element.attributes['class']?.replaceFirst('language-', '') ?? 'plaintext';
    final code = element.textContent;

    return _CodeBlockView(
      code: code,
      language: language,
      isUser: isUser,
    );
  }
}

class _CodeBlockView extends StatefulWidget {
  final String code;
  final String language;
  final bool isUser;

  const _CodeBlockView({
    required this.code,
    required this.language,
    required this.isUser,
  });

  @override
  State<_CodeBlockView> createState() => _CodeBlockViewState();
}

class _CodeBlockViewState extends State<_CodeBlockView> {
  bool _copied = false;

  void _copyCode() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.transparent,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with language and copy button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF252525) : const Color(0xFFE8E8E8),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.code,
                  size: 14,
                  color: widget.isUser ? Colors.white70 : Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  widget.language,
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.isUser ? Colors.white70 : Colors.grey[600],
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: _copyCode,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _copied ? Icons.check : Icons.copy,
                          size: 14,
                          color: _copied
                              ? Colors.green
                              : (widget.isUser ? Colors.white70 : Colors.grey[600]),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _copied ? 'Copied!' : 'Copy',
                          style: TextStyle(
                            fontSize: 11,
                            color: _copied
                                ? Colors.green
                                : (widget.isUser ? Colors.white70 : Colors.grey[600]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Code content
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: HighlightView(
                widget.code,
                language: widget.language,
                theme: widget.isUser
                    ? const {}
                    : (isDark ? atomOneDarkTheme : githubTheme),
                padding: EdgeInsets.zero,
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontFamily: 'monospace',
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
