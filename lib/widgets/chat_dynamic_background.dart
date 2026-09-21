import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/chat_theme_service.dart';

/// خلفية ديناميكية للمحادثات.
///
/// تستقبل ChatThemeData وتحوّلها إلى خلفية متحركة:
/// - تدرج لوني هادئ.
/// - إضاءات ناعمة متحركة.
/// - نقاط ضوئية بسيطة.
/// - حركة خفيفة لا تؤثر على محتوى المحادثة.
///
/// هذا الـWidget لا يحتوي على منطق الشات نفسه.
class ChatDynamicBackground extends StatefulWidget {
  final ChatThemeData theme;
  final Widget child;
  final bool animated;

  const ChatDynamicBackground({
    super.key,
    required this.theme,
    required this.child,
    this.animated = true,
  });

  @override
  State<ChatDynamicBackground> createState() =>
      _ChatDynamicBackgroundState();
}

class _ChatDynamicBackgroundState
    extends State<ChatDynamicBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );

    if (widget.animated) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(
    covariant ChatDynamicBackground oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (widget.animated && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.animated && _controller.isAnimating) {
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _ChatBackgroundPainter(
            theme: widget.theme,
            animationValue: _controller.value,
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _ChatBackgroundPainter extends CustomPainter {
  final ChatThemeData theme;
  final double animationValue;

  _ChatBackgroundPainter({
    required this.theme,
    required this.animationValue,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }

    // ==========================================================
    // الخلفية الأساسية
    // ==========================================================

    final backgroundPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          theme.backgroundTop,
          theme.backgroundBottom,
        ],
      ).createShader(
        Rect.fromLTWH(
          0,
          0,
          size.width,
          size.height,
        ),
      );

    canvas.drawRect(
      Offset.zero & size,
      backgroundPaint,
    );

    // ==========================================================
    // الإضاءات المتحركة
    // ==========================================================

    final angle = animationValue * math.pi * 2;

    final firstCenter = Offset(
      size.width * 0.18 +
          math.cos(angle) * size.width * 0.08,
      size.height * 0.18 +
          math.sin(angle) * size.height * 0.06,
    );

    final secondCenter = Offset(
      size.width * 0.82 +
          math.sin(angle) * size.width * 0.07,
      size.height * 0.58 +
          math.cos(angle) * size.height * 0.09,
    );

    _drawGlow(
      canvas,
      center: firstCenter,
      radius: size.width * 0.55,
      color: theme.primary,
      opacity: 0.10,
    );

    _drawGlow(
      canvas,
      center: secondCenter,
      radius: size.width * 0.50,
      color: theme.secondary,
      opacity: 0.08,
    );

    // ==========================================================
    // هالة صغيرة متحركة
    // ==========================================================

    final smallCenter = Offset(
      size.width *
          (0.50 + math.sin(angle * 0.7) * 0.20),
      size.height *
          (0.78 + math.cos(angle * 0.8) * 0.08),
    );

    _drawGlow(
      canvas,
      center: smallCenter,
      radius: size.width * 0.28,
      color: theme.glow,
      opacity: 0.05,
    );

    // ==========================================================
    // النقاط الضوئية
    // ==========================================================

    _drawParticles(
      canvas,
      size,
      angle,
    );
  }

  void _drawGlow(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required Color color,
    required double opacity,
  }) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: opacity),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(
          center: center,
          radius: radius,
        ),
      );

    canvas.drawCircle(
      center,
      radius,
      paint,
    );
  }

  void _drawParticles(
    Canvas canvas,
    Size size,
    double angle,
  ) {
    final paint = Paint()
      ..style = PaintingStyle.fill;

    const particleCount = 18;

    for (int i = 0; i < particleCount; i++) {
      final seed = i * 1.731;

      final xRatio =
          (math.sin(seed * 4.0) + 1.0) / 2.0;

      final baseY =
          (math.cos(seed * 2.7) + 1.0) / 2.0;

      final movement =
          math.sin(angle + seed) * 0.025;

      final x = size.width * xRatio;

      final y = size.height *
          (baseY + movement).clamp(0.0, 1.0);

      final radius =
          0.8 + ((i % 3) * 0.45);

      final color =
          i.isEven ? theme.primary : theme.secondary;

      paint.color = color.withValues(
        alpha: 0.08 + ((i % 4) * 0.015),
      );

      canvas.drawCircle(
        Offset(x, y),
        radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant _ChatBackgroundPainter oldDelegate,
  ) {
    return oldDelegate.theme.id != theme.id ||
        oldDelegate.animationValue !=
            animationValue;
  }
}
