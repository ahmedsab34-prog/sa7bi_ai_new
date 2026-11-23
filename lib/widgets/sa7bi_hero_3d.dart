
import 'package:flutter/material.dart';

import '../services/hero_face_runtime.dart';

/// HERO 2.5D — رسم محلي داخل Flutter.
/// لا يستخدم GLB أو WebView أو اتصال شبكة.
/// احتفظنا باسم Sa7biHero3D وخصائصه لتوافق الملفات القديمة.
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
      duration: const Duration(milliseconds: 2800),
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
        (_rotation.dx + details.delta.dx * 0.004)
            .clamp(-0.30, 0.30)
            .toDouble(),
        (_rotation.dy + details.delta.dy * 0.003)
            .clamp(-0.16, 0.16)
            .toDouble(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (Sa7biHero3D.debugDisableWebViewForTests) {
      return const ColoredBox(
        color: Color(0xFF081225),
        child: Center(
          child: Icon(
            Icons.smart_toy_rounded,
            color: Color(0xFF72D7FF),
            size: 30,
          ),
        ),
      );
    }

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

  Path _polygon(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  void _roundRect(Canvas canvas, Rect rect, double radius, Paint paint) {
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
    double opacity = 0.35,
  }) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withValues(alpha: opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.65),
    );
  }

  void _drawBackground(Canvas canvas) {
    const rect = Rect.fromLTWH(0, 0, 360, 640);

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

    _glow(canvas, const Offset(180, 330), 105);
    _glow(
      canvas,
      const Offset(180, 565),
      60,
      color: gold,
      opacity: 0.14,
    );
  }

  void _drawBody(Canvas canvas) {
    final breath = breathing * 2.0;
    final shoulderY = 232.0 + breath * 0.7;

    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(180, 604),
        width: 215,
        height: 27,
      ),
      _paint(const Color(0x66000000)),
    );

    // الساقان والدرع السفلي.
    canvas.drawPath(
      _polygon(const [
        Offset(112, 420),
        Offset(178, 425),
        Offset(169, 558),
        Offset(150, 601),
        Offset(91, 594),
        Offset(101, 526),
      ]),
      _gradient(
        const Rect.fromLTWH(90, 420, 90, 185),
        [gold, blue, navy, red],
        vertical: true,
      ),
    );

    canvas.drawPath(
      _polygon(const [
        Offset(183, 425),
        Offset(248, 420),
        Offset(260, 526),
        Offset(272, 594),
        Offset(211, 601),
        Offset(191, 558),
      ]),
      _gradient(
        const Rect.fromLTWH(180, 420, 100, 185),
        [red, blue, navy, gold],
        vertical: true,
      ),
    );

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

    // الذراعان.
    canvas.drawPath(
      _polygon([
        Offset(91, shoulderY + 4),
        const Offset(48, 255),
        const Offset(29, 348),
        const Offset(48, 421),
        const Offset(88, 416),
        const Offset(80, 350),
        const Offset(119, 286),
      ]),
      _gradient(
        const Rect.fromLTWH(25, 235, 100, 190),
        [gold, red, blue, navy],
      ),
    );

    canvas.drawPath(
      _polygon([
        Offset(269, shoulderY + 4),
        const Offset(312, 255),
        const Offset(331, 348),
        const Offset(312, 421),
        const Offset(272, 416),
        const Offset(280, 350),
        const Offset(241, 286),
      ]),
      _gradient(
        const Rect.fromLTWH(235, 235, 100, 190),
        [red, gold, blue, navy],
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

    // الجذع والدرع الصدري.
    canvas.drawPath(
      _polygon([
        Offset(112, shoulderY),
        Offset(248, shoulderY),
        const Offset(270, 390),
        const Offset(235, 455),
        const Offset(125, 455),
        const Offset(90, 390),
      ]),
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

    final inner = _polygon(const [
      Offset(127, 263),
      Offset(233, 263),
      Offset(246, 316),
      Offset(220, 350),
      Offset(140, 350),
      Offset(114, 316),
    ]);

    canvas.drawPath(
      inner,
      _gradient(
        const Rect.fromLTWH(114, 263, 132, 87),
        [Color(0xFF0755B8), Color(0xFF061B3A)],
        vertical: true,
      ),
    );

    canvas.drawPath(
      inner,
      _paint(gold, style: PaintingStyle.stroke)..strokeWidth = 2.5,
    );

    final logo = TextPainter(
      text: const TextSpan(
        text: 'صاحبي AI',
        style: TextStyle(
          color: Colors.white,
          fontSize: 21,
          fontWeight: FontWeight.w900,
          shadows: [Shadow(color: cyan, blurRadius: 8)],
        ),
      ),
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.center,
    )..layout(maxWidth: 128);

    logo.paint(canvas, Offset(180 - logo.width / 2, 294));

    // نواة الطاقة.
    _glow(canvas, const Offset(180, 390), 23);
    canvas.drawCircle(
      const Offset(180, 390),
      13,
      _gradient(
        Rect.fromCircle(center: Offset(180, 390), radius: 13),
        [Colors.white, cyan, blue],
      ),
    );

    canvas.drawCircle(
      const Offset(180, 390),
      18,
      _paint(gold, style: PaintingStyle.stroke)..strokeWidth = 2,
    );

    // لمسات الطاقة.
    final energy = _paint(
      cyan,
      style: PaintingStyle.stroke,
    )
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      const Offset(117, 365),
      const Offset(148, 428),
      energy,
    );
    canvas.drawLine(
      const Offset(243, 365),
      const Offset(212, 428),
      energy,
    );
  }

  void _drawHead(Canvas canvas) {
    final headOffset = Offset(rotation.dx * 12, rotation.dy * 8);

    canvas.save();
    canvas.translate(headOffset.dx, headOffset.dy);

    // الرقبة والياقة.
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

    // الوجه مكشوف بالكامل.
    const face = Rect.fromLTWH(128, 53, 104, 157);
    canvas.drawOval(
      face,
      _gradient(
        face,
        [skinLight, skin, Color(0xFFB9785B)],
        vertical: true,
      ),
    );

    // الشعر القصير الداكن.
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

    // الحاجبان.
    final leftBrow = Path()
      ..moveTo(143, 113)
      ..quadraticBezierTo(158, 103, 171, 112);

    final rightBrow = Path()
      ..moveTo(190, 112)
      ..quadraticBezierTo(207, 102, 219, 114);

    final browPaint = _paint(
      hair,
      style: PaintingStyle.stroke,
    )
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(leftBrow, browPaint);
    canvas.drawPath(rightBrow, browPaint);

    final surprised = status.expression == HeroExpression.surprise;
    final angry = status.expression == HeroExpression.angry;
    final wink = status.expression == HeroExpression.wink;
    final blink = status.expression == HeroExpression.blink;

    // العينان.
    for (final x in [157.0, 203.0]) {
      final isClosed = blink || (wink && x == 203.0);

      if (isClosed) {
        canvas.drawLine(
          Offset(x - 11, 128),
          Offset(x + 11, 128),
          _paint(hair, style: PaintingStyle.stroke)
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round,
        );
      } else {
        final eyeRect = Rect.fromCenter(
          center: Offset(x, 128),
          width: 25,
          height: surprised ? 16 : 12,
        );

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
      _paint(
        const Color(0xFF925D4B),
        style: PaintingStyle.stroke,
      )
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    // الفم وتعبيرات الوجه.
    const mouthY = 174.0;
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
          center: const Offset(180, mouthY),
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
        _paint(
          const Color(0xFF713A35),
          style: PaintingStyle.stroke,
        )
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }

    if (smile) {
      _glow(
        canvas,
        const Offset(145, 158),
        10,
        color: red,
        opacity: 0.18,
      );
      _glow(
        canvas,
        const Offset(215, 158),
        10,
        color: red,
        opacity: 0.18,
      );
    }

    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final scaleX = size.width / 360;
    final scaleY = size.height / 640;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    canvas.save();
    canvas.translate(
      (size.width - 360 * scale) / 2,
      (size.height - 640 * scale) / 2,
    );
    canvas.scale(scale);

    _drawBackground(canvas);

    canvas.save();
    final lean = animationName == 'Hero_Welcome'
        ? -0.012
        : animationName == 'Hero_Power'
            ? 0.012
            : 0.0;

    canvas.translate(180, 320);
    canvas.rotate(lean + rotation.dx * 0.08);
    canvas.translate(-180, -320);

    _drawBody(canvas);
    _drawHead(canvas);

    canvas.restore();

    // حلقة الطاقة أسفل الشخصية.
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(180, 618),
        width: 170 + breathing * 5,
        height: 10,
      ),
      _paint(
        cyan.withValues(alpha: 0.55),
        style: PaintingStyle.stroke,
      )..strokeWidth = 2,
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
