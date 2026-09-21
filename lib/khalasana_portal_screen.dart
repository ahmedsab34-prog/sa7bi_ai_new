import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'chat_screen.dart';

class KhalasanaPortalScreen extends StatefulWidget {
  const KhalasanaPortalScreen({
    super.key,
  });

  static const Color gold =
      Color(0xFFFFD76A);

  static const Color cyan =
      Color(0xFF63E6FF);

  static const Color purple =
      Color(0xFF8B6CFF);

  static const Color background =
      Color(0xFF050710);

  static const String _context = '''
أنت خلصانة AI، المساعد الشامل داخل تطبيق صاحبي.

أنت نقطة المساعدة العامة للمستخدم، ولا تطلب منه اختيار قسم قبل أن تبدأ في مساعدته.

يمكن للمستخدم:
- طرح أي سؤال.
- إرسال صورة لتحليلها.
- طلب إنشاء صورة.
- التحدث بالصوت.
- طلب مساعدة في الطعام والمطبخ.
- التسوق والمنتجات.
- التجارة والتسويق.
- الرياضة والهوايات.
- الأفلام والألعاب.
- الدراسة والعمل.
- التصوير والتصميم والإعلانات.
- المشاكل المنزلية والحرفيين.
- الأفكار والمشروعات.
- التطبيقات والتقنية.
- الفضفضة والمحادثات الشخصية.
- البودكاست والمحتوى.

إذا كان الطلب يحتاج صورة، استخدم مسار إنشاء الصور الموجود في التطبيق.
إذا أرسل المستخدم صورة، حللها ووضح ما يمكن استنتاجه منها.
إذا كان الطلب متعلقًا بخدمة معينة، استخدم أفضل سياق مناسب للموضوع تلقائيًا.
لا تجبر المستخدم على اختيار قسم يدويًا.

كن واضحًا ومفيدًا ومباشرًا.
لا تدّعي تنفيذ شيء لم يتم تنفيذه فعليًا.
إذا فشلت خدمة فعلية، وضح المشكلة وحاول تقديم بديل مفيد.
''';

  @override
  State<KhalasanaPortalScreen> createState() =>
      _KhalasanaPortalScreenState();
}

class _KhalasanaPortalScreenState
    extends State<KhalasanaPortalScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;

  @override
  void initState() {
    super.initState();

    _animation = AnimationController(
      vsync: this,
      duration:
          const Duration(seconds: 9),
    )..repeat();
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  void _openChat(
    BuildContext context,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ChatScreen(
          serviceTitle: 'خلصانة AI',
          serviceContext:
              KhalasanaPortalScreen._context,
        ),
      ),
    );
  }

  void _openVoice(
    BuildContext context,
  ) {
    _openChat(context);
  }

  void _openMedia(
    BuildContext context,
  ) {
    _openChat(context);
  }

  void _openText(
    BuildContext context,
  ) {
    _openChat(context);
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          KhalasanaPortalScreen.background,
      body: AnimatedBuilder(
        animation: _animation,
        builder: (_, __) {
          return Stack(
            children: [
              Positioned.fill(
                child: _KhalasanaBackground(
                  progress:
                      _animation.value,
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    _TopBar(
                      onBack: () =>
                          Navigator.pop(
                        context,
                      ),
                    ),
                    Expanded(
                      child:
                          SingleChildScrollView(
                        physics:
                            const BouncingScrollPhysics(),
                        padding:
                            const EdgeInsets.fromLTRB(
                          18,
                          6,
                          18,
                          25,
                        ),
                        child: Column(
                          children: [
                            const SizedBox(
                              height: 8,
                            ),
                            _KhalasanaHero(
                              progress:
                                  _animation.value,
                            ),
                            const SizedBox(
                              height: 19,
                            ),
                            const _IntroCard(),
                            const SizedBox(
                              height: 18,
                            ),
                            _ThreeActions(
                              onVoice: () =>
                                  _openVoice(
                                context,
                              ),
                              onMedia: () =>
                                  _openMedia(
                                context,
                              ),
                              onText: () =>
                                  _openText(
                                context,
                              ),
                            ),
                            const SizedBox(
                              height: 18,
                            ),
                            _StartCard(
                              onTap: () =>
                                  _openChat(
                                context,
                              ),
                            ),
                            const SizedBox(
                              height: 13,
                            ),
                            const Text(
                              'كل ده من مكان واحد — خلصانة مع صاحبي AI',
                              textDirection:
                                  TextDirection.rtl,
                              textAlign:
                                  TextAlign.center,
                              style:
                                  TextStyle(
                                color:
                                    Colors.white30,
                                fontSize:
                                    11,
                                fontWeight:
                                    FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TopBar
    extends StatelessWidget {
  final VoidCallback onBack;

  const _TopBar({
    required this.onBack,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        14,
        8,
        14,
        2,
      ),
      child: Row(
        children: [
          _GlassButton(
            icon:
                Icons.arrow_back_rounded,
            onTap: onBack,
          ),
          const Spacer(),
          Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              const Text(
                'AI',
                style: TextStyle(
                  color:
                      KhalasanaPortalScreen.cyan,
                  fontSize: 9,
                  fontWeight:
                      FontWeight.w900,
                  letterSpacing:
                      2.8,
                ),
              ),
              const SizedBox(
                height: 1,
              ),
              const Text(
                'خلصانة',
                textDirection:
                    TextDirection.rtl,
                style: TextStyle(
                  color:
                      KhalasanaPortalScreen.gold,
                  fontSize: 17,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
            ],
          ),
          const Spacer(),
          const SizedBox(
            width: 44,
          ),
        ],
      ),
    );
  }
}

class _GlassButton
    extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(
          15,
        ),
        child: Container(
          width: 43,
          height: 43,
          decoration:
              BoxDecoration(
            color: Colors.white
                .withOpacity(0.045),
            borderRadius:
                BorderRadius.circular(
              15,
            ),
            border: Border.all(
              color: Colors.white
                  .withOpacity(0.09),
            ),
          ),
          child: const Icon(
            Icons.arrow_back_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _KhalasanaHero
    extends StatelessWidget {
  final double progress;

  const _KhalasanaHero({
    required this.progress,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final pulse =
        (math.sin(
                  progress *
                      math.pi *
                      2,
                ) +
                1) /
            2;

    final rotate =
        progress *
            math.pi *
            2;

    return Column(
      children: [
        SizedBox(
          width: 190,
          height: 185,
          child: Stack(
            alignment:
                Alignment.center,
            children: [
              Transform.rotate(
                angle: -rotate,
                child: Container(
                  width: 166,
                  height: 166,
                  decoration:
                      BoxDecoration(
                    shape:
                        BoxShape.circle,
                    border:
                        Border.all(
                      color: KhalasanaPortalScreen
                          .gold
                          .withOpacity(
                        0.16 +
                            pulse *
                                0.12,
                      ),
                      width: 1.3,
                    ),
                  ),
                ),
              ),

              Transform.rotate(
                angle: rotate * 0.65,
                child: Container(
                  width: 143,
                  height: 143,
                  decoration:
                      BoxDecoration(
                    shape:
                        BoxShape.circle,
                    gradient:
                        const SweepGradient(
                      colors: [
                        KhalasanaPortalScreen.gold,
                        KhalasanaPortalScreen.cyan,
                        KhalasanaPortalScreen.purple,
                        KhalasanaPortalScreen.gold,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:
                            KhalasanaPortalScreen
                                .cyan
                                .withOpacity(
                          0.08 +
                              pulse *
                                  0.08,
                        ),
                        blurRadius: 34,
                        spreadRadius:
                            3,
                      ),
                    ],
                  ),
                ),
              ),

              Container(
                width: 126,
                height: 126,
                decoration:
                    BoxDecoration(
                  shape:
                      BoxShape.circle,
                  gradient:
                      const RadialGradient(
                    center:
                        Alignment(
                      -0.25,
                      -0.35,
                    ),
                    colors: [
                      Color(
                        0xFF27303D,
                      ),
                      Color(
                        0xFF111722,
                      ),
                      Color(
                        0xFF090D15,
                      ),
                    ],
                  ),
                  border:
                      Border.all(
                    color: Colors.white
                        .withOpacity(
                      0.13,
                    ),
                    width: 1.2,
                  ),
                ),
              ),

              Column(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  const Text(
                    'AI',
                    style:
                        TextStyle(
                      color:
                          KhalasanaPortalScreen
                              .cyan,
                      fontSize: 13,
                      fontWeight:
                          FontWeight.w900,
                      letterSpacing:
                          3,
                    ),
                  ),
                  const SizedBox(
                    height: 4,
                  ),
                  const Text(
                    'خلصانة',
                    textDirection:
                        TextDirection.rtl,
                    style:
                        TextStyle(
                      color:
                          KhalasanaPortalScreen
                              .gold,
                      fontSize: 26,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                  const SizedBox(
                    height: 3,
                  ),
                  Text(
                    'صاحبي',
                    textDirection:
                        TextDirection.rtl,
                    style:
                        TextStyle(
                      color: Colors.white
                          .withOpacity(
                        0.46 +
                            pulse *
                                0.15,
                      ),
                      fontSize: 9,
                      fontWeight:
                          FontWeight.w700,
                      letterSpacing:
                          1,
                    ),
                  ),
                ],
              ),

              Positioned(
                top: 24,
                right: 34,
                child: Transform.rotate(
                  angle: rotate,
                  child:
                      Container(
                    width: 6,
                    height: 6,
                    decoration:
                        const BoxDecoration(
                      shape:
                          BoxShape.circle,
                      color:
                          Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color:
                              KhalasanaPortalScreen
                                  .gold,
                          blurRadius:
                              9,
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
          height: 4,
        ),
        const Text(
          'خلصانة',
          textDirection:
              TextDirection.rtl,
          style: TextStyle(
            color: Colors.white,
            fontSize: 29,
            fontWeight:
                FontWeight.w900,
            height: 1.1,
          ),
        ),
        const SizedBox(
          height: 6,
        ),
        const Text(
          'المساعد الشامل بتاعك',
          textDirection:
              TextDirection.rtl,
          style: TextStyle(
            color:
                KhalasanaPortalScreen
                    .gold,
            fontSize: 13,
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _IntroCard
    extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.fromLTRB(
        17,
        16,
        17,
        15,
      ),
      decoration:
          BoxDecoration(
        color:
            const Color(0xFF10151F)
                .withOpacity(0.78),
        borderRadius:
            BorderRadius.circular(
          22,
        ),
        border:
            Border.all(
          color:
              KhalasanaPortalScreen
                  .gold
                  .withOpacity(0.13),
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black
                    .withOpacity(
              0.18,
            ),
            blurRadius: 20,
          ),
        ],
      ),
      child: const Column(
        children: [
          Text(
            'قول اللي في دماغك وخلاص',
            textDirection:
                TextDirection.rtl,
            textAlign:
                TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight:
                  FontWeight.w900,
            ),
          ),
          SizedBox(
            height: 7,
          ),
          Text(
            'مش محتاج تختار قسم. اتكلم، اكتب، ابعت صورة أو فيديو، وصاحبي يفهمك ويوجهك للمساعدة المناسبة.',
            textDirection:
                TextDirection.rtl,
            textAlign:
                TextAlign.center,
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreeActions
    extends StatelessWidget {
  final VoidCallback onVoice;
  final VoidCallback onMedia;
  final VoidCallback onText;

  const _ThreeActions({
    required this.onVoice,
    required this.onMedia,
    required this.onText,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,
      children: [
        const Text(
          'ابدأ بالطريقة اللي تريحك',
          textDirection:
              TextDirection.rtl,
          textAlign:
              TextAlign.right,
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight:
                FontWeight.w900,
          ),
        ),
        const SizedBox(
          height: 10,
        ),
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                icon:
                    Icons.mic_rounded,
                title:
                    'الصوت',
                subtitle:
                    'اتكلم مع صاحبي',
                color:
                    KhalasanaPortalScreen
                        .cyan,
                onTap: onVoice,
              ),
            ),
            const SizedBox(
              width: 8,
            ),
            Expanded(
              child: _ActionCard(
                icon:
                    Icons.photo_camera_rounded,
                title:
                    'الكاميرا',
                subtitle:
                    'صورة أو فيديو',
                color:
                    KhalasanaPortalScreen
                        .gold,
                onTap: onMedia,
              ),
            ),
            const SizedBox(
              width: 8,
            ),
            Expanded(
              child: _ActionCard(
                icon:
                    Icons.keyboard_rounded,
                title:
                    'الكتابة',
                subtitle:
                    'اكتب براحتك',
                color:
                    KhalasanaPortalScreen
                        .purple,
                onTap: onText,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionCard
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(
          19,
        ),
        child: Container(
          height: 117,
          padding:
              const EdgeInsets.symmetric(
            horizontal: 7,
            vertical: 12,
          ),
          decoration:
              BoxDecoration(
            color:
                Colors.white
                    .withOpacity(
              0.042,
            ),
            borderRadius:
                BorderRadius.circular(
              19,
            ),
            border:
                Border.all(
              color:
                  color.withOpacity(
                0.20,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color:
                    color.withOpacity(
                  0.035,
                ),
                blurRadius: 18,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Container(
                width: 43,
                height: 43,
                decoration:
                    BoxDecoration(
                  shape:
                      BoxShape.circle,
                  color:
                      color.withOpacity(
                    0.09,
                  ),
                  border:
                      Border.all(
                    color:
                        color.withOpacity(
                      0.28,
                    ),
                  ),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(
                height: 8,
              ),
              Text(
                title,
                textDirection:
                    TextDirection.rtl,
                style:
                    const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
              const SizedBox(
                height: 3,
              ),
              Text(
                subtitle,
                textDirection:
                    TextDirection.rtl,
                textAlign:
                    TextAlign.center,
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style:
                    const TextStyle(
                  color:
                      Colors.white38,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StartCard
    extends StatelessWidget {
  final VoidCallback onTap;

  const _StartCard({
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width: double.infinity,
      decoration:
          BoxDecoration(
        borderRadius:
            BorderRadius.circular(
          21,
        ),
        boxShadow: [
          BoxShadow(
            color:
                KhalasanaPortalScreen
                    .gold
                    .withOpacity(0.12),
            blurRadius: 28,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius:
              BorderRadius.circular(
            21,
          ),
          child: Ink(
            padding:
                const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 17,
            ),
            decoration:
                BoxDecoration(
              borderRadius:
                  BorderRadius.circular(
                21,
              ),
              gradient:
                  const LinearGradient(
                begin:
                    Alignment.centerRight,
                end:
                    Alignment.centerLeft,
                colors: [
                  Color(0xFFFFE58F),
                  Color(0xFFFFC84D),
                ],
              ),
            ),
            child: const Row(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.black,
                  size: 20,
                ),
                SizedBox(
                  width: 8,
                ),
                Text(
                  'افتح خلصانة وابدأ الكلام',
                  textDirection:
                      TextDirection.rtl,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 15,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                SizedBox(
                  width: 7,
                ),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.black,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KhalasanaBackground
    extends StatelessWidget {
  final double progress;

  const _KhalasanaBackground({
    required this.progress,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return CustomPaint(
      painter:
          _BackgroundPainter(
        progress: progress,
      ),
    );
  }
}

class _BackgroundPainter
    extends CustomPainter {
  final double progress;

  _BackgroundPainter({
    required this.progress,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final paint =
        Paint();

    final pulse =
        (math.sin(
                  progress *
                      math.pi *
                      2,
                ) +
                1) /
            2;

    final x =
        math.sin(
              progress *
                  math.pi *
                  2,
            ) *
            0.35;

    final y =
        math.cos(
              progress *
                  math.pi *
                  2,
            ) *
            0.20;

    final goldGlow =
        RadialGradient(
      center:
          Alignment(
        0.55 + x * 0.4,
        -0.70 + y * 0.3,
      ),
      radius: 1.05,
      colors: [
        KhalasanaPortalScreen.gold
            .withOpacity(
          0.09 +
              pulse * 0.045,
        ),
        Colors.transparent,
      ],
    );

    paint.shader =
        goldGlow.createShader(
      Offset.zero & size,
    );

    canvas.drawRect(
      Offset.zero & size,
      paint,
    );

    final cyanGlow =
        RadialGradient(
      center:
          Alignment(
        -0.85 - x * 0.3,
        0.62 - y * 0.25,
      ),
      radius: 1.0,
      colors: [
        KhalasanaPortalScreen.cyan
            .withOpacity(
          0.055 +
              pulse * 0.035,
        ),
        Colors.transparent,
      ],
    );

    paint.shader =
        cyanGlow.createShader(
      Offset.zero & size,
    );

    canvas.drawRect(
      Offset.zero & size,
      paint,
    );

    final purpleGlow =
        RadialGradient(
      center:
          Alignment(
        0.85,
        0.55,
      ),
      radius: 0.9,
      colors: [
        KhalasanaPortalScreen.purple
            .withOpacity(
          0.045,
        ),
        Colors.transparent,
      ],
    );

    paint.shader =
        purpleGlow.createShader(
      Offset.zero & size,
    );

    canvas.drawRect(
      Offset.zero & size,
      paint,
    );

    paint.shader = null;

    paint.color =
        Colors.white.withOpacity(
      0.022,
    );

    for (
      double yy = 0;
      yy < size.height;
      yy += 45
    ) {
      for (
        double xx = 0;
        xx < size.width;
        xx += 45
      ) {
        final offsetX =
            math.sin(
                  progress *
                      math.pi *
                      2 +
                      yy * 0.015,
                ) *
                3;

        final offsetY =
            math.cos(
                  progress *
                      math.pi *
                      2 +
                      xx * 0.01,
                ) *
                2;

        canvas.drawCircle(
          Offset(
            xx + 22 + offsetX,
            yy + 22 + offsetY,
          ),
          1,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(
    covariant _BackgroundPainter
        oldDelegate,
  ) {
    return oldDelegate.progress !=
        progress;
  }
}
