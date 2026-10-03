import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio_player_service.dart';
import '../services/profile_service.dart';

/// الهيدر الرئيسي لتطبيق صاحبي AI.
///
/// الترتيب:
/// الشعار → الترحيب → الصوت → البروفايل
///
/// مهم:
/// - اللوجو والهيدر الأساسي محفوظان كما هما.
/// - التعديل الأساسي هنا على مؤشر الصوت فقط.
/// - زر الصوت مستطيل بزوايا دائرية.
/// - الألوان تتحرك أثناء التشغيل.
/// - توجد نقاط/خطوط نازلة مثل المطر داخل الزر.
/// - الحركة تتوقف عند توقف الصوت.
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
  late final AnimationController _controller;
  Timer? _timer;

  static const List<String> _messages = [
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
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _timer = Timer.periodic(
      const Duration(seconds: 4),
      (_) {
        if (!mounted) {
          return;
        }

        setState(() {
          _index = (_index + 1) % _messages.length;
        });
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final glow =
            0.06 + (_controller.value * 0.08);

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
                    .withValues(alpha: glow),
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
                  _messages[_index],
                  key: ValueKey<int>(_index),
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
        child,
      ) {
        return _PulsingAudioButton(
          isPlaying: isPlaying,
          onTap: onTap,
        );
      },
    );
  }
}

class _PulsingAudioButton extends StatefulWidget {
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
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration:
          const Duration(milliseconds: 1450),
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
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 56,
        height: 46,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (
            context,
            child,
          ) {
            return _AudioIndicator(
              progress:
                  widget.isPlaying
                      ? _controller.value
                      : 0,
              isPlaying:
                  widget.isPlaying,
            );
          },
        ),
      ),
    );
  }
}

// ============================================================
// AUDIO INDICATOR
// ============================================================

class _AudioIndicator extends StatelessWidget {
  final double progress;
  final bool isPlaying;

  const _AudioIndicator({
    required this.progress,
    required this.isPlaying,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(13),
        gradient: SweepGradient(
          transform:
              GradientRotation(
            progress * math.pi * 2,
          ),
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
                .withValues(
              alpha: isPlaying
                  ? 0.30
                  : 0.12,
            ),
            blurRadius:
                isPlaying ? 13 : 8,
          ),
        ],
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(1.6),
        child: ClipRRect(
          borderRadius:
              BorderRadius.circular(11),
          child: Container(
            decoration:
                const BoxDecoration(
              gradient: LinearGradient(
                begin:
                    Alignment.topLeft,
                end:
                    Alignment.bottomRight,
                colors: [
                  Color(0xFF10131C),
                  Color(0xFF171426),
                  Color(0xFF0B1018),
                ],
              ),
            ),
            child: ClipRRect(
              borderRadius:
                  BorderRadius.circular(10),
              child: CustomPaint(
                painter:
                    _AudioRainPainter(
                  progress:
                      progress,
                  isPlaying:
                      isPlaying,
                ),
                child:
                    const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// AUDIO RAIN PAINTER
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
    if (size.width <= 0 ||
        size.height <= 0) {
      return;
    }

    final paint = Paint()
      ..strokeCap =
          StrokeCap.round
      ..style =
          PaintingStyle.stroke;

    const columns = 11;

    const heights = <double>[
      0.34,
      0.55,
      0.43,
      0.78,
      0.62,
      0.95,
      0.52,
      0.82,
      0.44,
      0.66,
      0.36,
    ];

    const phases = <double>[
      0.00,
      0.37,
      0.74,
      1.11,
      1.48,
      1.85,
      2.22,
      2.59,
      2.96,
      3.33,
      3.70,
    ];

    final availableWidth =
        math.max(1.0, size.width - 8);

    for (var i = 0;
        i < columns;
        i++) {
      final x =
          4 +
          (availableWidth *
              i /
              (columns - 1));

      final phase =
          (progress * math.pi * 2) +
          phases[i];

      final wave = isPlaying
          ? (math.sin(phase) + 1) / 2
          : 0.15;

      final baseHeight =
          size.height *
          (0.16 +
              heights[i] * 0.38);

      final dynamicHeight =
          isPlaying
              ? baseHeight *
                  (0.60 +
                      wave * 0.90)
              : baseHeight * 0.65;

      final fall =
          isPlaying
              ? ((progress +
                          phases[i] /
                              (math.pi * 2)) %
                      1.0)
              : 0.50;

      final top =
          ((fall *
                  (size.height +
                      dynamicHeight)) -
              dynamicHeight);

      final bottom =
          top + dynamicHeight;

      final clippedTop =
          top.clamp(
            1.0,
            size.height - 1,
          );

      final clippedBottom =
          bottom.clamp(
            1.0,
            size.height - 1,
          );

      final alpha =
          isPlaying
              ? 0.30 +
                  (wave * 0.70)
              : 0.38;

      final colorIndex =
          (i +
                  (progress * 4)
                      .floor()) %
              4;

      const colors = [
        Color(0xFFFFD76A),
        Color(0xFF63E6FF),
        Color(0xFFFF4D8D),
        Color(0xFFB45CFF),
      ];

      paint
        ..color =
            colors[colorIndex]
                .withValues(
          alpha: alpha,
        )
        ..strokeWidth =
            i.isEven ? 1.9 : 1.5;

      canvas.drawLine(
        Offset(x, clippedTop),
        Offset(x, clippedBottom),
        paint,
      );
    }

    final centerY =
        size.height / 2;

    final wavePaint = Paint()
      ..style =
          PaintingStyle.stroke
      ..strokeCap =
          StrokeCap.round
      ..strokeWidth = 1.1
      ..color =
          const Color(0xFFFFD76A)
              .withValues(
        alpha:
            isPlaying
                ? 0.70
                : 0.28,
      );

    final path = Path();

    for (var i = 0; i <= 24; i++) {
      final x =
          3 +
          ((size.width - 6) *
              i /
              24);

      final y =
          centerY +
          math.sin(
                (i / 24) *
                    math.pi *
                    2 +
                    progress *
                        math.pi *
                        2,
              ) *
              (isPlaying
                  ? 2.0
                  : 0.7);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(
      path,
      wavePaint,
    );
  }

  @override
  bool shouldRepaint(
    covariant _AudioRainPainter oldDelegate,
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
      builder: (
        context,
        child,
      ) {
        return GestureDetector(
          onTap: onTap,
          behavior:
              HitTestBehavior.opaque,
          child: SizedBox(
            width: 56,
            height: 67,
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment
                      .center,
              children: [
                _ProfileAvatar(
                  profile: profile,
                ),
                const SizedBox(
                  height: 2,
                ),
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
                  ).withValues(
                    alpha: 0.35,
                  )
                : const Color(
                    0xFFFFD76A,
                  ).withValues(
                    alpha: 0.18,
                  ),
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
          child:
              photo != null &&
                      photo.isNotEmpty
                  ? Image.memory(
                      photo,
                      fit:
                          BoxFit.cover,
                      errorBuilder:
                          (
                        context,
                        error,
                        stackTrace,
                      ) {
                        return const Icon(
                          Icons
                              .person_rounded,
                          color:
                              Color(
                            0xFFFFD76A,
                          ),
                          size: 22,
                        );
                      },
                    )
                  : const Icon(
                      Icons
                          .person_rounded,
                      color:
                          Color(
                        0xFFFFD76A,
                      ),
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
            child:
                const Icon(
              Icons
                  .play_arrow_rounded,
              color:
                  Color(
                0xFFFF4D8D,
              ),
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
  late final AnimationController
      _controller;

  @override
  void initState() {
    super.initState();

    _controller =
        AnimationController(
      vsync: this,
      duration:
          const Duration(
        seconds: 9,
      ),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (
        context,
        child,
      ) {
        final rotation =
            _controller.value *
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
                    BoxDecoration(
                  shape:
                      BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color:
                          const Color(
                        0xFF132A55,
                      ).withValues(
                        alpha: 0.18,
                      ),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color:
                          const Color(
                        0xFF651B32,
                      ).withValues(
                        alpha: 0.16,
                      ),
                      blurRadius: 20,
                      spreadRadius: 1,
                    ),
                  ],
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
                    fit:
                        BoxFit.cover,
                    errorBuilder:
                        (
                      context,
                      error,
                      stackTrace,
                    ) {
                      return const Icon(
                        Icons
                            .auto_awesome_rounded,
                        color:
                            Color(
                          0xFFFFD76A,
                        ),
                        size: 22,
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
