
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../audio_player_service.dart';
import '../services/profile_service.dart';

class AppHeader extends StatelessWidget {
  final VoidCallback? onProfileTap;
  final VoidCallback? onAudioTap;

  const AppHeader({super.key, this.onProfileTap, this.onAudioTap});

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Sa7biLogo(),
            const SizedBox(width: 5),
            const Expanded(child: _HeaderWelcome()),
            const SizedBox(width: 4),
            _HeaderAudioButton(onTap: onAudioTap),
            const SizedBox(width: 4),
            _HeaderProfileButton(onTap: onProfileTap),
          ],
        ),
      );
}

class _HeaderWelcome extends StatefulWidget {
  const _HeaderWelcome();

  @override
  State<_HeaderWelcome> createState() => _HeaderWelcomeState();
}

class _HeaderWelcomeState extends State<_HeaderWelcome>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _timer;

  static const _messages = [
    'أهلاً يا صاحبي 👋',
    'أنا معاك في كل حاجة 🤖',
    'قول اللي في بالك 💙',
    'خلينا ننجزها سوا 🚀',
  ];

  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);

    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        setState(() => _index = (_index + 1) % _messages.length);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Container(
          constraints: const BoxConstraints(minHeight: 46),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0xFF1B2130), Color(0xFF10131C)],
            ),
            border: Border.all(color: const Color(0x33FFD76A)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD76A)
                    .withValues(alpha: 0.04 + _controller.value * 0.05),
                blurRadius: 10,
              ),
            ],
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _messages[_index],
                    key: ValueKey(_index),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'صاحبي AI معاك كل يوم',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white54, fontSize: 8),
                ),
              ],
            ),
          ),
        ),
      );
}

class _HeaderAudioButton extends StatelessWidget {
  final VoidCallback? onTap;

  const _HeaderAudioButton({required this.onTap});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
        valueListenable: AudioController.isPlayingNotifier,
        builder: (context, playing, child) => _PulsingAudioButton(
          isPlaying: playing,
          onTap: onTap,
        ),
      );
}

class _PulsingAudioButton extends StatefulWidget {
  final bool isPlaying;
  final VoidCallback? onTap;

  const _PulsingAudioButton({
    required this.isPlaying,
    required this.onTap,
  });

  @override
  State<_PulsingAudioButton> createState() => _PulsingAudioButtonState();
}

class _PulsingAudioButtonState extends State<_PulsingAudioButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1450),
    );
    _sync();
  }

  @override
  void didUpdateWidget(covariant _PulsingAudioButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPlaying != widget.isPlaying) _sync();
  }

  void _sync() {
    if (widget.isPlaying) {
      _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'مركز الصوت',
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: 42,
            height: 42,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) => _AudioIndicator(
                progress: widget.isPlaying ? _controller.value : 0,
                isPlaying: widget.isPlaying,
              ),
            ),
          ),
        ),
      );
}

class _AudioIndicator extends StatelessWidget {
  final double progress;
  final bool isPlaying;

  const _AudioIndicator({
    required this.progress,
    required this.isPlaying,
  });

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: SweepGradient(
            transform: GradientRotation(progress * math.pi * 2),
            colors: const [
              Color(0xFFFFD76A),
              Color(0xFFFF4D8D),
              Color(0xFFB45CFF),
              Color(0xFF63E6FF),
              Color(0xFFFFD76A),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF63E6FF)
                  .withValues(alpha: isPlaying ? .30 : .12),
              blurRadius: isPlaying ? 12 : 7,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(1.5),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF10131C),
                    Color(0xFF171426),
                    Color(0xFF0B1018),
                  ],
                ),
              ),
              child: CustomPaint(
                painter: _AudioRainPainter(
                  progress: progress,
                  isPlaying: isPlaying,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      );
}

class _AudioRainPainter extends CustomPainter {
  final double progress;
  final bool isPlaying;

  const _AudioRainPainter({
    required this.progress,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 2 || size.height <= 2) return;

    const heights = [
      0.34, 0.55, 0.43, 0.78, 0.62, 0.95,
      0.52, 0.82, 0.44, 0.66, 0.36,
    ];
    const phases = [
      0.00, 0.37, 0.74, 1.11, 1.48, 1.85,
      2.22, 2.59, 2.96, 3.33, 3.70,
    ];
    const colors = [
      Color(0xFFFFD76A),
      Color(0xFF63E6FF),
      Color(0xFFFF4D8D),
      Color(0xFFB45CFF),
    ];

    final paint = Paint()..strokeCap = StrokeCap.round;
    final width = math.max(1.0, size.width - 8);

    for (var i = 0; i < heights.length; i++) {
      final x = 4 + width * i / (heights.length - 1);
      final phase = progress * math.pi * 2 + phases[i];
      final wave = isPlaying ? (math.sin(phase) + 1) / 2 : .15;
      final base = size.height * (.16 + heights[i] * .38);
      final h = isPlaying ? base * (.60 + wave * .90) : base * .65;
      final fall = isPlaying
          ? (progress + phases[i] / (math.pi * 2)) % 1.0
          : .5;
      final top = fall * (size.height + h) - h;
      final maxY = math.max(1.0, size.height - 1);

      paint
        ..color = colors[(i + (progress * 4).floor()) % colors.length]
            .withValues(alpha: isPlaying ? .30 + wave * .70 : .38)
        ..strokeWidth = i.isEven ? 1.7 : 1.4;

      canvas.drawLine(
        Offset(x, top.clamp(1.0, maxY).toDouble()),
        Offset(x, (top + h).clamp(1.0, maxY).toDouble()),
        paint,
      );
    }

    final center = size.height / 2;
    final wavePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.1
      ..color = const Color(0xFFFFD76A)
          .withValues(alpha: isPlaying ? .70 : .28);

    final path = Path();
    for (var i = 0; i <= 24; i++) {
      final x = 3 + (size.width - 6) * i / 24;
      final y = center +
          math.sin(i / 24 * math.pi * 2 + progress * math.pi * 2) *
              (isPlaying ? 2.0 : .7);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, wavePaint);
  }

  @override
  bool shouldRepaint(covariant _AudioRainPainter old) =>
      old.progress != progress || old.isPlaying != isPlaying;
}

class _HeaderProfileButton extends StatelessWidget {
  final VoidCallback? onTap;

  const _HeaderProfileButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final profile = ProfileService.instance;

    return AnimatedBuilder(
      animation: profile.changes,
      builder: (context, child) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 48,
          height: 54,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ProfileAvatar(profile: profile),
              const SizedBox(height: 2),
              SizedBox(
                width: 48,
                child: Text(
                  profile.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final ProfileService profile;

  const _ProfileAvatar({required this.profile});

  @override
  Widget build(BuildContext context) {
    final photo = profile.photoBytes;
    final reel = profile.hasReel;

    final avatar = Container(
      width: 37,
      height: 37,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: reel
            ? const SweepGradient(
                colors: [
                  Color(0xFFFFD76A),
                  Color(0xFFFF4D8D),
                  Color(0xFFB45CFF),
                  Color(0xFF63E6FF),
                  Color(0xFFFFD76A),
                ],
              )
            : const LinearGradient(
                colors: [Color(0xFFFFD76A), Color(0xFF8B6A25)],
              ),
        boxShadow: [
          BoxShadow(
            color: (reel
                    ? const Color(0xFFB45CFF)
                    : const Color(0xFFFFD76A))
                .withValues(alpha: reel ? .30 : .16),
            blurRadius: reel ? 12 : 8,
          ),
        ],
      ),
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF10131C),
        ),
        child: ClipOval(
          child: photo != null && photo.isNotEmpty
              ? Image.memory(
                  photo,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) =>
                      const _DefaultProfileIcon(),
                )
              : const _DefaultProfileIcon(),
        ),
      ),
    );

    if (!reel) return avatar;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: -1,
          top: -1,
          child: Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF10131C),
              border: Border.all(
                color: const Color(0xFFFFD76A),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Color(0xFFFF4D8D),
              size: 7,
            ),
          ),
        ),
      ],
    );
  }
}

class _DefaultProfileIcon extends StatelessWidget {
  const _DefaultProfileIcon();

  @override
  Widget build(BuildContext context) => const Icon(
        Icons.person_rounded,
        color: Color(0xFFFFD76A),
        size: 20,
      );
}

class Sa7biLogo extends StatefulWidget {
  const Sa7biLogo({super.key});

  @override
  State<Sa7biLogo> createState() => _Sa7biLogoState();
}

class _Sa7biLogoState extends State<Sa7biLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final angle = _controller.value * math.pi * 2;

          return SizedBox(
            width: 49,
            height: 49,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 47,
                  height: 47,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF132A55)
                            .withValues(alpha: .18),
                        blurRadius: 15,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                Transform.rotate(
                  angle: angle,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          Color(0xFF8A1834),
                          Color(0xFF183D72),
                          Color(0xFF254F82),
                          Color(0xFF5C1630),
                          Color(0xFF8A1834),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF070A12),
                    border: Border.all(
                      color: const Color(0xFF315277),
                      width: 1.8,
                    ),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'app_icon.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) =>
                          const Icon(
                        Icons.auto_awesome_rounded,
                        color: Color(0xFFFFD76A),
                        size: 21,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
}
