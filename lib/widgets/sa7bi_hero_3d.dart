
import 'package:flutter/material.dart';
import '../services/hero_face_runtime.dart';

/// HERO 2.5D - نسخة Flutter مجانية.
/// نفس الشخصية تستخدم في العرض الكبير وأيقونة خلصانة المصغرة.
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
  late final AnimationController _motion;
  Offset _rotation = Offset.zero;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
      lowerBound: -1,
      upperBound: 1,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  void _onDrag(DragUpdateDetails details) {
    if (!widget.cameraControls || widget.compact) return;

    setState(() {
      _rotation = Offset(
        (_rotation.dx + details.delta.dx * .003)
            .clamp(-.25, .25).toDouble(),
        (_rotation.dy + details.delta.dy * .002)
            .clamp(-.12, .12).toDouble(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<HeroLiteStatus>(
      valueListenable: HeroFaceRuntime.instance.liteStatus,
      builder: (context, status, _) {
        final faceStatus = widget.enableFaceAnimations
            ? status
            : const HeroLiteStatus();

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: widget.cameraControls && !widget.compact
              ? _onDrag
              : null,
          child: AnimatedBuilder(
            animation: _motion,
            builder: (context, _) {
              return CustomPaint(
                painter: _HeroPainter(
                  status: faceStatus,
                  motion: _motion.value,
                  rotation: _rotation,
                  animationName: widget.animationName,
                  compact: widget.compact,
                ),
                child: const SizedBox.expand(),
              );
            },
          ),
        );
      },
    );
  }
}

class _HeroPainter extends CustomPainter {
  const _HeroPainter({
    required this.status,
    required this.motion,
    required this.rotation,
    required this.animationName,
    required this.compact,
  });

  final HeroLiteStatus status;
  final double motion;
  final Offset rotation;
  final String animationName;
  final bool compact;

  static const navy = Color(0xFF071329);
  static const blue = Color(0xFF0751A0);
  static const cyan = Color(0xFF45DFFF);
  static const gold = Color(0xFFFFC34D);
  static const red = Color(0xFFB52235);
  static const skin = Color(0xFFD69B7A);
  static const hair = Color(0xFF17191E);

  Paint paint(Color color, {PaintingStyle style = PaintingStyle.fill}) {
    return Paint()
      ..color = color
      ..style = style
      ..isAntiAlias = true;
  }

  Paint gradient(Rect rect, List<Color> colors,
      {bool vertical = false}) {
    return Paint()
      ..isAntiAlias = true
      ..shader = LinearGradient(
        begin: vertical ? Alignment.topCenter : Alignment.centerLeft,
        end: vertical ? Alignment.bottomCenter : Alignment.centerRight,
        colors: colors,
      ).createShader(rect);
  }

  Path polygon(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  void glow(Canvas c, Offset p, double radius, Color color) {
    c.drawCircle(
      p,
      radius,
      Paint()
        ..color = color.withValues(alpha: .35)
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          radius * .7,
        ),
    );
  }

  void rounded(Canvas c, Rect r, double radius, Paint p) {
    c.drawRRect(
      RRect.fromRectAndRadius(r, Radius.circular(radius)),
      p,
    );
  }

  void drawBackground(Canvas c) {
    final rect = const Rect.fromLTWH(0, 0, 360, 640);
    c.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -.3),
          radius: .9,
          colors: [
            Color(0xFF164274),
            Color(0xFF091A32),
            Color(0xFF040A15),
          ],
        ).createShader(rect),
    );

    glow(c, const Offset(180, 350), 105, cyan);
    glow(c, const Offset(180, 570), 55, gold);

    for (int i = 0; i < 8; i++) {
      final y = 60.0 + i * 75;
      c.drawLine(
        Offset(10, y),
        Offset(350, y),
        paint(const Color(0x1872DFFF))
          ..style = PaintingStyle.stroke
          ..strokeWidth = .7,
      );
    }
  }

  void drawBody(Canvas c) {
    final breath = motion * 2.0;
    final shoulder = 230.0 + breath;

    // الساقان.
    c.drawPath(
      polygon(const [
        Offset(112, 415), Offset(177, 420),
        Offset(168, 560), Offset(151, 598),
        Offset(91, 592), Offset(101, 520),
      ]),
      gradient(
        const Rect.fromLTWH(90, 415, 90, 185),
        [gold, blue, navy, red],
        vertical: true,
      ),
    );

    c.drawPath(
      polygon(const [
        Offset(183, 420), Offset(248, 415),
        Offset(259, 520), Offset(269, 592),
        Offset(209, 598), Offset(192, 560),
      ]),
      gradient(
        const Rect.fromLTWH(180, 415, 100, 185),
        [red, blue, navy, gold],
        vertical: true,
      ),
    );

    // ألواح الفخذ.
    c.drawPath(
      polygon(const [
        Offset(109, 438), Offset(164, 442),
        Offset(154, 492), Offset(106, 489),
      ]),
      gradient(
        const Rect.fromLTWH(105, 438, 60, 55),
        [gold, Color(0xFF9B5D1B)],
      ),
    );

    c.drawPath(
      polygon(const [
        Offset(196, 442), Offset(251, 438),
        Offset(254, 489), Offset(206, 492),
      ]),
      gradient(
        const Rect.fromLTWH(195, 438, 60, 55),
        [gold, Color(0xFF9B5D1B)],
      ),
    );

    // الركبتان.
    rounded(
      c,
      const Rect.fromLTWH(111, 500, 43, 34),
      9,
      gradient(
        const Rect.fromLTWH(111, 500, 43, 34),
        [cyan, blue, navy],
      ),
    );
    rounded(
      c,
      const Rect.fromLTWH(206, 500, 43, 34),
      9,
      gradient(
        const Rect.fromLTWH(206, 500, 43, 34),
        [cyan, blue, navy],
      ),
    );

    // الحذاء.
    rounded(
      c,
      const Rect.fromLTWH(77, 575, 92, 32),
      12,
      gradient(
        const Rect.fromLTWH(77, 575, 92, 32),
        [blue, navy, red],
      ),
    );
    rounded(
      c,
      const Rect.fromLTWH(191, 575, 92, 32),
      12,
      gradient(
        const Rect.fromLTWH(191, 575, 92, 32),
        [red, navy, blue],
      ),
    );

    // الذراعان.
    c.drawPath(
      polygon([
        Offset(103, shoulder + 8),
        const Offset(50, 258),
        const Offset(29, 350),
        const Offset(49, 419),
        const Offset(86, 414),
        const Offset(80, 350),
        const Offset(123, 286),
      ]),
      gradient(
        const Rect.fromLTWH(25, 235, 105, 190),
        [gold, red, blue, navy],
      ),
    );

    c.drawPath(
      polygon([
        Offset(257, shoulder + 8),
        const Offset(310, 258),
        const Offset(331, 350),
        const Offset(311, 419),
        const Offset(274, 414),
        const Offset(280, 350),
        const Offset(237, 286),
      ]),
      gradient(
        const Rect.fromLTWH(235, 235, 105, 190),
        [gold, red, blue, navy],
      ),
    );

    // الكتفان.
    c.drawOval(
      const Rect.fromLTWH(49, 222, 84, 70),
      gradient(
        const Rect.fromLTWH(49, 222, 84, 70),
        [gold, red, Color(0xFF76202C)],
      ),
    );
    c.drawOval(
      const Rect.fromLTWH(227, 222, 84, 70),
      gradient(
        const Rect.fromLTWH(227, 222, 84, 70),
        [gold, red, Color(0xFF76202C)],
      ),
    );

    // الجذع.
    c.drawPath(
      polygon([
        Offset(112, shoulder),
        Offset(248, shoulder),
        const Offset(270, 390),
        const Offset(235, 455),
        const Offset(125, 455),
        const Offset(90, 390),
      ]),
      gradient(
        const Rect.fromLTWH(90, 230, 180, 230),
        [Color(0xFF164E91), navy, Color(0xFF050B16)],
        vertical: true,
      ),
    );

    // الدرع الأمامي.
    c.drawPath(
      polygon(const [
        Offset(117, 251), Offset(243, 251),
        Offset(260, 320), Offset(228, 367),
        Offset(132, 367), Offset(100, 320),
      ]),
      gradient(
        const Rect.fromLTWH(100, 250, 160, 120),
        [gold, red, blue, navy],
        vertical: true,
      ),
    );

    c.drawPath(
      polygon(const [
        Offset(127, 263), Offset(233, 263),
        Offset(246, 316), Offset(220, 350),
        Offset(140, 350), Offset(114, 316),
      ]),
      gradient(
        const Rect.fromLTWH(114, 263, 132, 87),
        [Color(0xFF0755B8), Color(0xFF061B3A)],
        vertical: true,
      ),
    );

    // إطار ذهبي حول شعار الصدر.
    c.drawPath(
      polygon(const [
        Offset(127, 263), Offset(233, 263),
        Offset(246, 316), Offset(220, 350),
        Offset(140, 350), Offset(114, 316),
      ]),
      paint(gold, style: PaintingStyle.stroke)..strokeWidth = 2.5,
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

    logo.paint(c, Offset(180 - logo.width / 2, 294));

    // مفاعل الطاقة.
    glow(c, const Offset(180, 390), 24, cyan);
    c.drawCircle(
      const Offset(180, 390),
      13,
      gradient(
        const Rect.fromCircle(
          center: Offset(180, 390),
          radius: 13,
        ),
        [Colors.white, cyan, blue],
      ),
    );
    c.drawCircle(
      const Offset(180, 390),
      18,
      paint(gold, style: PaintingStyle.stroke)..strokeWidth = 2,
    );

    // خطوط الطاقة.
    final energy = paint(cyan, style: PaintingStyle.stroke)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    c.drawPath(
      polygon(const [
        Offset(117, 365), Offset(137, 385),
        Offset(125, 411), Offset(148, 428),
      ]),
      energy,
    );
    c.drawPath(
      polygon(const [
        Offset(243, 365), Offset(223, 385),
        Offset(235, 411), Offset(212, 428),
      ]),
      energy,
    );
  }

  void drawHead(Canvas c) {
    c.save();
    c.translate(rotation.dx * 10, rotation.dy * 7);

    // الرقبة والياقة أسفل الوجه فقط.
    rounded(
      c,
      const Rect.fromLTWH(151, 190, 58, 61),
      16,
      gradient(
        const Rect.fromLTWH(151, 190, 58, 61),
        [Color(0xFFE2AE8C), skin, Color(0xFF85513F)],
        vertical: true,
      ),
    );

    rounded(
      c,
      const Rect.fromLTWH(139, 222, 82, 22),
      8,
      gradient(
        const Rect.fromLTWH(139, 222, 82, 22),
        [red, gold, navy],
      ),
    );

    // الأذنان.
    c.drawOval(
      const Rect.fromLTWH(119, 117, 25, 43),
      paint(skin),
    );
    c.drawOval(
      const Rect.fromLTWH(216, 117, 25, 43),
      paint(skin),
    );

    // الوجه ظاهر بالكامل.
    const face = Rect.fromLTWH(128, 53, 104, 157);
    c.drawOval(
      face,
      gradient(face, [
        Color(0xFFE7B18E),
        skin,
        Color(0xFFB9785B),
      ], vertical: true),
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

    c.drawPath(
      hairPath,
      gradient(
        const Rect.fromLTWH(125, 35, 110, 90),
        [Color(0xFF3A3A40), hair, Color(0xFF090D15)],
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

    final browPaint = paint(hair, style: PaintingStyle.stroke)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    c.drawPath(leftBrow, browPaint);
    c.drawPath(rightBrow, browPaint);

    final surprised = status.expression == HeroExpression.surprise;
    final angry = status.expression == HeroExpression.angry;
    final wink = status.expression == HeroExpression.wink;
    final blink = status.expression == HeroExpression.blink;

    // العينان.
    for (final x in [157.0, 203.0]) {
      final closed = blink || (wink && x == 203.0);

      if (closed) {
        c.drawLine(
          Offset(x - 11, 128),
          Offset(x + 11, 128),
          paint(hair, style: PaintingStyle.stroke)
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round,
        );
      } else {
        c.drawOval(
          Rect.fromCenter(
            center: Offset(x, 128),
            width: 25,
            height: surprised ? 16 : 12,
          ),
          paint(Colors.white),
        );
        c.drawCircle(
          Offset(x, 128),
          5,
          paint(const Color(0xFF38251F)),
        );
        c.drawCircle(
          Offset(x - 1.5, 126),
          1.5,
          paint(Colors.white),
        );
      }
    }

    if (angry) {
      c.drawLine(
        const Offset(145, 108),
        const Offset(171, 117),
        paint(hair, style: PaintingStyle.stroke)..strokeWidth = 3,
      );
      c.drawLine(
        const Offset(190, 117),
        const Offset(216, 108),
        paint(hair, style: PaintingStyle.stroke)..strokeWidth = 3,
      );
    }

    // الأنف.
    final nose = Path()
      ..moveTo(181, 129)
      ..quadraticBezierTo(175, 151, 180, 154)
      ..quadraticBezierTo(185, 158, 190, 153);

    c.drawPath(
      nose,
      paint(
        const Color(0xFF925D4B),
        style: PaintingStyle.stroke,
      )..strokeWidth = 2,
    );

    // الفم والتعبيرات.
    final smile = status.expression == HeroExpression.smile;
    final sad = status.expression == HeroExpression.sad;
    const mouthY = 174.0;

    if (status.isSpeaking && status.activeViseme != 'sil') {
      final height = switch (status.activeViseme) {
        'aa' || 'O' || 'U' => 12.0,
        'E' || 'I' => 5.0,
        _ => 7.0,
      };

      c.drawOval(
        Rect.fromCenter(
          center: const Offset(180, mouthY),
          width: 20,
          height: height,
        ),
        paint(const Color(0xFF55252B)),
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

      c.drawPath(
        mouth,
        paint(
          const Color(0xFF713A35),
          style: PaintingStyle.stroke,
        )
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }

    c.restore();
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

    drawBackground(canvas);

    canvas.save();
    final lean = animationName == 'Hero_Welcome'
        ? -.025
        : animationName == 'Hero_Power'
            ? .018
            : 0.0;

    canvas.translate(180, 320);
    canvas.rotate(lean + rotation.dx * .08);
    canvas.translate(-180, -320);

    drawBody(canvas);
    drawHead(canvas);

    canvas.restore();

    // قاعدة ضوء أسفل الشخصية.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(180, 618),
        width: 170 + motion * 5,
        height: 9,
      ),
      paint(cyan, style: PaintingStyle.stroke)..strokeWidth = 2,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HeroPainter old) {
    return old.status.revision != status.revision ||
        old.motion != motion ||
        old.rotation != rotation ||
        old.animationName != animationName ||
        old.compact != compact;
  }
}
