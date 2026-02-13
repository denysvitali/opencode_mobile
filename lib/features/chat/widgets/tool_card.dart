import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/models/message.dart';

class ToolCard extends StatefulWidget {
  final MessagePart part;

  const ToolCard({super.key, required this.part});

  @override
  State<ToolCard> createState() => _ToolCardState();
}

class _ToolCardState extends State<ToolCard> with SingleTickerProviderStateMixin {
  bool _expanded = true;
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (!_expanded) {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        _controller.reverse();
      } else {
        _controller.forward();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final toolName = widget.part.toolName ?? 'Unknown';
    final state = widget.part.toolState ?? 'pending';
    final input = widget.part.toolInput ?? '';
    final output = widget.part.toolOutput ?? '';

    final (icon, color) = _getIconAndColor(context, toolName);
    final stateColor = _getStateColor(context, state);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: _toggleExpanded,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  RotationTransition(
                    turns: _rotationAnimation,
                    child: Icon(
                      Icons.expand_more,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(width: 8),
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
                            _StateIndicator(state: state, stateColor: stateColor),
                            const SizedBox(width: 6),
                            Text(
                              widget.part.isToolRunning
                                  ? 'Running...'
                                  : (widget.part.toolState?.isNotEmpty == true
                                      ? widget.part.toolState![0].toUpperCase() + widget.part.toolState!.substring(1)
                                      : state),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: stateColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (widget.part.isToolRunning)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(stateColor),
                      ),
                    ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
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
                    icon: Icons.terminal,
                  ),
                ],
              ],
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
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
      'completed' || 'success' => Colors.green,
      'error' => Theme.of(context).colorScheme.error,
      _ => Colors.grey,
    };
  }
}

class _StateIndicator extends StatefulWidget {
  final String state;
  final Color stateColor;

  const _StateIndicator({
    required this.state,
    required this.stateColor,
  });

  @override
  State<_StateIndicator> createState() => _StateIndicatorState();
}

class _StateIndicatorState extends State<_StateIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.state == 'running') {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_StateIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state == 'running' && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (widget.state != 'running' && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.state == 'running') {
      return AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: widget.stateColor.withOpacity(_animation.value),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.stateColor.withOpacity(_animation.value * 0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          );
        },
      );
    }

    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: widget.stateColor,
        shape: BoxShape.circle,
      ),
    );
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

class _ExpandableSectionState extends State<_ExpandableSection>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  bool _copied = false;
  late AnimationController _controller;
  late Animation<double> _iconRotation;
  late Animation<double> _contentSlide;

  static const int _maxLines = 5;
  static const int _truncationLimit = 500;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _iconRotation = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _contentSlide = Tween<double>(begin: -10, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _copyContent() async {
    await Clipboard.setData(ClipboardData(text: widget.content));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  bool get _shouldTruncate => widget.content.length > _truncationLimit;

  String get _displayContent {
    if (_shouldTruncate && !_expanded) {
      return widget.content.substring(0, _truncationLimit) + '...';
    }
    return widget.content;
  }

  bool get _hasMoreContent => _shouldTruncate && widget.content.length > _truncationLimit;

  @override
  Widget build(BuildContext context) {
    final lines = _displayContent.split('\n').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _expanded = !_expanded;
              if (_expanded) {
                _controller.forward();
              } else {
                _controller.reverse();
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                RotationTransition(
                  turns: _iconRotation,
                  child: Icon(
                    Icons.expand_more,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
                const SizedBox(width: 8),
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
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_hasMoreContent && !_expanded) ...[
                  const SizedBox(width: 4),
                  Text(
                    '(${widget.content.length} chars)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                      fontSize: 10,
                    ),
                  ),
                ],
                const Spacer(),
                // Copy button
                InkWell(
                  onTap: _copyContent,
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
                              : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                        ),
                        if (_copied) ...[
                          const SizedBox(width: 4),
                          Text(
                            'Copied!',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Text(
              _displayContent,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.4,
              ),
              maxLines: _maxLines,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          secondChild: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.1),
              end: Offset.zero,
            ).animate(_controller),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: SelectableText(
                widget.content,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          ),
          crossFadeState: _expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
        if (!_expanded && lines > _maxLines)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Text(
              'Tap to expand',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 11,
              ),
            ),
          ),
      ],
    );
  }
}
