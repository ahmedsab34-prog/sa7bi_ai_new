
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/sa7bi_theme.dart';

/// روبوت خلصانة العائم، بدون مربع خلفية أو اسم أسفله.
class KhalasanaPortal extends StatefulWidget {
  const KhalasanaPortal({
    super.key,
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  State<KhalasanaPortal> createState() => _KhalasanaPortalState();
}

class _KhalasanaPortalState extends State<KhalasanaPortal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Offset _dragOffset = Offset.zero;

  static const double _width = 64;
  static const double _height = 74;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _move(DragUpdateDetails details, Size screen) {
    const edge = 4.0;

    setState(() {
      final next = _dragOffset + details.delta;
      _dragOffset = Offset(
        next.dx
            .clamp(
              -screen.width + _width + edge,
              screen.width - _width - edge,
            )
            .toDouble(),
        next.dy
            .clamp(
              -screen.height + _height + edge,
              screen.height - _height - edge,
            )
            .toDouble(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);

    return Transform.translate(
      offset: _dragOffset,
      child: Semantics(
        button: true,
        label: 'روبوت خلصانة، اضغط لفتح المساعد أو اسحب لتحريكه',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onPanUpdate: (details) => _move(details, screen),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final phase = _controller.value * math.pi * 2;
              final pulse = (math.sin(phase) + 1) / 2;
              final glow = Color.lerp(
                Sa7biTheme.cyan,
                Sa7biTheme.violet,
                pulse,
              )!;

              return Transform.translate(
                offset: Offset(0, math.sin(phase) * 1.8),
                child: SizedBox(
                  width: _width,
                  height: _height,
                  child: Stack(
                    alignment: Alignment.topCenter,
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        top: 1,
                        child: Container(
                          width: 3,
                          height: 12,
                          decoration: BoxDecoration(
                            color: glow,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Sa7biTheme.gold,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Sa7biTheme.gold.withValues(
                                  alpha: 0.55,
                                ),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 31,
                        left: 3,
                        child: _RobotEar(color: glow),
                      ),
                      Positioned(
                        top: 31,
                        right: 3,
                        child: _RobotEar(color: glow),
                      ),
                      Positioned(
                        top: 11,
                        child: Container(
                          width: 48,
                          height: 43,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF293953),
                                Color(0xFF17243A),
                                Color(0xFF101727),
                              ],
                            ),
                            border: Border.all(
                              color: glow.withValues(
                                alpha: 0.72 + pulse * 0.2,
                              ),
                              width: 1.4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: glow.withValues(
                                  alpha: 0.13 + pulse * 0.1,
                                ),
                                blurRadius: 14,
                                spreadRadius: 1,
                              ),
                              const BoxShadow(
                                color: Color(0x66000000),
                                blurRadius: 9,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned(
                                top: 4,
                                left: 10,
                                right: 10,
                                child: Container(
                                  height: 2,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(
                                      alpha: 0.17,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 14,
                                left: 10,
                                child: _RobotEye(glow: glow),
                              ),
                              Positioned(
                                top: 14,
                                right: 10,
                                child: _RobotEye(glow: glow),
                              ),
                              Positioned(
                                bottom: 7,
                                child: Container(
                                  width: 13,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    border: const Border(
                                      bottom: BorderSide(
                                        color: Sa7biTheme.cyan,
                                        width: 1.8,
                                      ),
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 11,
                                right: 7,
                                child: Container(
                                  width: 3,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: Sa7biTheme.gold.withValues(
                                      alpha: 0.9,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 57,
                        child: Container(
                          width: 25,
                          height: 11,
                          decoration: BoxDecoration(
                            color: const Color(0xFF26354D),
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                              color: glow.withValues(alpha: 0.7),
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: Container(
                              width: 7,
                              height: 2,
                              decoration: BoxDecoration(
                                color: Sa7biTheme.gold,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 19,
                        right: 0,
                        child: Transform.rotate(
                          angle: phase * 0.4,
                          child: Icon(
                            Icons.auto_awesome_rounded,
                            color: Sa7biTheme.gold.withValues(
                              alpha: 0.45 + pulse * 0.4,
                            ),
                            size: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RobotEye extends StatelessWidget {
  const _RobotEye({required this.glow});

  final Color glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 10,
      decoration: BoxDecoration(
        color: glow,
        borderRadius: BorderRadius.circular(5),
        boxShadow: [
          BoxShadow(
            color: glow.withValues(alpha: 0.45),
            blurRadius: 5,
          ),
        ],
      ),
      child: Align(
        alignment: Alignment.topRight,
        child: Container(
          width: 3,
          height: 3,
          margin: const EdgeInsets.all(2),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _RobotEar extends StatelessWidget {
  const _RobotEar({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 14,
      decoration: BoxDecoration(
        color: const Color(0xFF202E45),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: color.withValues(alpha: 0.75),
          width: 1,
        ),
      ),
    );
  }
}
