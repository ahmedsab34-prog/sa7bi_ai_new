import 'dart:math' as math;

import 'package:flutter/material.dart';

/// أيقونة خلصانة العائمة.
///
/// - أيقونة فقط بدون كلمة "صاحبي".
/// - أصغر من النسخة السابقة.
/// - زجاجية وفاخرة.
/// - الحركة داخلية حول الأيقونة.
/// - الضغط يفتح ChatScreen مباشرة من MainContainerScreen.
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
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
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
          builder: (context, child) {
            final progress = _controller.value;
            final angle = progress * math.pi * 2;

            final pulse =
                (math.sin(angle) + 1) / 2;

            final glow =
                0.16 + pulse * 0.16;

            final borderColors = <Color>[
              const Color(0xFFFFD76A),
              const Color(0xFFFF6FD8),
              const Color(0xFF63E6FF),
              const Color(0xFF7864FF),
              const Color(0xFF49E6A8),
              const Color(0xFFFFD76A),
            ];

            final lightColor = Color.lerp(
              const Color(0xFFFFD76A),
              const Color(0xFF63E6FF),
              pulse,
            )!;

            return SizedBox(
              width: 70,
              height: 70,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // ================================================
                  // EXTERNAL GLOW
                  // ================================================

                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(21),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD76A)
                              .withOpacity(glow),
                          blurRadius: 24,
                          spreadRadius: 1,
                        ),
                        BoxShadow(
                          color: const Color(0xFF63E6FF)
                              .withOpacity(
                            0.06 + pulse * 0.08,
                          ),
                          blurRadius: 22,
                        ),
                      ],
                    ),
                  ),

                  // ================================================
                  // ROTATING COLOR BORDER
                  // ================================================

                  Transform.rotate(
                    angle: angle,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(20),
                        gradient: SweepGradient(
                          colors: borderColors,
                        ),
                      ),
                    ),
                  ),

                  // ================================================
                  // INNER GLASS
                  // ================================================

                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(17),
                      gradient:
                          const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF343A50),
                          Color(0xFF171B2A),
                          Color(0xFF080B13),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white
                            .withOpacity(0.15),
                        width: 1,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x55000000),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                  ),

                  // ================================================
                  // MOVING GLASS REFLECTION
                  // ================================================

                  Positioned(
                    left: 8 + progress * 42,
                    top:
                        12 +
                        math.sin(angle) * 5,
                    child: Transform.rotate(
                      angle: -0.35,
                      child: Container(
                        width: 23,
                        height: 6,
                        decoration:
                            BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(
                            20,
                          ),
                          gradient:
                              LinearGradient(
                            colors: [
                              Colors.white
                                  .withOpacity(0.0),
                              Colors.white
                                  .withOpacity(0.16),
                              Colors.white
                                  .withOpacity(0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ================================================
                  // AI
                  // ================================================

                  Positioned(
                    top: 10,
                    child: ShaderMask(
                      shaderCallback: (bounds) {
                        return const LinearGradient(
                          colors: [
                            Color(0xFFFFF2AE),
                            Color(0xFFFFD76A),
                            Color(0xFFFF9F43),
                          ],
                        ).createShader(bounds);
                      },
                      child: Text(
                        'AI',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight:
                              FontWeight.w900,
                          letterSpacing: 1.2,
                          shadows: [
                            Shadow(
                              color:
                                  const Color(
                                0xFFFFD76A,
                              ).withOpacity(
                                0.45 + pulse * 0.25,
                              ),
                              blurRadius:
                                  7 + pulse * 5,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ================================================
                  // خلصانة
                  // ================================================

                  Positioned(
                    top: 27,
                    child: ShaderMask(
                      shaderCallback: (bounds) {
                        return const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFFFFF4B8),
                            Color(0xFFFFD76A),
                            Color(0xFFC9912E),
                            Color(0xFFFFE58F),
                          ],
                          stops: [
                            0.0,
                            0.30,
                            0.72,
                            1.0,
                          ],
                        ).createShader(bounds);
                      },
                      child: Text(
                        'خلصانة',
                        textDirection:
                            TextDirection.rtl,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight:
                              FontWeight.w900,
                          letterSpacing: -0.4,
                          shadows: [
                            Shadow(
                              color:
                                  const Color(
                                0xFFFFD76A,
                              ).withOpacity(
                                0.30 + pulse * 0.25,
                              ),
                              blurRadius:
                                  7 + pulse * 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ================================================
                  // SMALL MOVING DOTS
                  // ================================================

                  Positioned(
                    bottom: 9,
                    child: Row(
                      mainAxisSize:
                          MainAxisSize.min,
                      children: [
                        _LightDot(
                          progress: pulse,
                          first: true,
                        ),
                        const SizedBox(width: 3),
                        _LightDot(
                          progress:
                              (pulse + 0.35) % 1,
                          first: false,
                        ),
                        const SizedBox(width: 3),
                        _LightDot(
                          progress:
                              (pulse + 0.70) % 1,
                          first: true,
                        ),
                      ],
                    ),
                  ),

                  // ================================================
                  // MOVING HIGHLIGHT
                  // ================================================

                  Transform.rotate(
                    angle: angle,
                    child: Align(
                      alignment:
                          Alignment.topRight,
                      child: Container(
                        margin:
                            const EdgeInsets.only(
                          top: 5,
                          right: 5,
                        ),
                        width: 5,
                        height: 5,
                        decoration:
                            BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: lightColor,
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LightDot extends StatelessWidget {
  final double progress;
  final bool first;

  const _LightDot({
    required this.progress,
    required this.first,
  });

  @override
  Widget build(BuildContext context) {
    final color = first
        ? Color.lerp(
            const Color(0xFFFFD76A),
            const Color(0xFFFF6FD8),
            progress,
          )!
        : Color.lerp(
            const Color(0xFF63E6FF),
            const Color(0xFF49E6A8),
            progress,
          )!;

    return Container(
      width: 3.5,
      height: 3.5,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.65),
            blurRadius: 5,
          ),
        ],
      ),
    );
  }
}
