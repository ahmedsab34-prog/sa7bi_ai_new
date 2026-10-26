
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// أيقونة خلصانة AI العائمة.
/// يحافظ الملف على واجهة الاستخدام الحالية: KhalasanaPortal(onTap: ...).
/// يمكن الضغط لفتح المساعد أو سحب الأيقونة لتغيير مكانها.
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
      duration: const Duration(seconds: 7),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _move(DragUpdateDetails details, Size screen) {
    const edge = 8.0;
    const widgetWidth = 82.0;
    const widgetHeight = 82.0;

    setState(() {
      final next = _dragOffset + details.delta;
      _dragOffset = Offset(
        next.dx
            .clamp(
              -screen.width + widgetWidth + edge,
              screen.width - widgetWidth - edge,
            )
            .toDouble(),
        next.dy
            .clamp(
              -screen.height + widgetHeight + edge,
              screen.height - widgetHeight - edge,
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
        label: 'خلصانة AI، اضغط لفتح المساعد أو اسحب لتحريك الأيقونة',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onPanUpdate: (details) => _move(details, screen),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final phase = _controller.value * math.pi * 2;
              final pulse = (math.sin(phase) + 1) / 2;
              final glow = Color.lerp(
                const Color(0xFFFFD76A),
                const Color(0xFF6CE8FF),
                pulse,
              )!;

              return SizedBox(
                width: 82,
                height: 82,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 61,
                      height: 57,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(22),
                          topRight: Radius.circular(22),
                          bottomLeft: Radius.circular(22),
                          bottomRight: Radius.circular(8),
                        ),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF303C5B),
                            Color(0xFF171E32),
                            Color(0xFF090E1A),
                          ],
                        ),
                        border: Border.all(
                          color: glow.withValues(alpha: 0.85),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: glow.withValues(
                              alpha: 0.14 + pulse * 0.12,
                            ),
                            blurRadius: 15,
                            spreadRadius: 1,
                          ),
                          const BoxShadow(
                            color: Color(0x66000000),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned(
                            top: 5,
                            right: 8,
                            child: Container(
                              width: 29,
                              height: 3,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          Icon(
                            Icons.forum_rounded,
                            color: Colors.white.withValues(alpha: 0.94),
                            size: 31,
                          ),
                          Positioned(
                            bottom: 8,
                            right: 11,
                            child: Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                color: glow,
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
                            top: 9,
                            left: 9,
                            child: Transform.rotate(
                              angle: -phase * 0.35,
                              child: Icon(
                                Icons.auto_awesome_rounded,
                                color: const Color(0xFFFFD76A)
                                    .withValues(alpha: 0.8),
                                size: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xF0101522),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: glow.withValues(alpha: 0.65),
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
