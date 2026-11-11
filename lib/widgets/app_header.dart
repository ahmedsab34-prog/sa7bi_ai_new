
import 'package:flutter/material.dart';

import '../audio_player_service.dart';
import '../services/profile_service.dart';

/// الهيدر الموحد لتطبيق صاحبي AI.
///
/// نسخة أصغر بارتفاع 48 نقطة، مع زر صوت نابض عند التشغيل.
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
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        height: 48,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Sa7biLogo(),
            const SizedBox(width: 5),
            const Expanded(
              child: _HeaderWelcome(),
            ),
            const SizedBox(width: 4),
            _HeaderAudioButton(
              onTap: onAudioTap,
            ),
            const SizedBox(width: 3),
            _HeaderProfileButton(
              onTap: onProfileTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderWelcome extends StatelessWidget {
  const _HeaderWelcome();

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(
        minHeight: 38,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color(0xFF1C2B45),
            Color(0xFF10131D),
            Color(0xFF24111E),
          ],
        ),
        border: Border.all(
          color: const Color(0x555A8DCB),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 7,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: const Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'صاحبي AI',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 1),
            Text(
              'أنا معاك',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Color(0xFF9FCBFF),
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderAudioButton extends StatefulWidget {
  final VoidCallback? onTap;

  const _HeaderAudioButton({
    required this.onTap,
  });

  @override
  State<_HeaderAudioButton> createState() =>
      _HeaderAudioButtonState();
}

class _HeaderAudioButtonState extends State<_HeaderAudioButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  bool _playing = false;

  @override
  void initState() {
    super.initState();

    _playing = AudioController.isPlayingNotifier.value;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
      lowerBound: 0,
      upperBound: 1,
    );

    AudioController.isPlayingNotifier.addListener(
      _onPlaybackChanged,
    );

    if (_playing) {
      _pulseController.repeat(reverse: true);
    }
  }

  void _onPlaybackChanged() {
    if (!mounted) return;

    final next = AudioController.isPlayingNotifier.value;
    if (next == _playing) return;

    setState(() {
      _playing = next;
    });

    if (next) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.value = 0;
    }
  }

  @override
  void dispose() {
    AudioController.isPlayingNotifier.removeListener(
      _onPlaybackChanged,
    );
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: _playing
          ? 'مركز الصوت، التشغيل نشط'
          : 'مركز الصوت',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final pulse = _playing
                  ? _pulseController.value
                  : 0.0;

              final scale = 1.0 + (pulse * 0.075);

              final activeColor = Color.lerp(
                const Color(0xFF319FEA),
                const Color(0xFF70E5C7),
                pulse,
              )!;

              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _playing
                          ? [
                              const Color(0xFF123B50),
                              const Color(0xFF122B3C),
                            ]
                          : [
                              const Color(0xFF172B49),
                              const Color(0xFF241528),
                            ],
                    ),
                    border: Border.all(
                      color: _playing
                          ? activeColor.withValues(alpha: 0.9)
                          : const Color(0x8877A8E8),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (_playing
                                ? activeColor
                                : const Color(0xFF477FC4))
                            .withValues(
                          alpha: _playing
                              ? 0.16 + (pulse * 0.22)
                              : 0.10,
                        ),
                        blurRadius: _playing
                            ? 5 + pulse * 8
                            : 5,
                        spreadRadius: _playing
                            ? pulse * 1.5
                            : 0,
                      ),
                    ],
                  ),
                  child: Icon(
                    _playing
                        ? Icons.graphic_eq_rounded
                        : Icons.headphones_rounded,
                    color: _playing
                        ? activeColor
                        : const Color(0xFF83C8FF),
                    size: 20,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HeaderProfileButton extends StatelessWidget {
  final VoidCallback? onTap;

  const _HeaderProfileButton({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final profile = ProfileService.instance;

    return AnimatedBuilder(
      animation: profile.changes,
      builder: (context, child) {
        return Semantics(
          button: true,
          label: 'الملف الشخصي',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(11),
              child: SizedBox(
                width: 43,
                height: 46,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ProfileAvatar(
                      profile: profile,
                    ),
                    const SizedBox(height: 1),
                    SizedBox(
                      width: 43,
                      child: Text(
                        profile.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 7.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final ProfileService profile;

  const _ProfileAvatar({
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    final photo = profile.photoBytes;
    final hasReel = profile.hasReel;

    return Container(
      width: 31,
      height: 31,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: hasReel
            ? const SweepGradient(
                colors: [
                  Color(0xFF67D9F2),
                  Color(0xFF8F2147),
                  Color(0xFF4B8DFF),
                  Color(0xFF67D9F2),
                ],
              )
            : const LinearGradient(
                colors: [
                  Color(0xFF67B7FF),
                  Color(0xFF8F2147),
                ],
              ),
        boxShadow: [
          BoxShadow(
            color: (hasReel
                    ? const Color(0xFF8F2147)
                    : const Color(0xFF67B7FF))
                .withValues(alpha: 0.17),
            blurRadius: 6,
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
                  gaplessPlayback: true,
                  errorBuilder: (context, error, stackTrace) {
                    return const _DefaultProfileIcon();
                  },
                )
              : const _DefaultProfileIcon(),
        ),
      ),
    );
  }
}

class _DefaultProfileIcon extends StatelessWidget {
  const _DefaultProfileIcon();

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.person_rounded,
      color: Color(0xFF83C8FF),
      size: 18,
    );
  }
}

/// شعار التطبيق المصغر.
class Sa7biLogo extends StatelessWidget {
  const Sa7biLogo({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [
                  Color(0xFF67B7FF),
                  Color(0xFF8F2147),
                  Color(0xFF254F82),
                  Color(0xFF67B7FF),
                ],
              ),
            ),
          ),
          Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF070A12),
              border: Border.all(
                color: const Color(0xFF315277),
                width: 1.3,
              ),
            ),
            child: ClipOval(
              child: Image.asset(
                'app_icon.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.auto_awesome_rounded,
                    color: Color(0xFF83C8FF),
                    size: 19,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
