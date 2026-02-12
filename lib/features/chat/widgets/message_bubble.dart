import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart' as md;
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:flutter_highlight/themes/github-dark.dart';

import '../../core/models/message.dart';
import 'tool_card.dart';

class MessageBubble extends StatelessWidget {
  final Message message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        child: Column(
          crossAxisAlignment: isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).cardColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: !isUser
                    ? Border.all(
                        color: Theme.of(context).dividerColor,
                      )
                    : null,
              ),
              child: _buildContent(context, isUser),
            ),
            if (message.toolParts.isNotEmpty)
              ...message.toolParts.map(
                (tool) => Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ToolCard(part: tool),
                ),
              ),
          ],
        ),
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

class _CodeBlockBuilder extends md.MarkdownElementBuilder {
  final bool isUser;

  _CodeBlockBuilder(this.isUser);

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final language = element.attributes['class']?.replaceFirst('language-', '') ?? 'plaintext';
    final code = element.textContent;

    return _CodeBlockView(
      code: code,
      language: language,
      isUser: isUser,
    );
  }
}

class _CodeBlockView extends StatelessWidget {
  final String code;
  final String language;
  final bool isUser;

  const _CodeBlockView({
    required this.code,
    required this.language,
    required this.isUser,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.transparent,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.code,
                size: 14,
                color: isUser ? Colors.white70 : null,
              ),
              const SizedBox(width: 4),
              Text(
                language,
                style: TextStyle(
                  fontSize: 12,
                  color: isUser ? Colors.white70 : Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          HighlightView(
            code,
            language: language,
            theme: isUser
                ? {}
                : (isDark ? githubDarkTheme : githubTheme),
            padding: const EdgeInsets.all(12),
            textStyle: TextStyle(
              fontSize: 13,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
