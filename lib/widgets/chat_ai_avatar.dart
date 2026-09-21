import 'package:flutter/material.dart';

import '../services/chat_theme_service.dart';

/// أيقونة الذكاء الاصطناعي داخل المحادثة.
///
/// تتغير ألوانها وشكل الإضاءة حسب ChatThemeData.
/// لا تعتمد على شعار صاحبي AI ولا تغيّره؛
/// دي أيقونة خاصة بالـAI داخل المحادثة فقط.
class ChatAiAvatar extends StatelessWidget {
  final ChatThemeData theme;
  final double size;
  final bool animated;
  final String? label;

  const ChatAiAvatar({
    super.key,
    required this.theme,
    this.size = 46,
    this.animated = true,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return _AnimatedAiAvatar(
      theme: theme,
      size: size,
      animated: animated,
      label: label,
    );
  }
}

class _AnimatedAiAvatar extends StatefulWidget {
  final ChatThemeData theme;
  final double size;
  final bool animated;
  final String? label;

  const _AnimatedAiAvatar({
    required this.theme,
    required this.size,
    required this.animated,
    required this.label,
  });

  @override
  State<_AnimatedAiAvatar> createState() =>
      _AnimatedAiAvatarState();
}

class _AnimatedAiAvatarState
    extends State<_AnimatedAiAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    if (widget.animated) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(
    covariant _AnimatedAiAvatar oldWidget,
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
    final avatar = AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;

        final rotation =
            progress * 0.18;

        final pulse =
            1.0 +
            (0.025 *
                (0.5 +
                    0.5 *
                        _sin(progress * 6.28318)));

        return Transform.scale(
          scale: pulse,
          child: Transform.rotate(
            angle: rotation,
            child: child,
          ),
        );
      },
      child: _buildAvatar(),
    );

    if (widget.label == null ||
        widget.label!.trim().isEmpty) {
      return avatar;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        avatar,
        const SizedBox(height: 4),
        Text(
          widget.label!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.82),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar() {
    final outerSize = widget.size;

    return SizedBox(
      width: outerSize,
      height: outerSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // الهالة الخارجية
          Container(
            width: outerSize,
            height: outerSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.theme.primary.withValues(
                    alpha: 0.28,
                  ),
                  blurRadius: outerSize * 0.32,
                  spreadRadius: outerSize * 0.04,
                ),
                BoxShadow(
                  color: widget.theme.secondary.withValues(
                    alpha: 0.18,
                  ),
                  blurRadius: outerSize * 0.55,
                  spreadRadius: 0,
                ),
              ],
            ),
          ),

          // الحلقة المتدرجة
          Container(
            width: outerSize,
            height: outerSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                transform: GradientRotation(
                  _controller.value * 6.28318,
                ),
                colors: [
                  widget.theme.primary,
                  widget.theme.secondary,
                  widget.theme.glow,
                  widget.theme.primary,
                ],
              ),
            ),
          ),

          // الجسم الداخلي
          Container(
            width: outerSize - 5,
            height: outerSize - 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  widget.theme.backgroundBottom,
                  widget.theme.aiBubble,
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(
                  alpha: 0.12,
                ),
                width: 1,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // نقطة ضوء داخلية
                Positioned(
                  top: outerSize * 0.16,
                  right: outerSize * 0.20,
                  child: Container(
                    width: outerSize * 0.12,
                    height: outerSize * 0.12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.theme.secondary
                          .withValues(alpha: 0.85),
                      boxShadow: [
                        BoxShadow(
                          color: widget.theme.secondary
                              .withValues(alpha: 0.55),
                          blurRadius: outerSize * 0.18,
                        ),
                      ],
                    ),
                  ),
                ),

                Icon(
                  widget.theme.aiIcon,
                  size: outerSize * 0.46,
                  color: Colors.white,
                ),

                // لمعة صغيرة
                Positioned(
                  bottom: outerSize * 0.16,
                  left: outerSize * 0.20,
                  child: Container(
                    width: outerSize * 0.07,
                    height: outerSize * 0.07,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.theme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _sin(double value) {
    // تقريب بسيط للحركة الدورية بدون إضافة dependency.
    return _wave(value);
  }

  double _wave(double value) {
    final normalized =
        value % 6.28318;

    if (normalized < 1.570795) {
      return normalized / 1.570795;
    }

    if (normalized < 4.712385) {
      return 1 -
          ((normalized - 1.570795) /
              1.570795 *
              2);
    }

    return -1 +
        ((normalized - 4.712385) /
            1.570795);
  }
}
