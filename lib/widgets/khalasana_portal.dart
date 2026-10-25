
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// أيقونة خلصانة AI العائمة.
/// تصميم روبوت زجاجي بحركة خفيفة، ويدعم السحب والضغط.
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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _move(DragUpdateDetails details, Size screen) {
    const edge = 8.0;
    const size = 78.0;

    setState(() {
      final next = _dragOffset + details.delta;
      _dragOffset = Offset(
        next.dx
            .clamp(-screen.width + size + edge,
                screen.width - size - edge)
            .toDouble(),
        next.dy
            .clamp(-screen.height + size + edge,
                screen.height - size - edge)
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
        label: 'فتح خلصانة AI، اضغط للفتح واسحب لتحريك الروبوت',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onPanUpdate: (details) => _move(details, screen),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final pulse =
                  (math.sin(_controller.value * math.pi * 2) + 1) / 2;

              final glow = Color.lerp(
                const Color(0xFFFFD76A),
                const Color(0xFF62E7FF),
                pulse,
              )!;

              return SizedBox(
                width: 72,
                height: 78,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(23),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF343B58),
                            Color(0xFF141A2A),
                            Color(0xFF090D17),
                          ],
                        ),
                        border: Border.all(
                          color: glow.withValues(alpha: 0.85),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: glow.withValues(
                              alpha: 0.16 + pulse * 0.10,
                            ),
                            blurRadius: 13,
                            spreadRadius: 1,
                          ),
                          const BoxShadow(
                            color: Color(0x66000000),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned(
                            top: 7,
                            child: Container(
                              width: 35,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          Container(
                            width: 43,
                            height: 35,
                            decoration: BoxDecoration(
                              color: const Color(0xFF202A40),
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _RobotEye(color: glow),
                                    const SizedBox(width: 10),
                                    _RobotEye(color: glow),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Container(
                                  width: 15,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFD76A),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            top: 1,
                            child: Container(
                              width: 3,
                              height: 7,
                              decoration: BoxDecoration(
                                color: glow,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFD76A),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: glow.withValues(alpha: 0.7),
                                    blurRadius: 7,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 4,
                            top: 29,
                            child: Container(
                              width: 4,
                              height: 11,
                              decoration: BoxDecoration(
                                color: glow.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 4,
                            top: 29,
                            child: Container(
                              width: 4,
                              height: 11,
                              decoration: BoxDecoration(
                                color: glow.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xEE101522),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0x55FFD76A),
                        ),
                      ),
                      child: const Text(
                        'خلصانة AI',
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          color: Color(0xFFFFE6A0),
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ],
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
  const _RobotEye({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.65),
            blurRadius: 5,
          ),
        ],
      ),
    );
  }
}
