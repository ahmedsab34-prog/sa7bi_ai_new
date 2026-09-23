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
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
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
            final angle =
                _controller.value * math.pi * 2;

            final pulse =
                (math.sin(angle) + 1) / 2;

            final glow =
                0.20 + (pulse * 0.18);

            return Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 5,
                horizontal: 2,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ==================================================
                  // الدائرة الرئيسية
                  // ==================================================

                  SizedBox(
                    width: 76,
                    height: 76,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // الهالة الخارجية.
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color:
                                    const Color(0xFFFFD76A)
                                        .withOpacity(
                                  glow,
                                ),
                                blurRadius: 28,
                                spreadRadius: 2,
                              ),
                              BoxShadow(
                                color:
                                    const Color(0xFF63E6FF)
                                        .withOpacity(
                                  0.10 + pulse * 0.10,
                                ),
                                blurRadius: 24,
                              ),
                              BoxShadow(
                                color:
                                    const Color(0xFFB45CFF)
                                        .withOpacity(
                                  0.08 + pulse * 0.08,
                                ),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                        ),

                        // ==================================================
                        // الحلقة الملونة الدوارة
                        // ==================================================

                        Transform.rotate(
                          angle: angle,
                          child: Container(
                            width: 70,
                            height: 70,
                            decoration:
                                const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: SweepGradient(
                                colors: [
                                  Color(0xFFFFD76A),
                                  Color(0xFFFF6FD8),
                                  Color(0xFF63E6FF),
                                  Color(0xFF7864FF),
                                  Color(0xFF49E6A8),
                                  Color(0xFFFFD76A),
                                ],
                                stops: [
                                  0.0,
                                  0.20,
                                  0.40,
                                  0.62,
                                  0.82,
                                  1.0,
                                ],
                              ),
                            ),
                          ),
                        ),

                        // طبقة داخلية لتكوين الحلقة السميكة.
                        Container(
                          width: 61,
                          height: 61,
                          decoration:
                              const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF080B13),
                          ),
                        ),

                        // زجاج داخلي.
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient:
                                const RadialGradient(
                              colors: [
                                Color(0xFF222638),
                                Color(0xFF090C14),
                              ],
                              center: Alignment(
                                -0.25,
                                -0.35,
                              ),
                            ),
                            border: Border.all(
                              color: Colors.white
                                  .withOpacity(0.15),
                              width: 1,
                            ),
                          ),
                        ),

                        // انعكاس زجاجي.
                        Positioned(
                          top: 12,
                          left: 17,
                          child: Container(
                            width: 19,
                            height: 7,
                            decoration:
                                BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(
                                20,
                              ),
                              color: Colors.white
                                  .withOpacity(0.10),
                            ),
                          ),
                        ),

                        // ==================================================
                        // العلامة الداخلية:
                        // رمز اتصال مخصص + I
                        // ==================================================

                        Row(
                          mainAxisSize:
                              MainAxisSize.min,
                          crossAxisAlignment:
                              CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 26,
                              height: 30,
                              child: CustomPaint(
                                painter:
                                    _ConnectionGlyphPainter(
                                  glow: pulse,
                                ),
                              ),
                            ),

                            const SizedBox(
                              width: 2,
                            ),

                            // حرف I فقط.
                            AnimatedDefaultTextStyle(
                              duration:
                                  const Duration(
                                milliseconds: 250,
                              ),
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight:
                                    FontWeight.w900,
                                fontFamily:
                                    'sans-serif',
                                color: Color.lerp(
                                  const Color(
                                    0xFFFFD76A,
                                  ),
                                  const Color(
                                    0xFF63E6FF,
                                  ),
                                  pulse,
                                ),
                                shadows: [
                                  Shadow(
                                    color:
                                        const Color(
                                      0xFFFFD76A,
                                    ).withOpacity(
                                      0.45 +
                                          pulse * 0.35,
                                    ),
                                    blurRadius:
                                        10 + pulse * 8,
                                  ),
                                ],
                              ),
                              child: const Text(
                                'I',
                              ),
                            ),
                          ],
                        ),

                        // نقطة ضوء تتحرك حول الحلقة.
                        Transform.rotate(
                          angle: angle,
                          child: Align(
                            alignment:
                                Alignment.topCenter,
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration:
                                  BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        Color.lerp(
                                      const Color(
                                        0xFFFFD76A,
                                      ),
                                      const Color(
                                        0xFF63E6FF,
                                      ),
                                      pulse,
                                    )!,
                                    blurRadius: 9,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 5),

                  // ==================================================
                  // كلمة صاحبي
                  // ==================================================

                  ShaderMask(
                    shaderCallback: (bounds) {
                      return const LinearGradient(
                        begin:
                            Alignment.topCenter,
                        end:
                            Alignment.bottomCenter,
                        colors: [
                          Color(0xFFFFF1A8),
                          Color(0xFFFFD76A),
                          Color(0xFFC99228),
                          Color(0xFFFFE38A),
                        ],
                        stops: [
                          0.0,
                          0.32,
                          0.70,
                          1.0,
                        ],
                      ).createShader(bounds);
                    },
                    child: Text(
                      'صاحبي',
                      textDirection:
                          TextDirection.rtl,
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                        shadows: [
                          Shadow(
                            color:
                                const Color(
                              0xFFFFD76A,
                            ).withOpacity(
                              0.35 + pulse * 0.25,
                            ),
                            blurRadius: 12,
                          ),
                        ],
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

// ================================================================
// رمز الاتصال المخصص
// ================================================================
//
// هذا ليس حرف "س".
// يتم رسمه كرمز مستقل حتى لا يظهر أي حرف عربي آخر داخل الشعار.
// ================================================================

class _ConnectionGlyphPainter
    extends CustomPainter {
  final double glow;

  _ConnectionGlyphPainter({
    required this.glow,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final mainColor = Color.lerp(
      const Color(0xFFFFD76A),
      const Color(0xFFFF79D7),
      glow,
    )!;

    // توهج خلفي.
    paint
      ..color = mainColor.withOpacity(0.30)
      ..strokeWidth = 5.5
      ..maskFilter = const MaskFilter.blur(
        BlurStyle.normal,
        5,
      );

    final glowPath = Path();

    glowPath.moveTo(
      size.width * 0.18,
      size.height * 0.52,
    );

    glowPath.cubicTo(
      size.width * 0.35,
      size.height * 0.12,
      size.width * 0.67,
      size.height * 0.12,
      size.width * 0.82,
      size.height * 0.48,
    );

    glowPath.cubicTo(
      size.width * 0.66,
      size.height * 0.88,
      size.width * 0.35,
      size.height * 0.88,
      size.width * 0.18,
      size.height * 0.52,
    );

    canvas.drawPath(
      glowPath,
      paint,
    );

    // الخط الأساسي.
    paint
      ..maskFilter = null
      ..color = mainColor
      ..strokeWidth = 2.7;

    final path = Path();

    path.moveTo(
      size.width * 0.18,
      size.height * 0.52,
    );

    path.cubicTo(
      size.width * 0.35,
      size.height * 0.12,
      size.width * 0.67,
      size.height * 0.12,
      size.width * 0.82,
      size.height * 0.48,
    );

    path.cubicTo(
      size.width * 0.66,
      size.height * 0.88,
      size.width * 0.35,
      size.height * 0.88,
      size.width * 0.18,
      size.height * 0.52,
    );

    canvas.drawPath(
      path,
      paint,
    );

    // خط الاتصال الداخلي.
    paint
      ..color = const Color(0xFFFFF1A8)
          .withOpacity(0.90)
      ..strokeWidth = 2.0;

    final link = Path();

    link.moveTo(
      size.width * 0.30,
      size.height * 0.52,
    );

    link.cubicTo(
      size.width * 0.40,
      size.height * 0.34,
      size.width * 0.60,
      size.height * 0.34,
      size.width * 0.70,
      size.height * 0.52,
    );

    canvas.drawPath(
      link,
      paint,
    );

    // نقطتا الاتصال.
    paint
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFFFE9A0);

    canvas.drawCircle(
      Offset(
        size.width * 0.18,
        size.height * 0.52,
      ),
      2.3,
      paint,
    );

    canvas.drawCircle(
      Offset(
        size.width * 0.82,
        size.height * 0.48,
      ),
      2.3,
      paint,
    );
  }

  @override
  bool shouldRepaint(
    covariant _ConnectionGlyphPainter oldDelegate,
  ) {
    return oldDelegate.glow != glow;
  }
}
