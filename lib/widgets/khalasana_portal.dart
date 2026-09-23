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
      duration: const Duration(
        seconds: 5,
      ),
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
          builder: (
            context,
            child,
          ) {
            final progress =
                _controller.value;

            final angle =
                progress *
                    math.pi *
                    2;

            final pulse =
                (math.sin(angle) + 1) /
                    2;

            final glow =
                0.18 +
                    pulse * 0.18;

            return Padding(
              padding:
                  const EdgeInsets.symmetric(
                vertical: 5,
                horizontal: 2,
              ),
              child: Row(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  // ==================================================
                  // MAIN KHALASANA GLASS ICON
                  // ==================================================

                  SizedBox(
                    width: 82,
                    height: 82,
                    child: Stack(
                      alignment:
                          Alignment.center,
                      children: [
                        // ============================================
                        // OUTER GLOW
                        // ============================================

                        Container(
                          width: 78,
                          height: 78,
                          decoration:
                              BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(
                              25,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    const Color(
                                  0xFFFFD76A,
                                ).withOpacity(
                                  glow,
                                ),
                                blurRadius: 28,
                                spreadRadius: 2,
                              ),
                              BoxShadow(
                                color:
                                    const Color(
                                  0xFF63E6FF,
                                ).withOpacity(
                                  0.08 +
                                      pulse *
                                          0.10,
                                ),
                                blurRadius: 26,
                              ),
                              BoxShadow(
                                color:
                                    const Color(
                                  0xFFB45CFF,
                                ).withOpacity(
                                  0.07 +
                                      pulse *
                                          0.08,
                                ),
                                blurRadius: 24,
                              ),
                            ],
                          ),
                        ),

                        // ============================================
                        // ROTATING LUXURY BORDER
                        // ============================================

                        Transform.rotate(
                          angle: angle,
                          child: Container(
                            width: 76,
                            height: 76,
                            decoration:
                                BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(
                                24,
                              ),
                              gradient:
                                  const SweepGradient(
                                colors: [
                                  Color(
                                    0xFFFFD76A,
                                  ),
                                  Color(
                                    0xFFFF6FD8,
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

                        // ============================================
                        // INNER DARK GLASS
                        // ============================================

                        Container(
                          width: 68,
                          height: 68,
                          decoration:
                              BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(
                              21,
                            ),
                            gradient:
                                const LinearGradient(
                              begin:
                                  Alignment.topLeft,
                              end:
                                  Alignment.bottomRight,
                              colors: [
                                Color(
                                  0xFF30364A,
                                ),
                                Color(
                                  0xFF151927,
                                ),
                                Color(
                                  0xFF080B13,
                                ),
                              ],
                            ),
                            border:
                                Border.all(
                              color: Colors
                                  .white
                                  .withOpacity(
                                0.14,
                              ),
                              width: 1,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color:
                                    Color(
                                  0x55000000,
                                ),
                                blurRadius: 12,
                                offset:
                                    Offset(
                                  0,
                                  5,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // ============================================
                        // MOVING INTERNAL LIGHT
                        // ============================================

                        Positioned(
                          left:
                              10 +
                                  progress *
                                      36,
                          top:
                              13 +
                                  math.sin(
                                        angle,
                                      ) *
                                      8,
                          child:
                              Transform.rotate(
                            angle: -0.35,
                            child:
                                Container(
                              width: 34,
                              height: 8,
                              decoration:
                                  BoxDecoration(
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  20,
                                ),
                                gradient:
                                    LinearGradient(
                                  colors: [
                                    Colors
                                        .white
                                        .withOpacity(
                                      0.0,
                                    ),
                                    Colors
                                        .white
                                        .withOpacity(
                                      0.15,
                                    ),
                                    Colors
                                        .white
                                        .withOpacity(
                                      0.0,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        // ============================================
                        // INTERNAL LIGHT ORB
                        // ============================================

                        Positioned(
                          right:
                              8 +
                                  math.cos(
                                        angle,
                                      ) *
                                      5,
                          bottom:
                              9 +
                                  math.sin(
                                        angle,
                                      ) *
                                      4,
                          child:
                              Container(
                            width: 13,
                            height: 13,
                            decoration:
                                BoxDecoration(
                              shape:
                                  BoxShape
                                      .circle,
                              color:
                                  Color.lerp(
                                const Color(
                                  0xFFFFD76A,
                                ),
                                const Color(
                                  0xFF63E6FF,
                                ),
                                pulse,
                              ),
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
                                  )!.withOpacity(
                                    0.65,
                                  ),
                                  blurRadius: 14,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),

                        // ============================================
                        // AI
                        // ============================================

                        Positioned(
                          top: 12,
                          child: ShaderMask(
                            shaderCallback:
                                (bounds) {
                              return
                                  const LinearGradient(
                                begin:
                                    Alignment.topLeft,
                                end:
                                    Alignment.bottomRight,
                                colors: [
                                  Color(
                                    0xFFFFF2AE,
                                  ),
                                  Color(
                                    0xFFFFD76A,
                                  ),
                                  Color(
                                    0xFFFF9F43,
                                  ),
                                ],
                              ).createShader(
                                bounds,
                              );
                            },
                            child: Text(
                              'AI',
                              style:
                                  TextStyle(
                                color:
                                    Colors.white,
                                fontSize: 17,
                                fontWeight:
                                    FontWeight
                                        .w900,
                                letterSpacing:
                                    1.5,
                                shadows: [
                                  Shadow(
                                    color:
                                        const Color(
                                      0xFFFFD76A,
                                    ).withOpacity(
                                      0.55 +
                                          pulse *
                                              0.25,
                                    ),
                                    blurRadius:
                                        9 +
                                            pulse *
                                                7,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // ============================================
                        // خلصانة
                        // ============================================

                        Positioned(
                          top: 33,
                          child: ShaderMask(
                            shaderCallback:
                                (bounds) {
                              return
                                  const LinearGradient(
                                begin:
                                    Alignment.topCenter,
                                end:
                                    Alignment.bottomCenter,
                                colors: [
                                  Color(
                                    0xFFFFF4B8,
                                  ),
                                  Color(
                                    0xFFFFD76A,
                                  ),
                                  Color(
                                    0xFFC9912E,
                                  ),
                                  Color(
                                    0xFFFFE58F,
                                  ),
                                ],
                                stops: [
                                  0.0,
                                  0.30,
                                  0.72,
                                  1.0,
                                ],
                              ).createShader(
                                bounds,
                              );
                            },
                            child: Text(
                              'خلصانة',
                              textDirection:
                                  TextDirection
                                      .rtl,
                              style:
                                  TextStyle(
                                color:
                                    Colors.white,
                                fontSize: 15,
                                fontWeight:
                                    FontWeight
                                        .w900,
                                letterSpacing:
                                    -0.5,
                                shadows: [
                                  Shadow(
                                    color:
                                        const Color(
                                      0xFFFFD76A,
                                    ).withOpacity(
                                      0.35 +
                                          pulse *
                                              0.30,
                                    ),
                                    blurRadius:
                                        9 +
                                            pulse *
                                                6,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // ============================================
                        // SMALL AI DOTS
                        // ============================================

                        Positioned(
                          bottom: 11,
                          child: Row(
                            mainAxisSize:
                                MainAxisSize.min,
                            children: [
                              _LightDot(
                                progress:
                                    pulse,
                                first: true,
                              ),
                              const SizedBox(
                                width: 4,
                              ),
                              _LightDot(
                                progress:
                                    pulse,
                                first: false,
                              ),
                              const SizedBox(
                                width: 4,
                              ),
                              _LightDot(
                                progress:
                                    pulse *
                                        0.7,
                                first: true,
                              ),
                            ],
                          ),
                        ),

                        // ============================================
                        // ROTATING HIGHLIGHT
                        // ============================================

                        Transform.rotate(
                          angle: angle,
                          child:
                              Align(
                            alignment:
                                Alignment
                                    .topRight,
                            child:
                                Container(
                              width: 6,
                              height: 6,
                              decoration:
                                  BoxDecoration(
                                shape:
                                    BoxShape
                                        .circle,
                                color:
                                    Colors.white,
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
                                    blurRadius:
                                        10,
                                    spreadRadius:
                                        1,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(
                    width: 5,
                  ),

                  // ==================================================
                  // صاحبي
                  // ==================================================

                  ShaderMask(
                    shaderCallback:
                        (bounds) {
                      return const LinearGradient(
                        begin:
                            Alignment.topCenter,
                        end:
                            Alignment.bottomCenter,
                        colors: [
                          Color(
                            0xFFFFF1A8,
                          ),
                          Color(
                            0xFFFFD76A,
                          ),
                          Color(
                            0xFFC99228,
                          ),
                          Color(
                            0xFFFFE38A,
                          ),
                        ],
                        stops: [
                          0.0,
                          0.32,
                          0.70,
                          1.0,
                        ],
                      ).createShader(
                        bounds,
                      );
                    },
                    child: Text(
                      'صاحبي',
                      textDirection:
                          TextDirection.rtl,
                      style:
                          TextStyle(
                        fontSize: 21,
                        fontWeight:
                            FontWeight.w900,
                        letterSpacing: -0.4,
                        shadows: [
                          Shadow(
                            color:
                                const Color(
                              0xFFFFD76A,
                            ).withOpacity(
                              0.35 +
                                  pulse *
                                      0.25,
                            ),
                            blurRadius:
                                12,
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

// ============================================================
// SMALL INTERNAL LIGHT
// ============================================================

class _LightDot
    extends StatelessWidget {
  final double progress;
  final bool first;

  const _LightDot({
    required this.progress,
    required this.first,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final color =
        first
            ? Color.lerp(
                const Color(
                  0xFFFFD76A,
                ),
                const Color(
                  0xFFFF6FD8,
                ),
                progress,
              )!
            : Color.lerp(
                const Color(
                  0xFF63E6FF,
                ),
                const Color(
                  0xFF49E6A8,
                ),
                progress,
              )!;

    return Container(
      width: 4,
      height: 4,
      decoration:
          BoxDecoration(
        shape:
            BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color:
                color.withOpacity(
              0.65,
            ),
            blurRadius: 6,
          ),
        ],
      ),
    );
  }
}
