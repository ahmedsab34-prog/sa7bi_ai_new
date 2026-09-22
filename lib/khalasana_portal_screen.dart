import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'chat_screen.dart';
import 'config/service_keys.dart';

/// بوابة خلصانة AI.
///
/// الهدف من الشاشة بسيط:
/// - تعريف سريع بخلصانة.
/// - هوية بصرية مستقلة عن شعار صاحبي.
/// - زر واحد يفتح المحادثة الحقيقية.
/// - لا توجد هنا أدوات أو كروت مكررة؛ كل أدوات الصوت والصورة
///   والكاميرا وتوليد الصور موجودة داخل ChatScreen نفسها.
class KhalasanaPortalScreen extends StatefulWidget {
  const KhalasanaPortalScreen({
    super.key,
  });

  static const Color gold = Color(0xFFFFD76A);
  static const Color cyan = Color(0xFF63E6FF);
  static const Color purple = Color(0xFF8B6CFF);
  static const Color background = Color(0xFF050710);

  static const String contextText = '''
أنت خلصانة AI، المساعد الشامل داخل تطبيق صاحبي.

ساعد المستخدم مباشرة في أي موضوع بدون إجباره على اختيار قسم.
يمكنه الكتابة، إرسال صورة أو فيديو، استخدام الصوت، أو طلب إنشاء صورة.

إذا أرسل المستخدم صورة، حللها بقدر ما تسمح به الصورة ولا تخمن الأشياء غير الواضحة.
إذا طلب إنشاء صورة، استخدم مسار إنشاء الصور الموجود في التطبيق.
إذا كان الموضوع مرتبطًا بخدمة أو مجال محدد، استخدم أفضل سياق مناسب تلقائيًا.
كن واضحًا ومفيدًا ومباشرًا.
لا تدّعي تنفيذ شيء لم يتم تنفيذه فعليًا.
إذا فشلت خدمة فعلية، وضح ذلك وقدم بديلًا مفيدًا.
''';

  @override
  State<KhalasanaPortalScreen> createState() =>
      _KhalasanaPortalScreenState();
}

class _KhalasanaPortalScreenState extends State<KhalasanaPortalScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;

  @override
  void initState() {
    super.initState();

    _animation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  void _openChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ChatScreen(
          serviceKey: ServiceKeys.khalasana,
          serviceTitle: 'خلصانة AI',
          serviceContext: KhalasanaPortalScreen.contextText,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: AnimatedBuilder(
        animation: _animation,
        builder: (_, __) {
          return Stack(
            children: [
              Positioned.fill(
                child: _AnimatedBackground(
                  progress: _animation.value,
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                      child: Row(
                        children: [
                          _CircleButton(
                            icon: Icons.arrow_back_rounded,
                            onTap: () => Navigator.pop(context),
                          ),
                          const Spacer(),
                          const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'AI',
                                style: TextStyle(
                                  color: cyan,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 3,
                                ),
                              ),
                              SizedBox(height: 1),
                              Text(
                                'خلصانة',
                                textDirection: TextDirection.rtl,
                                style: TextStyle(
                                  color: gold,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          const SizedBox(width: 44),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                          22,
                          24,
                          22,
                          28,
                        ),
                        child: Column(
                          children: [
                            _KhalasanaMark(
                              progress: _animation.value,
                            ),
                            const SizedBox(height: 25),
                            const Text(
                              'قول اللي في دماغك وخلاص',
                              textDirection: TextDirection.rtl,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 9),
                            const Text(
                              'مساعد واحد يفهم الموضوع ويبدأ معاك من غير ما تختار قسم.',
                              textDirection: TextDirection.rtl,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 13,
                                height: 1.55,
                              ),
                            ),
                            const SizedBox(height: 25),
                            _InfoCard(
                              icon: Icons.auto_awesome_rounded,
                              title: 'محادثة واحدة',
                              text:
                                  'اكتب أو اتكلم، وابعت صورة أو استخدم الأدوات من داخل المحادثة.',
                            ),
                            const SizedBox(height: 10),
                            _InfoCard(
                              icon: Icons.psychology_alt_rounded,
                              title: 'يفهم الموضوع تلقائيًا',
                              text:
                                  'المظهر والسياق داخل الشات يتغيران حسب موضوع الكلام.',
                            ),
                            const SizedBox(height: 10),
                            _InfoCard(
                              icon: Icons.history_rounded,
                              title: 'محادثتك محفوظة',
                              text:
                                  'ارجع لنفس محادثة خلصانة في أي وقت من غير ما تختلط بمحادثات الخدمات الأخرى.',
                            ),
                            const SizedBox(height: 28),
                            _OpenChatButton(
                              onTap: _openChat,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'الكاميرا • الفيديو • الصوت • تحويل الكلام لنص • إنشاء الصور',
                              textDirection: TextDirection.rtl,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white30,
                                fontSize: 10.5,
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
          );
        },
      ),
    );
  }
}

class _KhalasanaMark extends StatelessWidget {
  final double progress;

  const _KhalasanaMark({
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final angle = progress * math.pi * 2;
    final pulse = (math.sin(angle) + 1) / 2;

    return SizedBox(
      width: 190,
      height: 190,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: -angle,
            child: Container(
              width: 176,
              height: 176,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: KhalasanaPortalScreen.cyan.withOpacity(
                    0.12 + pulse * 0.08,
                  ),
                  width: 1.4,
                ),
              ),
            ),
          ),
          Transform.rotate(
            angle: angle,
            child: Container(
              width: 151,
              height: 151,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: [
                    KhalasanaPortalScreen.gold,
                    KhalasanaPortalScreen.cyan,
                    KhalasanaPortalScreen.purple,
                    Color(0xFF49E6A8),
                    KhalasanaPortalScreen.gold,
                  ],
                ),
              ),
            ),
          ),
          Container(
            width: 135,
            height: 135,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                center: Alignment(-0.25, -0.35),
                colors: [
                  Color(0xFF28313F),
                  Color(0xFF111722),
                  Color(0xFF070A11),
                ],
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.14),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: KhalasanaPortalScreen.cyan.withOpacity(
                    0.05 + pulse * 0.08,
                  ),
                  blurRadius: 35,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'AI',
                  style: TextStyle(
                    color: KhalasanaPortalScreen.cyan,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'خلصانة',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    color: KhalasanaPortalScreen.gold,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'صاحبي AI',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Transform.rotate(
            angle: angle,
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: const EdgeInsets.only(top: 8),
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: KhalasanaPortalScreen.gold,
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF10151F).withOpacity(0.76),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(0.07),
        ),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: KhalasanaPortalScreen.gold.withOpacity(0.08),
              border: Border.all(
                color: KhalasanaPortalScreen.gold.withOpacity(0.16),
              ),
            ),
            child: Icon(
              icon,
              color: KhalasanaPortalScreen.gold,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  title,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11.5,
                    height: 1.45,
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

class _OpenChatButton extends StatelessWidget {
  final VoidCallback onTap;

  const _OpenChatButton({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 17),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [
                Color(0xFFFFD76A),
                Color(0xFFE7A93C),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: KhalasanaPortalScreen.gold.withOpacity(0.18),
                blurRadius: 24,
                spreadRadius: 1,
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.chat_bubble_rounded,
                color: Color(0xFF15100A),
                size: 21,
              ),
              SizedBox(width: 9),
              Text(
                'افتح خلصانة وابدأ الكلام',
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  color: Color(0xFF15100A),
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Ink(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.045),
            borderRadius: BorderRadius.circular(15),
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

class _AnimatedBackground extends StatelessWidget {
  final double progress;

  const _AnimatedBackground({
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final a = progress * math.pi * 2;

    return Stack(
      children: [
        Positioned(
          top: -120 + math.sin(a) * 18,
          right: -90 + math.cos(a * 0.8) * 22,
          child: _Glow(
            size: 300,
            color: KhalasanaPortalScreen.cyan,
          ),
        ),
        Positioned(
          bottom: -150 + math.cos(a * 0.7) * 20,
          left: -110 + math.sin(a * 0.6) * 18,
          child: _Glow(
            size: 330,
            color: KhalasanaPortalScreen.purple,
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  KhalasanaPortalScreen.background,
                  const Color(0xFF090C15),
                  KhalasanaPortalScreen.background,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  final double size;
  final Color color;

  const _Glow({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: size * 0.45,
              spreadRadius: size * 0.03,
            ),
          ],
        ),
      ),
    );
  }
}
