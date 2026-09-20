import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'chat_screen.dart';
import 'service_config.dart';

class ServiceDetailScreen extends StatefulWidget {
  final Sa7biService service;

  const ServiceDetailScreen({
    super.key,
    required this.service,
  });

  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  Sa7biService get service => widget.service;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openChat(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          serviceTitle: service.title,
          serviceContext: service.aiRole,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF06080E),
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (_, __) {
                final angle = _controller.value * math.pi * 2;

                return CustomPaint(
                  painter: _ServiceBackgroundPainter(
                    color: service.color,
                    angle: angle,
                  ),
                );
              },
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  service: service,
                  onBack: () => Navigator.pop(context),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      18,
                      8,
                      18,
                      24,
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),

                        _HeroCard(
                          service: service,
                          animation: _controller,
                        ),

                        const SizedBox(height: 18),

                        _CapabilitiesCard(
                          service: service,
                        ),

                        const SizedBox(height: 18),

                        _HowItWorksCard(
                          service: service,
                        ),

                        const SizedBox(height: 22),

                        _StartButton(
                          color: service.color,
                          onPressed: () => _openChat(context),
                        ),

                        const SizedBox(height: 11),

                        const Text(
                          'اكتب أو اتكلم أو ابعت صورة أو استخدم الكاميرا، وصاحبي هيساعدك داخل الخدمة.',
                          textDirection: TextDirection.rtl,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),

                        const SizedBox(height: 10),
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
  final Sa7biService service;
  final VoidCallback onBack;

  const _TopBar({
    required this.service,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        14,
        8,
        14,
        4,
      ),
      child: Row(
        children: [
          _CircleButton(
            icon: Icons.arrow_back_rounded,
            onPressed: onBack,
          ),
          const Spacer(),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                service.title,
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'صحبي AI',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
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

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _CircleButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.10),
            ),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 21,
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final Sa7biService service;
  final Animation<double> animation;

  const _HeroCard({
    required this.service,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) {
        final pulse =
            0.92 + (math.sin(animation.value * math.pi * 2) + 1) * 0.04;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(
            22,
            25,
            22,
            24,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                service.color.withOpacity(0.30),
                const Color(0xFF111521),
                const Color(0xFF090C13),
              ],
            ),
            border: Border.all(
              color: service.color.withOpacity(0.34),
            ),
            boxShadow: [
              BoxShadow(
                color: service.color.withOpacity(0.13),
                blurRadius: 35,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            children: [
              Transform.scale(
                scale: pulse,
                child: Container(
                  width: 108,
                  height: 108,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        service.color.withOpacity(0.32),
                        service.color.withOpacity(0.08),
                        Colors.transparent,
                      ],
                    ),
                    border: Border.all(
                      color: service.color.withOpacity(0.55),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF0C1019),
                        border: Border.all(
                          color: service.color.withOpacity(0.30),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: service.color.withOpacity(0.25),
                            blurRadius: 22,
                          ),
                        ],
                      ),
                      child: Icon(
                        service.icon,
                        color: service.color,
                        size: 40,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              Text(
                service.title,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                ),
              ),

              const SizedBox(height: 9),

              Text(
                service.description,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.65,
                ),
              ),

              const SizedBox(height: 15),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: service.color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: service.color.withOpacity(0.22),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 14,
                      color: service.color,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'مساعد ذكي متخصص',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CapabilitiesCard extends StatelessWidget {
  final Sa7biService service;

  const _CapabilitiesCard({
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassSection(
      color: service.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionTitle(
            icon: Icons.auto_awesome_rounded,
            title: 'إيه اللي تقدر تعمله هنا؟',
          ),

          const SizedBox(height: 15),

          Row(
            children: [
              Expanded(
                child: _Capability(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'محادثة',
                  color: service.color,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _Capability(
                  icon: Icons.mic_none_rounded,
                  title: 'صوت',
                  color: service.color,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _Capability(
                  icon: Icons.camera_alt_outlined,
                  title: 'كاميرا',
                  color: service.color,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _Capability(
                  icon: Icons.image_outlined,
                  title: 'صورة',
                  color: service.color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Capability extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const _Capability({
    required this.icon,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 12,
        horizontal: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.045),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 21,
          ),
          const SizedBox(height: 7),
          Text(
            title,
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _HowItWorksCard extends StatelessWidget {
  final Sa7biService service;

  const _HowItWorksCard({
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassSection(
      color: service.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionTitle(
            icon: Icons.tips_and_updates_outlined,
            title: 'ابدأ ببساطة',
          ),

          const SizedBox(height: 14),

          _StepRow(
            number: '1',
            title: 'احكي لصاحبي إنت محتاج إيه',
            subtitle: 'اكتب أو استخدم صوتك أو ابعت صورة.',
            color: service.color,
          ),

          const SizedBox(height: 11),

          _StepRow(
            number: '2',
            title: 'صاحبي يفهم نوع الخدمة',
            subtitle: 'الذكاء الاصطناعي بيشتغل حسب المجال ده.',
            color: service.color,
          ),

          const SizedBox(height: 11),

          _StepRow(
            number: '3',
            title: 'خد المساعدة ونفّذ اللي يناسبك',
            subtitle: 'وتقدر تكمل المحادثة وتضيف تفاصيل في أي وقت.',
            color: service.color,
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final String number;
  final String title;
  final String subtitle;
  final Color color;

  const _StepRow({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.14),
            border: Border.all(
              color: color.withOpacity(0.35),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),

        const SizedBox(width: 11),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                title,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionTitle({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      textDirection: TextDirection.rtl,
      children: [
        Icon(
          icon,
          color: Colors.white70,
          size: 19,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _GlassSection extends StatelessWidget {
  final Color color;
  final Widget child;

  const _GlassSection({
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D111A).withOpacity(0.88),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 24,
          ),
        ],
      ),
      child: child,
    );
  }
}

class _StartButton extends StatelessWidget {
  final Color color;
  final VoidCallback onPressed;

  const _StartButton({
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.24),
            blurRadius: 24,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            padding: const EdgeInsets.symmetric(
              vertical: 16,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [
                  color,
                  Color.lerp(
                        color,
                        Colors.white,
                        0.18,
                      ) ??
                      color,
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
                  'ابدأ مع صاحبي',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(width: 7),
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

class _ServiceBackgroundPainter extends CustomPainter {
  final Color color;
  final double angle;

  _ServiceBackgroundPainter({
    required this.color,
    required this.angle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = RadialGradient(
        center: Alignment(
          math.cos(angle) * 0.9,
          math.sin(angle) * 0.9,
        ),
        radius: 1.2,
        colors: [
          color.withOpacity(0.09),
          Colors.transparent,
        ],
      ).createShader(
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

    final dotPaint = Paint()
      ..color = color.withOpacity(0.035);

    for (double y = 0; y < size.height; y += 42) {
      for (double x = 0; x < size.width; x += 42) {
        canvas.drawCircle(
          Offset(x + 21, y + 21),
          1.1,
          dotPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(
    covariant _ServiceBackgroundPainter oldDelegate,
  ) {
    return oldDelegate.angle != angle ||
        oldDelegate.color != color;
  }
}
