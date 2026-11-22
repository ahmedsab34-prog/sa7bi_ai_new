
import 'package:flutter/material.dart';

import 'sa7bi_hero_3d.dart';

/// أيقونة HERO المصغّرة لفتح خلصانة.
/// العرض المرئي 52×64 dp، مع مساحة لمس لا تقل عن 48×48.
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
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF081225).withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0x9972D7FF),
                  width: 1.1,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x44000000),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Color(0x2272D7FF),
                    blurRadius: 9,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
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
                              color: Color(0x99FFD76A),
                              blurRadius: 6,
                            ),
                          ],
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
