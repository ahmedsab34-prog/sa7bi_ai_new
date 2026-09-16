import 'dart:math' as math;
import 'package:flutter/material.dart';

class Sa7biLogo extends StatefulWidget {
  final double size;
  final bool showText;

  const Sa7biLogo({
    super.key,
    this.size = 150,
    this.showText = true,
  });

  @override
  State<Sa7biLogo> createState() => _Sa7biLogoState();
}

class _Sa7biLogoState extends State<Sa7biLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final angle = t * math.pi * 2;

        // حركة ألوان ناعمة حول حافة الشعار
        final c1 = HSVColor.fromAHSV(
          1,
          (42 + t * 260) % 360,
          .75,
          1,
        ).toColor();

        final c2 = HSVColor.fromAHSV(
          1,
          (190 + t * 260) % 360,
          .70,
          1,
        ).toColor();

        // لون نقطة الـ I المتحركة
        final dotColor = HSVColor.fromAHSV(
          1,
          (45 + t * 315) % 360,
          .75,
          1,
        ).toColor();

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: s,
              height: s,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // الهالة الخارجية
                  Container(
                    width: s * .94,
                    height: s * .94,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: c1.withOpacity(.38),
                          blurRadius: 22,
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: c2.withOpacity(.20),
                          blurRadius: 35,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                  ),

                  // الحلقة الزجاجية الملونة
                  Container(
                    width: s * .91,
                    height: s * .91,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        transform: GradientRotation(angle),
                        colors: [
                          c1,
                          Colors.white.withOpacity(.9),
                          c2,
                          Colors.white.withOpacity(.35),
                          c1,
