import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio_player_service.dart';
import '../services/profile_service.dart';

/// الهيدر الرئيسي لتطبيق صاحبي AI.
///
/// الترتيب ثابت ولا يتم تغييره:
/// الشعار → الترحيب → الصوت → البروفايل
///
/// زر الصوت:
/// - الدائرة الخارجية ثابتة.
/// - الحركة تكون داخل الدائرة فقط أثناء تشغيل الصوت.
/// - البروفايل واللوجو والترحيب لا يتأثرون.
class AppHeader extends StatelessWidget {
  final VoidCallback? onProfileTap;
  final VoidCallback? onAudioTap;

  const AppHeader({
    super.key,
    this.onProfileTap,
    this.onAudioTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ======================================================
        // 1) SA7BI LOGO
        // ======================================================

        const Sa7biLogo(),

        const SizedBox(width: 9),

        // ======================================================
        // 2) WELCOME
        // ======================================================

        const Expanded(
          child: _HeaderWelcome(),
        ),

        const SizedBox(width: 7),

        // ======================================================
        // 3) AUDIO
        // ======================================================

        _HeaderAudioButton(
          onTap: onAudioTap,
        ),

        const SizedBox(width: 7),

        // ======================================================
        // 4) PROFILE
        // ======================================================

        _HeaderProfileButton(
          onTap: onProfileTap,
        ),
      ],
    );
  }
}

// ============================================================
// HEADER WELCOME
// ============================================================

class _HeaderWelcome extends StatefulWidget {
  const _HeaderWelcome();

  @override
  State<_HeaderWelcome> createState() =>
      _HeaderWelcomeState();
}

class _HeaderWelcomeState
    extends State<_HeaderWelcome>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  Timer? timer;

  final List<String> messages = const [
    'أهلاً يا صاحبي 👋',
    'أنا معاك في كل حاجة 🤖',
    'قول اللي في بالك 💙',
    'خلينا ننجزها سوا 🚀',
  ];

  int index = 0;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    timer = Timer.periodic(
      const Duration(seconds: 4),
      (_) {
        if (!mounted) return;

        setState(() {
          index = (index + 1) % messages.length;
        });
      },
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final glow =
            0.06 + controller.value * 0.08;

        return Container(
          constraints: const BoxConstraints(
            minHeight: 58,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                Color(0xFF1B2130),
                Color(0xFF10131C),
              ],
            ),
            border: Border.all(
              color: const Color(0x44FFD76A),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD76A)
                    .withOpacity(glow),
                blurRadius: 16,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            crossAxisAlignment:
                CrossAxisAlignment.end,
            children: [
              AnimatedSwitcher(
                duration:
                    const Duration(milliseconds: 350),
                child: Text(
                  messages[index],
                  key: ValueKey(index),
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  textDirection:
                      TextDirection.rtl,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'صاحبي AI معاك كل يوم',
                textDirection:
                    TextDirection.rtl,
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================
// AUDIO BUTTON
// ============================================================

class _HeaderAudioButton
    extends StatelessWidget {
  final VoidCallback? onTap;

  const _HeaderAudioButton({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable:
          AudioController.isPlayingNotifier,
      builder: (
        context,
        isPlaying,
        _,
      ) {
        return _PulsingAudioButton(
          isPlaying: isPlaying,
          onTap: onTap,
        );
      },
    );
  }
}

// ============================================================
// AUDIO BUTTON - FIXED OUTER CIRCLE
// ============================================================

class _PulsingAudioButton
    extends StatefulWidget {
  final bool isPlaying;
  final VoidCallback? onTap;

  const _PulsingAudioButton({
    required this.isPlaying,
    required this.onTap,
  });

  @override
  State<_PulsingAudioButton> createState() =>
      _PulsingAudioButtonState();
}

class _PulsingAudioButtonState
    extends State<_PulsingAudioButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 850,
      ),
    );

    _syncAnimation();
  }

  @override
  void didUpdateWidget(
    covariant _PulsingAudioButton oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isPlaying !=
        widget.isPlaying) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    if (widget.isPlaying) {
      controller.repeat();
    } else {
      controller.stop();
      controller.value = 0;
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 48,
        height: 48,
        child: AnimatedBuilder(
          animation: controller,
          builder: (_, __) {
            final t = widget.isPlaying
                ? controller.value
                : 0.0;

            return Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF10131C),
                border: Border.all(
                  color: const Color(
                    0xFF63E6FF,
                  ).withOpacity(
                    widget.isPlaying
                        ? 0.95
                        : 0.75,
                  ),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(
                      0xFF63E6FF,
                    ).withOpacity(
                      widget.isPlaying
                          ? 0.28
                          : 0.13,
                    ),
                    blurRadius:
                        widget.isPlaying
                            ? 18
                            : 11,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Center(
                child: SizedBox(
                  width: 30,
                  height: 25,
                  child: CustomPaint(
                    painter:
                        _AudioWavePainter(
                      progress: t,
                      isPlaying:
                          widget.isPlaying,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ============================================================
// INNER AUDIO WAVE
// ============================================================

class _AudioWavePainter
    extends CustomPainter {
  final double progress;
  final bool isPlaying;

  const _AudioWavePainter({
    required this.progress,
    required this.isPlaying,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final centerY = size.height / 2;

    final paint = Paint()
      ..color = const Color(0xFF63E6FF)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const barCount = 7;

    for (int i = 0; i < barCount; i++) {
      final x =
          2.0 +
          (i * (size.width - 4) /
              (barCount - 1));

      double height;

      if (!isPlaying) {
        height = i == 3 ? 9 : 5;
      } else {
        final wave =
            math.sin(
              (progress * math.pi * 2) +
                  (i * 0.85),
            );

        final wave2 =
            math.sin(
              (progress * math.pi * 4) +
                  (i * 0.45),
            );

        height =
            5.0 +
            ((wave + 1) / 2) * 11.0 +
            ((wave2 + 1) / 2) * 3.0;
      }

      final top =
          centerY - height / 2;
      final bottom =
          centerY + height / 2;

      canvas.drawLine(
        Offset(x, top),
        Offset(x, bottom),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant _AudioWavePainter oldDelegate,
  ) {
    return oldDelegate.progress !=
            progress ||
        oldDelegate.isPlaying !=
            isPlaying;
  }
}

// ============================================================
// PROFILE BUTTON
// ============================================================

class _HeaderProfileButton
    extends StatelessWidget {
  final VoidCallback? onTap;

  const _HeaderProfileButton({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final profile =
        ProfileService.instance;

    return AnimatedBuilder(
      animation: profile.changes,
      builder: (context, _) {
        return GestureDetector(
          onTap: onTap,
          child: SizedBox(
            width: 56,
            height: 67,
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                _ProfileAvatar(
                  profile: profile,
                ),
                const SizedBox(height: 2),
                SizedBox(
                  width: 56,
                  child: Text(
                    profile.displayName,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    textDirection:
                        TextDirection.rtl,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8.5,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================
// PROFILE AVATAR
// ============================================================

class _ProfileAvatar
    extends StatelessWidget {
  final ProfileService profile;

  const _ProfileAvatar({
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    final photo = profile.photoBytes;
    final hasReel = profile.hasReel;

    final avatar = Container(
      width: 43,
      height: 43,
      padding: const EdgeInsets.all(2.2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: hasReel
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
                colors: [
                  Color(0xFFFFD76A),
                  Color(0xFF8B6A25),
                ],
              ),
        boxShadow: [
          BoxShadow(
            color: hasReel
                ? const Color(
                    0xFFB45CFF,
                  ).withOpacity(0.35)
                : const Color(
                    0xFFFFD76A,
                  ).withOpacity(0.18),
            blurRadius:
                hasReel ? 15 : 11,
            spreadRadius:
                hasReel ? 1 : 0,
          ),
        ],
      ),
      child: Container(
        decoration:
            const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF10131C),
        ),
        child: ClipOval(
          child: photo != null &&
                  photo.isNotEmpty
              ? Image.memory(
                  photo,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (_, __, ___) {
                    return const Icon(
                      Icons.person_rounded,
                      color:
                          Color(0xFFFFD76A),
                      size: 22,
                    );
                  },
                )
              : const Icon(
                  Icons.person_rounded,
                  color:
                      Color(0xFFFFD76A),
                  size: 22,
                ),
        ),
      ),
    );

    if (!hasReel) {
      return avatar;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: -1,
          top: -1,
          child: Container(
            width: 12,
            height: 12,
            decoration:
                BoxDecoration(
              shape: BoxShape.circle,
              color:
                  const Color(0xFF10131C),
              border: Border.all(
                color:
                    const Color(
                  0xFFFFD76A,
                ),
                width: 1.1,
              ),
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color:
                  Color(0xFFFF4D8D),
              size: 7,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// SA7BI LOGO
// ============================================================

class Sa7biLogo
    extends StatefulWidget {
  const Sa7biLogo({
    super.key,
  });

  @override
  State<Sa7biLogo> createState() =>
      _Sa7biLogoState();
}

class _Sa7biLogoState
    extends State<Sa7biLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(
        seconds: 9,
      ),
    )..repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final rotation =
            controller.value *
            3.141592653589793 *
            2;

        return SizedBox(
          width: 62,
          height: 62,
          child: Stack(
            alignment:
                Alignment.center,
            children: [
              Container(
                width: 59,
                height: 59,
                decoration:
                    const BoxDecoration(
                  shape:
                      BoxShape.circle,
                ),
                child:
                    DecoratedBox(
                  decoration:
                      BoxDecoration(
                    shape:
                        BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color:
                            const Color(
                          0xFF132A55,
                        ).withOpacity(
                          0.18,
                        ),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color:
                            const Color(
                          0xFF651B32,
                        ).withOpacity(
                          0.16,
                        ),
                        blurRadius: 20,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),

              Transform.rotate(
                angle: rotation,
                child: Container(
                  width: 58,
                  height: 58,
                  decoration:
                      const BoxDecoration(
                    shape:
                        BoxShape.circle,
                    gradient:
                        SweepGradient(
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
                width: 51,
                height: 51,
                decoration:
                    BoxDecoration(
                  shape:
                      BoxShape.circle,
                  color:
                      const Color(
                    0xFF070A12,
                  ),
                  border:
                      Border.all(
                    color:
                        const Color(
                      0xFF315277,
                    ),
                    width: 2.2,
                  ),
                ),
                child:
                    ClipOval(
                  child:
                      Image.asset(
                    'app_icon.png',
                    fit:
                        BoxFit.cover,
                    errorBuilder:
                        (_, __, ___) {
                      return const Icon(
                        Icons
                            .auto_awesome_rounded,
                        color:
                            Color(
                          0xFFFFD76A,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
