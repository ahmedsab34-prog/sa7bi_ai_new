import 'package:flutter/material.dart';

import '../audio_player_service.dart';
import '../services/profile_service.dart';

/// الهيدر الموحد لتطبيق صاحبي AI.
///
/// نسخة ثابتة ومدمجة دون رسائل الترحيب المتحركة القديمة.
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
        height: 54,
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
            const SizedBox(width: 4),
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
        minHeight: 42,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color(0xFF1B2130),
            Color(0xFF10131C),
          ],
        ),
        border: Border.all(
          color: const Color(0x33FFD76A),
        ),
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
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'مساعدك الذكي',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white54,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderAudioButton extends StatelessWidget {
  final VoidCallback? onTap;

  const _HeaderAudioButton({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AudioController.isPlayingNotifier,
      builder: (context, playing, child) {
        return Semantics(
          button: true,
          label: 'مركز الصوت',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 39,
                height: 39,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: playing
                      ? const Color(0x223DDCBA)
                      : const Color(0x22FFD76A),
                  border: Border.all(
                    color: playing
                        ? const Color(0x8870E5C7)
                        : const Color(0x66FFD76A),
                  ),
                ),
                child: Icon(
                  playing
                      ? Icons.graphic_eq_rounded
                      : Icons.headphones_rounded,
                  color: playing
                      ? const Color(0xFF70E5C7)
                      : const Color(0xFFFFD76A),
                  size: 21,
                ),
              ),
            ),
          ),
        );
      },
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
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 46,
                height: 52,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ProfileAvatar(
                      profile: profile,
                    ),
                    const SizedBox(height: 2),
                    SizedBox(
                      width: 46,
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
      width: 36,
      height: 36,
      padding: const EdgeInsets.all(2),
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
            color: (hasReel
                    ? const Color(0xFFB45CFF)
                    : const Color(0xFFFFD76A))
                .withValues(alpha: 0.15),
            blurRadius: 7,
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
      color: Color(0xFFFFD76A),
      size: 20,
    );
  }
}

/// شعار التطبيق.
class Sa7biLogo extends StatelessWidget {
  const Sa7biLogo({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 45,
      height: 45,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 45,
            height: 45,
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
          Container(
            width: 39,
            height: 39,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF070A12),
              border: Border.all(
                color: const Color(0xFF315277),
                width: 1.5,
              ),
            ),
            child: ClipOval(
              child: Image.asset(
                'app_icon.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.auto_awesome_rounded,
                    color: Color(0xFFFFD76A),
                    size: 21,
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
