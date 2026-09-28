import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/chat_theme_service.dart';

/// أيقونة الذكاء الاصطناعي داخل المحادثة.
///
/// هذه الأيقونة خاصة بالـAI داخل شاشة المحادثة فقط.
/// لا تستخدم شعار صاحبي AI ولا تغيّره.
///
/// تعتمد الألوان والأيقونة على ChatThemeData.
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

class _AnimatedAiAvatarState extends State<_AnimatedAiAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _syncAnimation();
  }

  @override
  void didUpdateWidget(
    covariant _AnimatedAiAvatar oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.animated != widget.animated) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    if (widget.animated) {
      _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0;
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

        final pulse = widget.animated
            ? 1.0 +
                0.025 *
                    ((math.sin(
                              progress * math.pi * 2,
                            ) +
                            1) /
                        2)
            : 1.0;

        final rotation = widget.animated
            ? progress * math.pi * 0.18
            : 0.0;

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

    final labelText = widget.label?.trim();

    if (labelText == null || labelText.isEmpty) {
      return avatar;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        avatar,
        const SizedBox(height: 4),
        Text(
          labelText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
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

    final innerSize = math.max(
      1.0,
      outerSize - 5,
    );

    return SizedBox(
      width: outerSize,
      height: outerSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ======================================================
          // OUTER GLOW
          // ======================================================

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

          // ======================================================
          // GRADIENT RING
          // ======================================================

          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Container(
                width: outerSize,
                height: outerSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    transform: GradientRotation(
                      _controller.value * math.pi * 2,
                    ),
                    colors: [
                      widget.theme.primary,
                      widget.theme.secondary,
                      widget.theme.glow,
                      widget.theme.primary,
                    ],
                  ),
                ),
              );
            },
          ),

          // ======================================================
          // INNER GLASS BODY
          // ======================================================

          Container(
            width: innerSize,
            height: innerSize,
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
              boxShadow: [
                BoxShadow(
                  color: widget.theme.glow.withValues(
                    alpha: 0.10,
                  ),
                  blurRadius: outerSize * 0.20,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // ==================================================
                // TOP REFLECTION
                // ==================================================

                Positioned(
                  top: outerSize * 0.14,
                  left: outerSize * 0.18,
                  child: Container(
                    width: outerSize * 0.25,
                    height: outerSize * 0.10,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        outerSize,
                      ),
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(
                            alpha: 0.16,
                          ),
                          Colors.white.withValues(
                            alpha: 0.0,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ==================================================
                // INNER LIGHT POINT
                // ==================================================

                Positioned(
                  top: outerSize * 0.16,
                  right: outerSize * 0.20,
                  child: Container(
                    width: outerSize * 0.12,
                    height: outerSize * 0.12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.theme.secondary.withValues(
                        alpha: 0.88,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.theme.secondary.withValues(
                            alpha: 0.55,
                          ),
                          blurRadius: outerSize * 0.18,
                        ),
                      ],
                    ),
                  ),
                ),

                // ==================================================
                // AI ICON
                // ==================================================

                Icon(
                  widget.theme.aiIcon,
                  size: outerSize * 0.46,
                  color: Colors.white,
                ),

                // ==================================================
                // SMALL BOTTOM LIGHT
                // ==================================================

                Positioned(
                  bottom: outerSize * 0.16,
                  left: outerSize * 0.20,
                  child: Container(
                    width: outerSize * 0.07,
                    height: outerSize * 0.07,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.theme.primary,
                      boxShadow: [
                        BoxShadow(
                          color: widget.theme.primary.withValues(
                            alpha: 0.45,
                          ),
                          blurRadius: outerSize * 0.10,
                        ),
                      ],
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
}
