import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'audio_center_screen.dart';
import 'chat_screen.dart';
import 'service_config.dart';

class ServiceDetailScreen extends StatefulWidget {
  final Sa7biService service;

  const ServiceDetailScreen({
    super.key,
    required this.service,
  });

  @override
  State<ServiceDetailScreen> createState() =>
      _ServiceDetailScreenState();
}

class _ServiceDetailScreenState
    extends State<ServiceDetailScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  Sa7biService get service => widget.service;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ============================================================
  // CHAT
  // ============================================================

  void _openChat(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          serviceKey: service.serviceKey,
          serviceTitle: service.title,
          serviceContext: service.aiRole,
        ),
      ),
    );
  }

  // ============================================================
  // AUDIO
  // ============================================================

  void _openAudio(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AudioCenterScreen(),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05070D),
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (_, __) {
                return CustomPaint(
                  painter: _ServiceBackgroundPainter(
                    color: service.color,
                    angle: _controller.value * math.pi * 2,
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
                  onAudio: () => _openAudio(context),
                ),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      12,
                      4,
                      12,
                      20,
                    ),
                    children: [
                      _Hero(
                        service: service,
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      _ToolGrid(
                        color: service.color,
                        onChat: () => _openChat(context),
                        onAudio: () => _openAudio(context),

                        // أدوات الكاميرا والفيديو
                        // تدخل إلى ChatScreen الحقيقي،
                        // حيث توجد أدوات الكاميرا والفيديو
                        // والتحليل الفعلي.
                        onCamera: () => _openChat(context),
                        onVideo: () => _openChat(context),
                        onSpeech: () => _openChat(context),
                        onImage: () => _openChat(context),
                        onEdit: () => _openChat(context),
                        onText: () => _openChat(context),
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      _Start(
                        color: service.color,
                        onTap: () => _openChat(context),
                      ),
                    ],
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

// ============================================================
// TOP BAR
// ============================================================

class _TopBar extends StatelessWidget {
  final Sa7biService service;
  final VoidCallback onBack;
  final VoidCallback onAudio;

  const _TopBar({
    required this.service,
    required this.onBack,
    required this.onAudio,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        10,
        6,
        10,
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
              const Text(
                'صاحبي AI',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 9,
                ),
              ),
            ],
          ),
          const Spacer(),
          _CircleButton(
            icon: Icons.graphic_eq_rounded,
            onPressed: onAudio,
          ),
        ],
      ),
    );
  }
}

// ============================================================
// CIRCLE BUTTON
// ============================================================

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
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white12,
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

// ============================================================
// HERO
// ============================================================

class _Hero extends StatelessWidget {
  final Sa7biService service;

  const _Hero({
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        15,
        14,
        15,
        14,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            service.color.withOpacity(0.22),
            const Color(0xFF111722),
            const Color(0xFF090C13),
          ],
        ),
        border: Border.all(
          color: service.color.withOpacity(0.30),
        ),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: service.color.withOpacity(0.10),
              border: Border.all(
                color: service.color.withOpacity(0.45),
              ),
            ),
            child: Icon(
              service.icon,
              color: service.color,
              size: 31,
            ),
          ),
          const SizedBox(
            width: 12,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  service.title,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(
                  height: 5,
                ),
                Text(
                  service.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 11,
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

// ============================================================
// TOOLS GRID
// ============================================================

class _ToolGrid extends StatelessWidget {
  final Color color;

  final VoidCallback onChat;
  final VoidCallback onAudio;
  final VoidCallback onCamera;
  final VoidCallback onVideo;
  final VoidCallback onSpeech;
  final VoidCallback onImage;
  final VoidCallback onEdit;
  final VoidCallback onText;

  const _ToolGrid({
    required this.color,
    required this.onChat,
    required this.onAudio,
    required this.onCamera,
    required this.onVideo,
    required this.onSpeech,
    required this.onImage,
    required this.onEdit,
    required this.onText,
  });

  @override
  Widget build(BuildContext context) {
    final items = <_Tool>[
      _Tool(
        Icons.chat_bubble_rounded,
        'محادثة',
        onChat,
      ),
      _Tool(
        Icons.graphic_eq_rounded,
        'صوت / قرآن',
        onAudio,
      ),
      _Tool(
        Icons.camera_alt_rounded,
        'كاميرا',
        onCamera,
      ),
      _Tool(
        Icons.videocam_rounded,
        'فيديو',
        onVideo,
      ),
      _Tool(
        Icons.mic_rounded,
        'تحدث',
        onSpeech,
      ),
      _Tool(
        Icons.image_rounded,
        'إنشاء صورة',
        onImage,
      ),
      _Tool(
        Icons.edit_rounded,
        'تعديل صورة',
        onEdit,
      ),
      _Tool(
        Icons.keyboard_rounded,
        'كتابة',
        onText,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 7,
        mainAxisSpacing: 7,
        mainAxisExtent: 82,
      ),
      itemBuilder: (
        context,
        index,
      ) {
        return _ToolCard(
          tool: items[index],
          color: color,
        );
      },
    );
  }
}

// ============================================================
// TOOL
// ============================================================

class _Tool {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _Tool(
    this.icon,
    this.title,
    this.onTap,
  );
}

// ============================================================
// TOOL CARD
// ============================================================

class _ToolCard extends StatelessWidget {
  final _Tool tool;
  final Color color;

  const _ToolCard({
    required this.tool,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: tool.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xCC111722),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withOpacity(0.24),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                tool.icon,
                color: color,
                size: 25,
              ),
              const SizedBox(
                height: 7,
              ),
              Text(
                tool.title,
                textDirection: TextDirection.rtl,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// START BUTTON
// ============================================================

class _Start extends StatelessWidget {
  final Color color;
  final VoidCallback onTap;

  const _Start({
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onTap,
      icon: const Icon(
        Icons.auto_awesome_rounded,
      ),
      label: const Text(
        'ابدأ مع مساعد القسم',
        style: TextStyle(
          fontWeight: FontWeight.w900,
        ),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: color.withOpacity(0.85),
        foregroundColor: Colors.black,
        minimumSize: const Size(
          double.infinity,
          52,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(17),
        ),
      ),
    );
  }
}

// ============================================================
// SERVICE BACKGROUND
// ============================================================

class _ServiceBackgroundPainter extends CustomPainter {
  final Color color;
  final double angle;

  const _ServiceBackgroundPainter({
    required this.color,
    required this.angle,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final center = Offset(
      size.width *
          (0.5 +
              math.sin(angle) * 0.18),
      size.height *
          (0.22 +
              math.cos(angle) * 0.10),
    );

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withOpacity(0.22),
          color.withOpacity(0.07),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: center,
          radius: size.longestSide * 0.65,
        ),
      );

    canvas.drawRect(
      Offset.zero & size,
      paint,
    );
  }

  @override
  bool shouldRepaint(
    covariant _ServiceBackgroundPainter oldDelegate,
  ) {
    return oldDelegate.angle != angle ||
        oldDelegate.color != color;
  }
}
