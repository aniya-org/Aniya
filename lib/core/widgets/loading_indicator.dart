import 'package:flutter/material.dart';

/// Loading indicator type
enum LoadingIndicatorType { circular, linear, dots }

/// A Material Design 3 loading indicator with animations
class LoadingIndicator extends StatelessWidget {
  final String? message;
  final double size;
  final LoadingIndicatorType type;
  final bool fullScreen;

  const LoadingIndicator({
    super.key,
    this.message,
    this.size = 48,
    this.type = LoadingIndicatorType.circular,
    this.fullScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final content = Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildIndicator(colorScheme),
          if (message != null) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                message!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );

    if (fullScreen) {
      return Scaffold(body: content);
    }

    return content;
  }

  Widget _buildIndicator(ColorScheme colorScheme) {
    switch (type) {
      case LoadingIndicatorType.circular:
        return SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: 4,
            color: colorScheme.primary,
          ),
        );
      case LoadingIndicatorType.linear:
        return SizedBox(
          width: size,
          child: LinearProgressIndicator(color: colorScheme.primary),
        );
      case LoadingIndicatorType.dots:
        return _DotsLoadingIndicator(size: size, color: colorScheme.primary);
    }
  }
}

/// Animated dots loading indicator
class _DotsLoadingIndicator extends StatefulWidget {
  final double size;
  final Color color;

  const _DotsLoadingIndicator({required this.size, required this.color});

  @override
  State<_DotsLoadingIndicator> createState() => _DotsLoadingIndicatorState();
}

class _DotsLoadingIndicatorState extends State<_DotsLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size / 2,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final value = (_controller.value * 3 - index).clamp(0.0, 1.0);
              final scale = 0.5 + (value * 0.5);
              final opacity = value < 0.5 ? 1.0 : (1.0 - (value - 0.5) * 2);

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Transform.scale(
                  scale: scale,
                  child: Opacity(
                    opacity: opacity,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.color,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
