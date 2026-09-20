import 'dart:math' as math;

import 'package:flutter/material.dart';

class KhalasanaPortal extends StatefulWidget {
  final VoidCallback onTap;

  const KhalasanaPortal({
    super.key,
    required this.onTap,
  });

  @override
  State<KhalasanaPortal> createState() =>
      _KhalasanaPortalState();
}

class _KhalasanaPortalState
    extends State<KhalasanaPortal>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: controller,
        builder: (_, __) {
          final t =
              controller.value *
                  math.pi *
                  2;

          final dx = math.sin(t) * 7;
          final dy =
              math.cos(t * 0.75) * 5;

          final pulse =
              (math.sin(t) + 1) / 2;

          return Transform.translate(
            offset: Offset(dx, dy),
            child: SizedBox(
              width: 58,
              height: 58,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration:
                        BoxDecoration(
                      shape:
                          BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(
                            0xFF63E6FF,
                          ).withOpacity(
                            0.08 +
                                pulse * 0.10,
                          ),
                          blurRadius: 17,
                        ),
                        BoxShadow(
                          color:
                              const Color(
                            0xFFFFD76A,
                          ).withOpacity(
                            0.08 +
                                pulse * 0.10,
                          ),
                          blurRadius: 17,
                        ),
                      ],
                    ),
                  ),

                  Transform.rotate(
                    angle:
                        controller.value *
                            math.pi *
                            2,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration:
                          const BoxDecoration(
                        shape:
                            BoxShape.circle,
                        gradient:
                            SweepGradient(
                          colors: [
                            Color(
                              0xFFFFD76A,
                            ),
                            Color(
                              0xFF63E6FF,
                            ),
                            Color(
                              0xFF7864FF,
                            ),
                            Color(
                              0xFF49E6A8,
                            ),
                            Color(
                              0xFFFFD76A,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  Container(
                    width: 45,
                    height: 45,
                    decoration:
                        const BoxDecoration(
                      shape:
                          BoxShape.circle,
                      color:
                          Color(0xFF0B0E16),
                    ),
                    child:
                        const Center(
                      child: Column(
                        mainAxisSize:
                            MainAxisSize.min,
                        children: [
                          Text(
                            'خلصانة',
                            textDirection:
                                TextDirection.rtl,
                            style:
                                TextStyle(
                              color:
                                  Color(
                                0xFFFFD76A,
                              ),
                              fontSize:
                                  9,
                              fontWeight:
                                  FontWeight.w900,
                            ),
                          ),
                          Text(
                            'AI',
                            style:
                                TextStyle(
                              color:
                                  Color(
                                0xFF63E6FF,
                              ),
                              fontSize:
                                  8,
                              fontWeight:
                                  FontWeight.w900,
                            ),
                          ),
                        ],
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
