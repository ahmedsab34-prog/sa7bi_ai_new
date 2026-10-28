
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/chat_theme_service.dart';

/// أيقونة المساعد داخل المحادثة، منفصلة عن شعار التطبيق.
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
      duration: const Duration(seconds: 6),
    );

    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _AnimatedAiAvatar oldWidget) {
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
        final pulse = widget.animated
            ? 1 + 0.015 * ((math.sin(
                        _controller.value * math.pi * 2,
                      ) +
                      1) /
                  2)
            : 1.0;

        return Transform.scale(
          scale: pulse,
          child: child,
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
        const SizedBox(height: 3),
        Text(
          labelText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.78),
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar() {
    final outerSize = widget.size;
    final innerSize = math.max(1.0, outerSize - 4);

    return SizedBox(
      width: outerSize,
      height: outerSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: outerSize,
            height: outerSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.theme.primary.withValues(alpha: 0.18),
                  blurRadius: outerSize * 0.24,
                  spreadRadius: outerSize * 0.015,
                ),
              ],
            ),
          ),
          Container(
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
          ),
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
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  top: outerSize * 0.17,
                  right: outerSize * 0.19,
                  child: Container(
                    width: outerSize * 0.10,
                    height: outerSize * 0.10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.theme.secondary,
                      boxShadow: [
                        BoxShadow(
                          color: widget.theme.secondary.withValues(
                            alpha: 0.40,
                          ),
                          blurRadius: outerSize * 0.12,
                        ),
                      ],
                    ),
                  ),
                ),
                Icon(
                  widget.theme.aiIcon,
                  size: outerSize * 0.43,
                  color: Colors.white,
                ),
                Positioned(
                  bottom: outerSize * 0.17,
                  left: outerSize * 0.20,
                  child: Container(
                    width: outerSize * 0.065,
                    height: outerSize * 0.065,
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
}
