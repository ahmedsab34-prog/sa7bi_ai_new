import 'dart:async';

import 'package:flutter/material.dart';

import '../audio_player_service.dart';
import '../services/profile_service.dart';

/// الهيدر الرئيسي لتطبيق صاحبي AI.
///
/// الترتيب ثابت ولا يتم تغييره:
/// الشعار → الترحيب → الصوت → البروفايل
///
/// التعديلات المضافة:
/// - زر الصوت ينبض أثناء تشغيل الصوت.
/// - صورة المستخدم المحفوظة تظهر في البروفايل.
/// - حلقة Reel تظهر إذا كان لدى المستخدم Reel.
/// - اسم المستخدم يظهر أسفل الصورة.
/// - بيانات البروفايل تأتي من ProfileService.
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
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AnimatedSwitcher(
                duration: const Duration(
                  milliseconds: 350,
                ),
                child: Text(
                  messages[index],
                  key: ValueKey(index),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'صاحبي AI معاك كل يوم',
                textDirection: TextDirection.rtl,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 900,
      ),
      lowerBound: 0.0,
      upperBound: 1.0,
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
      controller.repeat(reverse: true);
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
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final pulse = widget.isPlaying
            ? controller.value
            : 0.0;

        final scale =
            1.0 + (pulse * 0.08);

        final glow =
            widget.isPlaying
                ? 0.22 + pulse * 0.25
                : 0.15;

        return GestureDetector(
          onTap: widget.onTap,
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: 43,
              height: 43,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF10131C),
                border: Border.all(
                  color: const Color(0xFF63E6FF)
                      .withOpacity(
                    widget.isPlaying
                        ? 0.95
                        : 0.75,
                  ),
                  width: widget.isPlaying
                      ? 1.7
                      : 1.3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(
                      0xFF63E6FF,
                    ).withOpacity(glow),
                    blurRadius:
                        widget.isPlaying
                            ? 20
                            : 13,
                    spreadRadius:
                        widget.isPlaying
                            ? 1.5
                            : 0,
                  ),
                ],
              ),
              child: Icon(
                widget.isPlaying
                    ? Icons.graphic_eq_rounded
                    : Icons.graphic_eq_rounded,
                color: const Color(
                  0xFF63E6FF,
                ),
                size: widget.isPlaying
                    ? 24
                    : 22,
              ),
            ),
          ),
        );
      },
    );
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

class _ProfileAvatar extends StatelessWidget {
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
            blurRadius: hasReel ? 15 : 11,
            spreadRadius:
                hasReel ? 1 : 0,
          ),
        ],
      ),
      child: Container(
        decoration: const BoxDecoration(
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
                  color: Color(0xFFFFD76A),
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
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(
                0xFF10131C,
              ),
              border: Border.all(
                color: const Color(
                  0xFFFFD76A,
                ),
                width: 1.1,
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

// ============================================================
// SA7BI LOGO
// ============================================================

class Sa7biLogo extends StatefulWidget {
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
            alignment: Alignment.center,
            children: [
              Container(
                width: 59,
                height: 59,
                decoration:
                    const BoxDecoration(
                  shape: BoxShape.circle,
                ),
                child: DecoratedBox(
                  decoration:
                      BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color:
                            const Color(
                          0xFF132A55,
                        ).withOpacity(0.18),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color:
                            const Color(
                          0xFF651B32,
                        ).withOpacity(0.16),
                        blurRadius: 20,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),

              // الحلقة الخارجية المتحركة.
              //
              // محتوى app_icon.png لا يتم تغييره.
              Transform.rotate(
                angle: rotation,
                child: Container(
                  width: 58,
                  height: 58,
                  decoration:
                      const BoxDecoration(
                    shape: BoxShape.circle,
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
                  shape: BoxShape.circle,
                  color:
                      const Color(
                    0xFF070A12,
                  ),
                  border: Border.all(
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
