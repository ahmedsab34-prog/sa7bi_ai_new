
import 'package:flutter/material.dart';

import '../services/hero_face_runtime.dart';

/// HERO 2.5D:
/// رسم محلي داخل Flutter، بلا GLB أو WebView أو خدمة مدفوعة.
/// يحافظ على اسم Sa7biHero3D وخصائصه لتجنب كسر الاستدعاءات الحالية.
class Sa7biHero3D extends StatefulWidget {
  const Sa7biHero3D({
    super.key,
    this.animationName = 'Hero_Idle',
    this.cameraControls = true,
    this.compact = false,
    this.enableFaceAnimations = true,
  });

  @visibleForTesting
  static bool debugDisableWebViewForTests = false;

  final String animationName;
  final bool cameraControls;
  final bool compact;
  final bool enableFaceAnimations;

  @override
  State<Sa7biHero3D> createState() => _Sa7biHero3DState();
}

class _Sa7biHero3DState extends State<Sa7biHero3D>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathing;
  Offset _rotation = Offset.zero;

  @override
  void initState() {
    super.initState();
    _breathing = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
      lowerBound: -1,
      upperBound: 1,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breathing.dispose();
    super.dispose();
  }

  void _onDrag(DragUpdateDetails details) {
    if (!widget.cameraControls) return;

    setState(() {
      _rotation = Offset(
        (_rotation.dx + details.delta.dx * 0.004).clamp(-0.30, 0.30),
        (_rotation.dy + details.delta.dy * 0.003).clamp(-0.16, 0.16),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<HeroLiteStatus>(
      valueListenable: HeroFaceRuntime.instance.liteStatus,
      builder: (context, status, _) {
        final visibleStatus = widget.enableFaceAnimations
            ? status
            : const HeroLiteStatus();

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: widget.cameraControls ? _onDrag : null,
          child: ClipRect(
            child: AnimatedBuilder(
              animation: _breathing,
              builder: (context, _) {
                return CustomPaint(
                  painter: _Hero25DPainter(
                    animationName: widget.animationName,
                    status: visibleStatus,
                    breathing: _breathing.value,
                    rotation: _rotation,
                  ),
                  child: const SizedBox.expand(),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _Hero25DPainter extends CustomPainter {
  const _Hero25DPainter({
    required this.animationName,
    required this.status,
    required this.breathing,
    required this.rotation,
  });

  final String animationName;
  final HeroLiteStatus status;
  final double breathing;
  final Offset rotation;

  static const Color navy = Color(0xFF07162D);
  static const Color blue = Color(0xFF073C83);
  static const Color cyan = Color(0xFF39DFFF);
  static const Color gold = Color(0xFFFFC247);
  static const Color red = Color(0xFFB82035);
  static const Color skin = Color(0xFFC98D6D);
  static const Color skinLight = Color(0xFFE5B18D);
  static const Color hair = Color(0xFF171A20);

  Paint _paint(Color color, {PaintingStyle style = PaintingStyle.fill}) {
    return Paint()
      ..color = color
      ..style = style
      ..isAntiAlias = true;
  }

  Paint _gradient(Rect rect, List<Color> colors, {bool vertical = false}) {
    return Paint()
      ..isAntiAlias = true
      ..shader = LinearGradient(
        begin: vertical ? Alignment.topCenter : Alignment.centerLeft,
        end: vertical ? Alignment.bottomCenter : Alignment.centerRight,
        colors: colors,
      ).createShader(rect);
  }

  void _roundRect(
    Canvas canvas,
    Rect rect,
    double radius,
    Paint paint,
  ) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      paint,
    );
  }

  void _glow(
    Canvas canvas,
    Offset center,
    double radius, {
    Color color = cyan,
    double opacity = 0.42,
  }) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withValues(alpha: opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.65),
    );
  }

  Path _polygon(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  void _drawBackground(Canvas canvas) {
    final rect = const Rect.fromLTWH(0, 0, 360, 640);

    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.28),
          radius: 0.86,
          colors: [
            Color(0xFF153A68),
            Color(0xFF091A32),
            Color(0xFF050B17),
          ],
        ).createShader(rect),
    );

    for (var i = 0; i < 7; i++) {
      final y = 72.0 + i * 76;
      canvas.drawLine(
        Offset(12, y),
        Offset(348, y),
        _paint(const Color(0x1672DFFF), style: PaintingStyle.stroke)
          ..strokeWidth = 0.7,
      );
    }

    _glow(canvas, const Offset(180, 330), 110);
    _glow(
      canvas,
      const Offset(180, 565),
      65,
      color: gold,
      opacity: 0.16,
    );
  }

  void _drawBody(Canvas canvas) {
    final breath = breathing * 2.0;
    final shoulderY = 232.0 + breath * 0.7;

    // ظل الجسم.
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(180, 604),
        width: 215,
        height: 27,
      ),
      _paint(const Color(0x66000000)),
    );

    // الساقان.
    final leftLeg = _polygon(const [
      Offset(112, 420),
      Offset(178, 425),
      Offset(169, 558),
      Offset(150, 601),
      Offset(91, 594),
      Offset(101, 526),
    ]);
    final rightLeg = _polygon(const [
      Offset(183, 425),
      Offset(248, 420),
      Offset(260, 526),
      Offset(272, 594),
      Offset(211, 601),
      Offset(191, 558),
    ]);

    canvas.drawPath(leftLeg, _gradient(
      const Rect.fromLTWH(90, 420, 90, 185),
      [gold, blue, navy, red],
      vertical: true,
    ));
    canvas.drawPath(rightLeg, _gradient(
      const Rect.fromLTWH(180, 420, 100, 185),
      [red, blue, navy, gold],
      vertical: true,
    ));

    // ألواح الفخذ والركبة.
    canvas.drawPath(
      _polygon(const [
        Offset(111, 438),
        Offset(164, 443),
        Offset(153, 493),
        Offset(106, 490),
      ]),
      _gradient(
        const Rect.fromLTWH(105, 438, 60, 55),
        [gold, Color(0xFF9C641C)],
      ),
    );
    canvas.drawPath(
      _polygon(const [
        Offset(195, 443),
        Offset(249, 438),
        Offset(254, 490),
        Offset(207, 493),
      ]),
      _gradient(
        const Rect.fromLTWH(195, 438, 60, 55),
        [gold, Color(0xFF9C641C)],
      ),
    );

    _roundRect(
      canvas,
      const Rect.fromLTWH(112, 500, 42, 35),
      10,
      _gradient(
        const Rect.fromLTWH(112, 500, 42, 35),
        [cyan, blue, navy],
      ),
    );
    _roundRect(
      canvas,
      const Rect.fromLTWH(207, 500, 42, 35),
      10,
      _gradient(
        const Rect.fromLTWH(207, 500, 42, 35),
        [cyan, blue, navy],
      ),
    );

    // الحذاء.
    _roundRect(
      canvas,
      const Rect.fromLTWH(77, 575, 92, 34),
      13,
      _gradient(
        const Rect.fromLTWH(77, 575, 92, 34),
        [blue, navy, red],
      ),
    );
    _roundRect(
      canvas,
      const Rect.fromLTWH(191, 575, 92, 34),
      13,
      _gradient(
        const Rect.fromLTWH(191, 575, 92, 34),
        [red, navy, blue],
      ),
    );
    _roundRect(
      canvas,
      const Rect.fromLTWH(89, 600, 69, 5),
      3,
      _paint(cyan),
    );
    _roundRect(
      canvas,
      const Rect.fromLTWH(202, 600, 69, 5),
      3,
      _paint(cyan),
    );

    // الذراعان.
    final leftArm = _polygon([
      Offset(91, shoulderY + 4),
      const Offset(48, 255),
      const Offset(29, 348),
      const Offset(48, 421),
      const Offset(88, 416),
      const Offset(80, 350),
      const Offset(119, 286),
    ]);
    final rightArm = _polygon([
      Offset(269, shoulderY + 4),
      const Offset(312, 255),
      const Offset(331, 348),
      const Offset(312, 421),
      const Offset(272, 416),
      const Offset(280, 350),
      const Offset(241, 286),
    ]);

    canvas.drawPath(
      leftArm,
      _gradient(
        const Rect.fromLTWH(25, 235, 100, 190),
        [gold, red, blue, navy],
      ),
    );
    canvas.drawPath(
      rightArm,
      _gradient(
        const Rect.fromLTWH(235, 235, 100, 190),
        [red, gold, blue, navy],
      ),
    );

    // ألواح الساعدين.
    canvas.drawPath(
      _polygon(const [
        Offset(35, 333),
        Offset(77, 337),
        Offset(83, 399),
        Offset(53, 414),
        Offset(39, 387),
      ]),
      _gradient(
        const Rect.fromLTWH(35, 333, 50, 82),
        [blue, cyan, navy],
        vertical: true,
      ),
    );
    canvas.drawPath(
      _polygon(const [
        Offset(325, 333),
        Offset(283, 337),
        Offset(277, 399),
        Offset(307, 414),
        Offset(321, 387),
      ]),
      _gradient(
        const Rect.fromLTWH(275, 333, 50, 82),
        [blue, cyan, navy],
        vertical: true,
      ),
    );

    // الكتفان.
    canvas.drawOval(
      const Rect.fromLTWH(49, 224, 84, 68),
      _gradient(
        const Rect.fromLTWH(49, 224, 84, 68),
        [gold, red, Color(0xFF76202C)],
      ),
    );
    canvas.drawOval(
      const Rect.fromLTWH(227, 224, 84, 68),
      _gradient(
        const Rect.fromLTWH(227, 224, 84, 68),
        [gold, red, Color(0xFF76202C)],
      ),
    );

    canvas.drawOval(
      const Rect.fromLTWH(65, 238, 51, 34),
      _paint(blue, style: PaintingStyle.stroke)..strokeWidth = 5,
    );
    canvas.drawOval(
      const Rect.fromLTWH(244, 238, 51, 34),
      _paint(blue, style: PaintingStyle.stroke)..strokeWidth = 5,
    );

    // الجذع والدرع الصدري.
    final torso = _polygon([
      Offset(112, shoulderY),
      Offset(248, shoulderY),
      const Offset(270, 390),
      const Offset(235, 455),
      const Offset(125, 455),
      const Offset(90, 390),
    ]);

    canvas.drawPath(
      torso,
      _gradient(
        const Rect.fromLTWH(90, 230, 180, 230),
        [Color(0xFF164E91), navy, Color(0xFF050B16)],
        vertical: true,
      ),
    );

    final chest = _polygon(const [
      Offset(117, 251),
      Offset(243, 251),
      Offset(260, 320),
      Offset(228, 367),
      Offset(132, 367),
      Offset(100, 320),
    ]);

    canvas.drawPath(
      chest,
      _gradient(
        const Rect.fromLTWH(100, 250, 160, 120),
        [gold, red, blue, navy],
        vertical: true,
      ),
    );

    final chestInner = _polygon(const [
      Offset(127, 263),
      Offset(233, 263),
      Offset(246, 316),
      Offset(220, 350),
      Offset(140, 350),
      Offset(114, 316),
    ]);

    canvas.drawPath(
      chestInner,
      _gradient(
        const Rect.fromLTWH(114, 263, 132, 87),
        [Color(0xFF0755B8), Color(0xFF061B3A)],
        vertical: true,
      ),
    );

    canvas.drawPath(
      chestInner,
      _paint(gold, style: PaintingStyle.stroke)..strokeWidth = 2.5,
    );

    // شعار صاحبي AI.
    final logo = TextPainter(
      text: const TextSpan(
        text: 'صاحبي AI',
        style: TextStyle(
          color: Colors.white,
          fontSize: 21,
          fontWeight: FontWeight.w900,
          shadows: [
            Shadow(color: cyan, blurRadius: 8),
          ],
        ),
      ),
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.center,
    )..layout(maxWidth: 128);

    logo.paint(canvas, Offset(180 - logo.width / 2, 294));

    canvas.drawArc(
      Rect.fromCenter(
        center: const Offset(180, 327),
        width: 82,
        height: 15,
      ),
      0.15,
      2.85,
      false,
      _paint(gold, style: PaintingStyle.stroke)..strokeWidth = 3,
    );

    // نواة الطاقة.
    _glow(canvas, const Offset(180, 390), 23);
    canvas.drawCircle(
      const Offset(180, 390),
      13,
      _gradient(
        const Rect.fromCircle(center: Offset(180, 390), radius: 13),
        [Colors.white, cyan, blue],
      ),
    );
    canvas.drawCircle(
      const Offset(180, 390),
      18,
      _paint(gold, style: PaintingStyle.stroke)..strokeWidth = 2,
    );

    // خطوط الطاقة.
    final energyPaint = _paint(
      cyan,
      style: PaintingStyle.stroke,
    )
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(
      _polygon(const [
        Offset(117, 365),
        Offset(137, 385),
        Offset(125, 411),
        Offset(148, 428),
      ])..close(),
      energyPaint,
    );
    canvas.drawPath(
      _polygon(const [
        Offset(243, 365),
        Offset(223, 385),
        Offset(235, 411),
        Offset(212, 428),
      ])..close(),
      energyPaint,
    );

    // القبضتان.
    canvas.drawCircle(
      const Offset(63, 421),
      22,
      _gradient(
        const Rect.fromCircle(center: Offset(63, 421), radius: 22),
        [blue, navy, red],
      ),
    );
    canvas.drawCircle(
      const Offset(297, 421),
      22,
      _gradient(
        const Rect.fromCircle(center: Offset(297, 421), radius: 22),
        [red, navy, blue],
      ),
    );
  }

  void _drawHead(Canvas canvas) {
    final headOffset = Offset(rotation.dx * 12, rotation.dy * 8);

    canvas.save();
    canvas.translate(headOffset.dx, headOffset.dy);

    // الرقبة والياقة أسفل الذقن، من دون تغطية الوجه.
    _roundRect(
      canvas,
      const Rect.fromLTWH(151, 192, 58, 62),
      17,
      _gradient(
        const Rect.fromLTWH(151, 192, 58, 62),
        [skinLight, skin, Color(0xFF85513F)],
        vertical: true,
      ),
    );

    _roundRect(
      canvas,
      const Rect.fromLTWH(139, 222, 82, 22),
      9,
      _gradient(
        const Rect.fromLTWH(139, 222, 82, 22),
        [red, gold, navy],
      ),
    );

    // الأذنان.
    canvas.drawOval(
      const Rect.fromLTWH(119, 117, 25, 43),
      _paint(skin),
    );
    canvas.drawOval(
      const Rect.fromLTWH(216, 117, 25, 43),
      _paint(skin),
    );

    // الوجه المكشوف بالكامل.
    final faceRect = const Rect.fromLTWH(128, 53, 104, 157);
    canvas.drawOval(
      faceRect,
      _gradient(
        faceRect,
        [skinLight, skin, Color(0xFFB9785B)],
        vertical: true,
      ),
    );

    // ظل جانبي طبيعي.
    canvas.drawOval(
      const Rect.fromLTWH(194, 83, 31, 112),
      _paint(const Color(0x22713C30)),
    );

    // الشعر القصير الداكن، أعلى الرأس فقط.
    final hairPath = Path()
      ..moveTo(128, 121)
      ..quadraticBezierTo(121, 75, 146, 49)
      ..quadraticBezierTo(177, 27, 207, 51)
      ..quadraticBezierTo(238, 71, 230, 121)
      ..quadraticBezierTo(219, 101, 211, 91)
      ..quadraticBezierTo(185, 103, 158, 91)
      ..quadraticBezierTo(144, 99, 128, 121)
      ..close();

    canvas.drawPath(
      hairPath,
      _gradient(
        const Rect.fromLTWH(125, 35, 110, 90),
        [Color(0xFF34343A), hair, Color(0xFF090D15)],
        vertical: true,
      ),
    );

    // لمعة الشعر.
    canvas.drawArc(
      const Rect.fromLTWH(143, 44, 66, 35),
      3.3,
      2.1,
      false,
      _paint(const Color(0x665E6571), style: PaintingStyle.stroke)
        ..strokeWidth = 3,
    );

    // الحاجبان الكثيفان.
    final browColor = hair;
    final leftBrow = Path()
      ..moveTo(143, 113)
      ..quadraticBezierTo(158, 103, 171, 112);
    final rightBrow = Path()
      ..moveTo(190, 112)
      ..quadraticBezierTo(207, 102, 219, 114);

    canvas.drawPath(
      leftBrow,
      _paint(browColor, style: PaintingStyle.stroke)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      rightBrow,
      _paint(browColor, style: PaintingStyle.stroke)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );

    final surprised = status.expression == HeroExpression.surprise;
    final angry = status.expression == HeroExpression.angry;
    final wink = status.expression == HeroExpression.wink;
    final blink = status.expression == HeroExpression.blink;

    // العينان.
    for (final x in [157.0, 203.0]) {
      final isWinkEye = wink && x == 203.0;
      final eyeRect = Rect.fromCenter(
        center: Offset(x, 128),
        width: 25,
        height: surprised ? 16 : 12,
      );

      if (blink || isWinkEye) {
        canvas.drawLine(
          Offset(x - 11, 128),
          Offset(x + 11, 128),
          _paint(hair, style: PaintingStyle.stroke)
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round,
        );
      } else {
        canvas.drawOval(eyeRect, _paint(Colors.white));
        canvas.drawCircle(
          Offset(x, 128),
          5.2,
          _paint(const Color(0xFF38251F)),
        );
        canvas.drawCircle(
          Offset(x - 1.5, 126),
          1.5,
          _paint(Colors.white),
        );
      }
    }

    // خطوط الغضب فوق الحاجبين.
    if (angry) {
      canvas.drawLine(
        const Offset(145, 108),
        const Offset(171, 117),
        _paint(hair, style: PaintingStyle.stroke)..strokeWidth = 3,
      );
      canvas.drawLine(
        const Offset(190, 117),
        const Offset(216, 108),
        _paint(hair, style: PaintingStyle.stroke)..strokeWidth = 3,
      );
    }

    // الأنف.
    final nose = Path()
      ..moveTo(181, 129)
      ..quadraticBezierTo(175, 151, 180, 154)
      ..quadraticBezierTo(185, 158, 190, 153);
    canvas.drawPath(
      nose,
      _paint(const Color(0xFF925D4B), style: PaintingStyle.stroke)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    // الفم: تعبيرات مرسومة، وليست Lip Sync صوتية دقيقة.
    final mouthY = 174.0;
    final speaking = status.isSpeaking;
    final smile = status.expression == HeroExpression.smile;
    final sad = status.expression == HeroExpression.sad;

    if (speaking && status.activeViseme != 'sil') {
      final mouthHeight = switch (status.activeViseme) {
        'aa' || 'O' || 'U' => 12.0,
        'E' || 'I' => 5.0,
        _ => 7.0,
      };

      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(180, mouthY),
          width: 20,
          height: mouthHeight,
        ),
        _paint(const Color(0xFF55252B)),
      );
    } else {
      final mouth = Path()
        ..moveTo(163, mouthY)
        ..quadraticBezierTo(
          180,
          mouthY + (smile ? 11 : sad ? -8 : 2),
          197,
          mouthY,
        );

      canvas.drawPath(
        mouth,
        _paint(const Color(0xFF713A35), style: PaintingStyle.stroke)
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }

    // لمسة ضوء على الخدّين.
    if (smile) {
      _glow(canvas, const Offset(145, 158), 10, color: red, opacity: 0.18);
      _glow(canvas, const Offset(215, 158), 10, color: red, opacity: 0.18);
    }

    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final scale = size.width / 360;
    final heightScale = size.height / 640;
    final fittedScale = scale < heightScale ? scale : heightScale;

    canvas.save();
    canvas.translate(
      (size.width - 360 * fittedScale) / 2,
      (size.height - 640 * fittedScale) / 2,
    );
    canvas.scale(fittedScale);

    _drawBackground(canvas);

    canvas.save();
    final lean = animationName == 'Hero_Welcome'
        ? -0.025
        : animationName == 'Hero_Power'
            ? 0.018
            : 0.0;
    canvas.translate(180, 320);
    canvas.rotate(lean + rotation.dx * 0.10);
    canvas.translate(-180, -320);

    _drawBody(canvas);
    _drawHead(canvas);

    canvas.restore();

    // حلقة طاقة صغيرة أسفل الشخصية.
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(180, 618),
        width: 170 + breathing * 5,
        height: 10,
      ),
      _paint(cyan.withValues(alpha: 0.55), style: PaintingStyle.stroke)
        ..strokeWidth = 2,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _Hero25DPainter oldDelegate) {
    return oldDelegate.animationName != animationName ||
        oldDelegate.status.revision != status.revision ||
        oldDelegate.breathing != breathing ||
        oldDelegate.rotation != rotation;
  }
}
