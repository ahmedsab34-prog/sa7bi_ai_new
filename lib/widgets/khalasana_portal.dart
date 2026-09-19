import 'dart:math' as math;
import 'package:flutter/material.dart';

class KhalasanaPortal extends StatefulWidget {
  final VoidCallback onTap;

  const KhalasanaPortal({
    super.key,
    required this.onTap,
  });

  @override
  State<KhalasanaPortal> createState() => _KhalasanaPortalState();
}

class _KhalasanaPortalState extends State<KhalasanaPortal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final rotation = _controller.value * math.pi * 2;
          final pulse =
              1.0 + (math.sin(_controller.value * math.pi * 2) * 0.035);

          return Transform.scale(
            scale: pulse,
            child: SizedBox(
              width: 92,
              height: 112,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer magical glow.
                  Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6C63FF).withOpacity(0.35),
                          blurRadius: 24,
                          spreadRadius: 5,
                        ),
                        BoxShadow(
                          color: const Color(0xFFFFD76A).withOpacity(0.18),
                          blurRadius: 35,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                  ),

                  // Rotating light ring.
                  Transform.rotate(
                    angle: rotation,
                    child: Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const SweepGradient(
                          colors: [
                            Color(0xFFFFD76A),
                            Color(0xFF8A6CFF),
                            Color(0xFF4FD8FF),
                            Color(0xFFFFD76A),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Glass center.
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.24),
                          const Color(0xFF15152B).withOpacity(0.94),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.42),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Portal opening.
                        Container(
                          width: 47,
                          height: 47,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const RadialGradient(
                              colors: [
                                Color(0xFF17152F),
                                Color(0xFF080814),
                              ],
                            ),
                            border: Border.all(
                              color: const Color(0xFFFFD76A)
                                  .withOpacity(0.65),
                              width: 1,
                            ),
                          ),
                        ),

                        // AI letters.
                        const Text(
                          'AI',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),

                        // Moving highlight.
                        Positioned(
                          top: 9,
                          left: 12 + (math.sin(rotation) * 7),
                          child: Container(
                            width: 17,
                            height: 7,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: Colors.white.withOpacity(0.55),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.45),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Name.
                  Positioned(
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10101D).withOpacity(0.88),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFFFD76A).withOpacity(0.5),
                          width: 0.7,
                        ),
                      ),
                      child: const Text(
                        'خلصانة AI',
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          color: Color(0xFFFFD76A),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
