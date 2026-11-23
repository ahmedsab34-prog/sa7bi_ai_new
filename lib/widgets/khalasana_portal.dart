
import 'package:flutter/material.dart';

import 'sa7bi_hero_3d.dart';

/// أيقونة HERO المصغّرة لفتح خلصانة.
/// تستخدم شخصية HERO الرئيسية نفسها داخل إطار زجاجي لامع.
class KhalasanaPortal extends StatefulWidget {
  const KhalasanaPortal({
    super.key,
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  State<KhalasanaPortal> createState() => _KhalasanaPortalState();
}

class _KhalasanaPortalState extends State<KhalasanaPortal> {
  static const double _width = 52;
  static const double _height = 64;

  Offset _dragOffset = Offset.zero;

  void _move(DragUpdateDetails details, Size screen) {
    const edge = 5.0;

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
        label: 'افتح خلصانة أو اسحب لتحريك شخصية صاحبي',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onPanUpdate: (details) => _move(details, screen),
          child: SizedBox(
            width: _width,
            height: _height,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(17),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF31516D),
                    Color(0xFF101F35),
                    Color(0xFF07101F),
                    Color(0xFF162D49),
                  ],
                  stops: [0.0, 0.28, 0.72, 1.0],
                ),
                border: Border.all(
                  color: const Color(0xAA8CE5FF),
                  width: 1.2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x55000000),
                    blurRadius: 13,
                    offset: Offset(0, 5),
                  ),
                  BoxShadow(
                    color: Color(0x4472D7FF),
                    blurRadius: 13,
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: Color(0x33A9E9FF),
                    blurRadius: 5,
                    spreadRadius: -1,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const IgnorePointer(
                      child: Sa7biHero3D(
                        animationName: 'Hero_Idle',
                        cameraControls: false,
                        compact: true,
                        enableFaceAnimations: true,
                      ),
                    ),

                    // انعكاس زجاجي علوي.
                    Positioned(
                      top: -19,
                      left: -17,
                      child: IgnorePointer(
                        child: Transform.rotate(
                          angle: -0.48,
                          child: Container(
                            width: 39,
                            height: 82,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.22),
                                  Colors.white.withValues(alpha: 0.035),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // إضاءة خفيفة على الحافة السفلية.
                    Positioned(
                      left: 7,
                      right: 7,
                      bottom: 3,
                      child: Container(
                        height: 2.5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD76A),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0xAAFFD76A),
                              blurRadius: 7,
                              spreadRadius: 0.5,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // لمعة جانبية رفيعة.
                    Positioned(
                      top: 8,
                      right: 3,
                      bottom: 9,
                      child: Container(
                        width: 1,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: 0.55),
                              Colors.white.withValues(alpha: 0.04),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
