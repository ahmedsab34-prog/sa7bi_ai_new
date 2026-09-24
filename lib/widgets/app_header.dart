import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio_player_service.dart';
import '../services/profile_service.dart';

/// الهيدر الرئيسي لتطبيق صاحبي AI.
///
/// الترتيب ثابت:
/// الشعار → الترحيب → الصوت → البروفايل
///
/// مهم:
/// - دائرة الصوت الخارجية ثابتة تمامًا.
/// - لا تكبر ولا تصغر ولا تهتز.
/// - الحركة داخل الدائرة فقط.
/// - عند تشغيل الصوت تظهر حركة داخلية تشبه المطر/الموجات الصوتية.
/// - عند توقف الصوت يظل شكل هادئ وثابت.
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
        const Sa7biLogo(),

        const SizedBox(width: 9),

        const Expanded(
          child: _HeaderWelcome(),
        ),

        const SizedBox(width: 7),

        _HeaderAudioButton(
          onTap: onAudioTap,
        ),

        const SizedBox(width: 7),

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

class _HeaderWelcomeState extends State<_HeaderWelcome>
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
        if (!mounted) {
          return;
        }

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
            borderRadius:
                BorderRadius.circular(18),
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
                  textAlign:
                      TextAlign.right,
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

class _HeaderAudioButton extends StatelessWidget {
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
// AUDIO BUTTON
//
// الدائرة الخارجية ثابتة تمامًا.
// الحركة داخلها فقط.
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
      duration:
          const Duration(milliseconds: 1250),
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
        width: 52,
        height: 52,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ==================================================
            // الدائرة الخارجية
            //
            // ثابتة 100%.
            // لا Rotation.
            // لا Scale.
            // لا Pulse.
            // ==================================================

            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    const Color(0xFF10131C),
                border: Border.all(
                  color:
                      const Color(0xFF63E6FF),
                  width: 1.8,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1F63E6FF),
                    blurRadius: 12,
                    spreadRadius: 0,
                  ),
                ],
              ),
            ),

            // ==================================================
            // RAIN AUDIO VISUALIZER
            //
            // الحركة داخل الدائرة فقط.
            // ==================================================

            SizedBox(
              width: 36,
              height: 32,
              child: AnimatedBuilder(
                animation: controller,
                builder: (_, __) {
                  return CustomPaint(
                    painter:
                        _AudioRainPainter(
                      progress:
                          widget.isPlaying
                              ? controller.value
                              : 0,
                      isPlaying:
                          widget.isPlaying,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// AUDIO RAIN PAINTER
//
// شكل داخلي يشبه المطر/الموجة الصوتية.
// ============================================================

class _AudioRainPainter
    extends CustomPainter {
  final double progress;
  final bool isPlaying;

  const _AudioRainPainter({
    required this.progress,
    required this.isPlaying,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const int columnCount = 9;

    const List<double> phaseOffsets = [
      0.0,
      0.72,
      1.45,
      2.15,
      2.85,
      3.55,
      4.25,
      4.95,
      5.65,
    ];

    const List<double> heightFactors = [
      0.52,
      0.82,
      0.66,
      1.0,
      0.72,
      0.92,
      0.58,
      0.78,
      0.48,
    ];

    for (int i = 0;
        i < columnCount;
        i++) {
      final x =
          2.5 +
          i *
              ((size.width - 5.0) /
                  (columnCount - 1));

      final phase =
          progress * math.pi * 2 +
              phaseOffsets[i];

      double length;

      if (isPlaying) {
        final wave =
            (math.sin(phase) + 1) / 2;

        length =
            7.0 +
            wave *
                14.0 *
                heightFactors[i];
      } else {
        length =
            5.0 +
            heightFactors[i] * 2.0;
      }

      final top =
          centerY - length / 2;

      final bottom =
          centerY + length / 2;

      final opacity = isPlaying
          ? 0.48 +
              ((math.sin(phase) + 1) / 2) *
                  0.52
          : 0.48;

      linePaint
        ..color = const Color(0xFF63E6FF)
            .withOpacity(opacity)
        ..strokeWidth =
            i.isEven ? 2.1 : 1.7;

      canvas.drawLine(
        Offset(x, top),
        Offset(x, bottom),
        linePaint,
      );
    }

    // خط ضوء أفقي خفيف في المنتصف.
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.2
      ..color = const Color(0xFFFFD76A)
          .withOpacity(
        isPlaying ? 0.45 : 0.25,
      );

    final centerWave =
        isPlaying
            ? math.sin(
                  progress * math.pi * 2,
                ) *
                2.0
            : 0.0;

    canvas.drawLine(
      Offset(
        centerX - 10,
        centerY + centerWave,
      ),
      Offset(
        centerX + 10,
        centerY - centerWave,
      ),
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(
    covariant _AudioRainPainter
        oldDelegate,
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
                    textAlign:
                        TextAlign.center,
                    textDirection:
                        TextDirection.rtl,
                    style:
                        const TextStyle(
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
    final photo =
        profile.photoBytes;

    final hasReel =
        profile.hasReel;

    final avatar = Container(
      width: 43,
      height: 43,
      padding:
          const EdgeInsets.all(2.2),
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
          color:
              Color(0xFF10131C),
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
      clipBehavior:
          Clip.none,
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
              shape:
                  BoxShape.circle,
              color:
                  const Color(
                0xFF10131C,
              ),
              border:
                  Border.all(
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

    controller =
        AnimationController(
      vsync: this,
      duration:
          const Duration(seconds: 9),
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
                math.pi *
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
                        Color(
                          0xFF8A1834,
                        ),
                        Color(
                          0xFF183D72,
                        ),
                        Color(
                          0xFF254F82,
                        ),
                        Color(
                          0xFF5C1630,
                        ),
                        Color(
                          0xFF8A1834,
                        ),
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
                child: ClipOval(
                  child: Image.asset(
                    'app_icon.png',
                    fit: BoxFit.cover,
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
