import 'package:flutter/material.dart';

import 'chat_screen.dart';

class KhalasanaPortalScreen extends StatelessWidget {
  const KhalasanaPortalScreen({
    super.key,
  });

  static const Color gold = Color(0xFFFFD76A);
  static const Color background = Color(0xFF060811);

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
- الرياضة والهوايات.
- الأفلام والألعاب.
- الدراسة والعمل.
- التصوير والتصميم والإعلانات.
- المشاكل المنزلية والحرفيين.
- الأفكار والمشروعات.
- التطبيقات والتقنية.
- الفضفضة والمحادثات الشخصية.

إذا كان الطلب يحتاج صورة، استخدم مسار إنشاء الصور الموجود في التطبيق.
إذا أرسل المستخدم صورة، حللها ووضح ما يمكن استنتاجه منها.
إذا كان الطلب متعلقًا بخدمة معينة، استخدم أفضل سياق مناسب للموضوع تلقائيًا.
لا تجبر المستخدم على اختيار قسم يدويًا.

كن واضحًا ومفيدًا ومباشرًا.
لا تدّعي تنفيذ شيء لم يتم تنفيذه فعليًا.
إذا فشلت خدمة فعلية، وضح المشكلة وحاول تقديم بديل مفيد.
''';

  void _openChat(
    BuildContext context, {
    String? initialPrompt,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          serviceTitle: 'خلصانة AI',
          serviceContext: _context,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: Stack(
        children: [
          const Positioned.fill(
            child: _KhalasanaBackground(),
          ),
          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  onBack: () => Navigator.pop(context),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      18,
                      8,
                      18,
                      26,
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        const _KhalasanaHero(),
                        const SizedBox(height: 20),
                        const _IntroCard(),
                        const SizedBox(height: 18),
                        _QuickActions(
                          onAction: () => _openChat(context),
                        ),
                        const SizedBox(height: 22),
                        _StartCard(
                          onTap: () => _openChat(context),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'كل ده من مكان واحد — خلصانة مع صاحبي AI',
                          textDirection: TextDirection.rtl,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
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
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;

  const _TopBar({
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        14,
        8,
        14,
        2,
      ),
      child: Row(
        children: [
          _GlassButton(
            icon: Icons.arrow_back_rounded,
            onTap: onBack,
          ),
          const Spacer(),
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'خلصانة',
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  color: KhalasanaPortalScreen.gold,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 1),
              Text(
                'AI',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const Spacer(),
          const SizedBox(width: 44),
        ],
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.055),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.09),
            ),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _KhalasanaHero extends StatelessWidget {
  const _KhalasanaHero();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 138,
          height: 138,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [
                Color(0x55FFD76A),
                Color(0x18FFD76A),
                Colors.transparent,
              ],
            ),
            border: Border.all(
              color: KhalasanaPortalScreen.gold.withOpacity(0.32),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: KhalasanaPortalScreen.gold.withOpacity(0.14),
                blurRadius: 45,
                spreadRadius: 3,
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 94,
              height: 94,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0D111B),
                border: Border.all(
                  color: KhalasanaPortalScreen.gold.withOpacity(0.40),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        KhalasanaPortalScreen.gold.withOpacity(0.18),
                    blurRadius: 25,
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: KhalasanaPortalScreen.gold,
                size: 46,
              ),
            ),
          ),
        ),
        const SizedBox(height: 17),
        const Text(
          'خلصانة AI',
          textDirection: TextDirection.rtl,
          style: TextStyle(
            color: Colors.white,
            fontSize: 29,
            fontWeight: FontWeight.w900,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'المساعد الشامل بتاعك',
          textDirection: TextDirection.rtl,
          style: TextStyle(
            color: KhalasanaPortalScreen.gold,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        18,
        17,
        18,
        17,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0D111A).withOpacity(0.90),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: KhalasanaPortalScreen.gold.withOpacity(0.14),
        ),
      ),
      child: const Column(
        children: [
          Text(
            'قول اللي في دماغك وخلاص',
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'مش محتاج تختار قسم. اسأل، ابعت صورة، اتكلم، أو اطلب حاجة — وصاحبي يحاول يفهمك ويوجهك للمساعدة المناسبة.',
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white60,
              fontSize: 12,
              height: 1.65,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final VoidCallback onAction;

  const _QuickActions({
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'اختصارات سريعة',
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.right,
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 11),
        Row(
          children: [
            Expanded(
              child: _QuickAction(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'اسأل',
                subtitle: 'أي سؤال',
                onTap: onAction,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _QuickAction(
                icon: Icons.mic_none_rounded,
                title: 'اتكلم',
                subtitle: 'بالصوت',
                onTap: onAction,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _QuickAction(
                icon: Icons.image_outlined,
                title: 'صورة',
                subtitle: 'تحليل أو إنشاء',
                onTap: onAction,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(19),
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            8,
            14,
            8,
            13,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.045),
            borderRadius: BorderRadius.circular(19),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      KhalasanaPortalScreen.gold.withOpacity(0.09),
                  border: Border.all(
                    color:
                        KhalasanaPortalScreen.gold.withOpacity(0.18),
                  ),
                ),
                child: Icon(
                  icon,
                  color: KhalasanaPortalScreen.gold,
                  size: 20,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white38,
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

class _StartCard extends StatelessWidget {
  final VoidCallback onTap;

  const _StartCard({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: KhalasanaPortalScreen.gold.withOpacity(0.14),
            blurRadius: 30,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            padding: const EdgeInsets.symmetric(
              vertical: 17,
              horizontal: 18,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
                colors: [
                  Color(0xFFFFE28B),
                  Color(0xFFFFC94D),
                ],
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.black,
                  size: 21,
                ),
                SizedBox(width: 9),
                Text(
                  'افتح خلصانة وابدأ الكلام',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.black,
                  size: 19,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KhalasanaBackground extends StatelessWidget {
  const _KhalasanaBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BackgroundPainter(),
    );
  }
}

class _BackgroundPainter extends CustomPainter {
  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final paint = Paint();

    final firstGlow = RadialGradient(
      center: const Alignment(
        0.65,
        -0.85,
      ),
      radius: 1.0,
      colors: [
        KhalasanaPortalScreen.gold.withOpacity(0.12),
        Colors.transparent,
      ],
    );

    paint.shader = firstGlow.createShader(
      Rect.fromLTWH(
        0,
        0,
        size.width,
        size.height,
      ),
    );

    canvas.drawRect(
      Offset.zero & size,
      paint,
    );

    final secondGlow = RadialGradient(
      center: const Alignment(
        -0.9,
        0.65,
      ),
      radius: 1.15,
      colors: [
        const Color(0xFF7A5CFF).withOpacity(0.07),
        Colors.transparent,
      ],
    );

    paint.shader = secondGlow.createShader(
      Rect.fromLTWH(
        0,
        0,
        size.width,
        size.height,
      ),
    );

    canvas.drawRect(
      Offset.zero & size,
      paint,
    );

    paint.shader = null;
    paint.color = Colors.white.withOpacity(0.025);

    for (double y = 0; y < size.height; y += 44) {
      for (double x = 0; x < size.width; x += 44) {
        canvas.drawCircle(
          Offset(
            x + 22,
            y + 22,
          ),
          1,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(
    covariant CustomPainter oldDelegate,
  ) {
    return false;
  }
}
