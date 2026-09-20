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
      duration: const Duration(seconds: 7),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'فتح خلصانة AI',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, __) {
            final angle = _controller.value * math.pi * 2;

            final dx = math.sin(angle) * 5;
            final dy = math.cos(angle * 0.72) * 3;

            final pulse =
                (math.sin(angle) + 1) / 2;

            return Transform.translate(
              offset: Offset(dx, dy),
              child: SizedBox(
                width: 68,
                height: 68,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // الهالة الخارجية المتحركة.
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFD76A)
                                .withOpacity(
                              0.07 + pulse * 0.10,
                            ),
                            blurRadius: 23,
                            spreadRadius: 2,
                          ),
                          BoxShadow(
                            color: const Color(0xFF63E6FF)
                                .withOpacity(
                              0.05 + pulse * 0.08,
                            ),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                    ),

                    // الحلقة الملونة الدوارة.
                    Transform.rotate(
                      angle: angle,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: SweepGradient(
                            colors: [
                              Color(0xFFFFD76A),
                              Color(0xFF63E6FF),
                              Color(0xFF7864FF),
                              Color(0xFF49E6A8),
                              Color(0xFFFFD76A),
                            ],
                            stops: [
                              0.0,
                              0.25,
                              0.50,
                              0.75,
                              1.0,
                            ],
                          ),
                        ),
                      ),
                    ),

                    // حلقة داخلية زجاجية.
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF080B13),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.16),
                          width: 1,
                        ),
                      ),
                    ),

                    // انعكاس زجاجي بسيط.
                    Positioned(
                      top: 9,
                      left: 15,
                      child: Container(
                        width: 17,
                        height: 7,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Colors.white.withOpacity(0.09),
                        ),
                      ),
                    ),

                    // الشعار الداخلي.
                    Container(
                      width: 47,
                      height: 47,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(
                          colors: [
                            Color(0xFF171A25),
                            Color(0xFF090C14),
                          ],
                        ),
                        border: Border.all(
                          color: const Color(0xFFFFD76A)
                              .withOpacity(0.25),
                        ),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'خلصانة',
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                              color: Color(0xFFFFD76A),
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'AI',
                            style: TextStyle(
                              color: Color(0xFF63E6FF),
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.4,
                              height: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // نقطة ضوء متحركة على الحلقة.
                    Transform.rotate(
                      angle: angle,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.90),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0xFFFFD76A),
                                blurRadius: 7,
                              ),
                            ],
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
      ),
    );
  }
}
