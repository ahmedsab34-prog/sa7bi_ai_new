import 'dart:math' as math;

import 'package:flutter/material.dart';

/// بوابة خلصانة AI العائمة.
///
/// - أيقونة فقط بدون كلمة "صاحبي".
/// - أصغر وأكثر هدوءًا من النسخة السابقة.
/// - لا تستخدم رمز اللوجو الرئيسي.
/// - لا توجد نقاط داخل الأيقونة.
/// - AI أعلى كلمة خلصانة.
/// - الحركة داخلية فقط.
/// - الإطار الخارجي يدور بألوان زجاجية فاخرة.
/// - الضغط يفتح ChatScreen مباشرة من MainContainerScreen.
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
          builder: (context, child) {
            final progress = _controller.value;
            final angle = progress * math.pi * 2;

            final wave = (math.sin(angle) + 1) / 2;

            final borderColors = <Color>[
              const Color(0xFFFFD76A),
              const Color(0xFFFF79D8),
              const Color(0xFF62E7FF),
              const Color(0xFF7568FF),
              const Color(0xFF48E5A8),
              const Color(0xFFFFD76A),
            ];

            final innerLight = Color.lerp(
              const Color(0xFFFFD76A),
              const Color(0xFF63E6FF),
              wave,
            )!;

            return SizedBox(
              width: 62,
              height: 62,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // =================================================
                  // SOFT EXTERNAL GLOW
                  // =================================================

                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD76A).withOpacity(
                            0.12 + wave * 0.10,
                          ),
                          blurRadius: 18,
                          spreadRadius: 1,
                        ),
                        BoxShadow(
                          color: const Color(0xFF63E6FF).withOpacity(
                            0.04 + wave * 0.05,
                          ),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                  ),

                  // =================================================
                  // ROTATING COLOR FRAME
                  // =================================================

                  Transform.rotate(
                    angle: angle,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(17),
                        gradient: SweepGradient(
                          colors: borderColors,
                          transform: const GradientRotation(0),
                        ),
                      ),
                    ),
                  ),

                  // =================================================
                  // INNER GLASS
                  // =================================================

                  Container(
                    width: 49,
                    height: 49,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF3A4058),
                          Color(0xFF1B2031),
                          Color(0xFF090C15),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.18),
                        width: 1,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x66000000),
                          blurRadius: 9,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                  ),

                  // =================================================
                  // INTERNAL GLASS ORBIT
                  // =================================================

                  Transform.rotate(
                    angle: -angle * 0.65,
                    child: Container(
                      width: 38,
                      height: 27,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(
                          color: innerLight.withOpacity(
                            0.22 + wave * 0.12,
                          ),
                          width: 1,
                        ),
                      ),
                    ),
                  ),

                  // =================================================
                  // MOVING GLASS REFLECTION
                  // =================================================

                  Positioned(
                    left: 7 + progress * 34,
                    top: 10 + math.sin(angle) * 3,
                    child: Transform.rotate(
                      angle: -0.35,
                      child: Container(
                        width: 18,
                        height: 5,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.0),
                              Colors.white.withOpacity(0.17),
                              Colors.white.withOpacity(0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // =================================================
                  // AI
                  // =================================================

                  Positioned(
                    top: 7,
                    child: ShaderMask(
                      shaderCallback: (bounds) {
                        return const LinearGradient(
                          colors: [
                            Color(0xFFFFF5C2),
                            Color(0xFFFFD76A),
                            Color(0xFFFFA348),
                          ],
                        ).createShader(bounds);
                      },
                      child: Text(
                        'AI',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                          shadows: [
                            Shadow(
                              color: const Color(0xFFFFD76A).withOpacity(
                                0.35 + wave * 0.20,
                              ),
                              blurRadius: 6 + wave * 3,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // =================================================
                  // خلصانة
                  // =================================================

                  Positioned(
                    top: 21,
                    child: ShaderMask(
                      shaderCallback: (bounds) {
                        return const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFFFFF5C5),
                            Color(0xFFFFD76A),
                            Color(0xFFC88D2B),
                            Color(0xFFFFE79A),
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
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          shadows: [
                            Shadow(
                              color: const Color(0xFFFFD76A).withOpacity(
                                0.25 + wave * 0.18,
                              ),
                              blurRadius: 6 + wave * 3,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // =================================================
                  // INTERNAL LIGHT POINT
                  // =================================================

                  Positioned(
                    bottom: 8,
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(
                          0.65 + wave * 0.30,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: innerLight.withOpacity(0.75),
                            blurRadius: 7 + wave * 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // =================================================
                  // SMALL ROTATING HIGHLIGHT
                  // =================================================

                  Transform.rotate(
                    angle: angle,
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        margin: const EdgeInsets.only(
                          top: 5,
                          right: 5,
                        ),
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.9),
                          boxShadow: [
                            BoxShadow(
                              color: innerLight,
                              blurRadius: 7,
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
