import 'package:flutter/material.dart';

import '../audio_player_service.dart';
import '../services/profile_service.dart';
import '../theme/sa7bi_theme.dart';
import 'sa7bi_glass_surface.dart';

/// الهيدر الموحد لتطبيق صاحبي AI.
///
/// يحافظ على واجهة الاستدعاء القديمة لتجنب كسر الشاشات الحالية.
class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    this.onProfileTap,
    this.onAudioTap,
    this.welcomeMessage = 'أنا معاك',
  });

  final VoidCallback? onProfileTap;
  final VoidCallback? onAudioTap;
  final String welcomeMessage;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        height: 48,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Sa7biLogo(),
              const SizedBox(width: 7),
              Expanded(
                child: _HeaderWelcome(
                  message: welcomeMessage,
                ),
              ),
              const SizedBox(width: 6),
              _HeaderAudioButton(
                onTap: onAudioTap,
              ),
              const SizedBox(width: 5),
              _HeaderProfileButton(
                onTap: onProfileTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderWelcome extends StatelessWidget {
  const _HeaderWelcome({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Sa7biGlassSurface(
      radius: 15,
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      borderColor: Sa7biTheme.borderGold.withValues(alpha: 0.65),
      gradient: const LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: <Color>[
          Color(0xFF25294B),
          Color(0xFF171B35),
          Color(0xFF11182C),
        ],
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Row(
          children: [
            Container(
              width: 3,
              height: 25,
              decoration: BoxDecoration(
                color: Sa7biTheme.gold,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'صاحبي AI',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Sa7biTheme.textPrimary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    message,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Sa7biTheme.blueBright,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 5),
            const Icon(
              Icons.auto_awesome_rounded,
              size: 15,
              color: Sa7biTheme.goldBright,
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderAudioButton extends StatefulWidget {
  const _HeaderAudioButton({
    required this.onTap,
  });

  final VoidCallback? onTap;

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
      duration: const Duration(milliseconds: 900),
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
      _pulseController
        ..stop()
        ..value = 0;
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
      button: widget.onTap != null,
      label: _playing
          ? 'مركز الصوت، التشغيل نشط'
          : 'مركز الصوت',
      child: SizedBox(
        width: 38,
        height: 38,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(13),
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final pulse = _playing
                    ? _pulseController.value
                    : 0.0;

                final activeColor = Color.lerp(
                  Sa7biTheme.cyan,
                  Sa7biTheme.goldBright,
                  pulse,
                )!;

                return Transform.scale(
                  scale: 1 + (pulse * 0.045),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(13),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: _playing
                            ? const <Color>[
                                Color(0xFF17404A),
                                Color(0xFF182E43),
                              ]
                            : const <Color>[
                                Color(0xFF25294A),
                                Color(0xFF171B35),
                              ],
                      ),
                      border: Border.all(
                        color: _playing
                            ? activeColor.withValues(alpha: 0.85)
                            : Sa7biTheme.borderGold,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (_playing
                                  ? activeColor
                                  : Sa7biTheme.violet)
                              .withValues(
                            alpha: _playing
                                ? 0.12 + (pulse * 0.17)
                                : 0.10,
                          ),
                          blurRadius: _playing
                              ? 7 + (pulse * 5)
                              : 6,
                        ),
                      ],
                    ),
                    child: Icon(
                      _playing
                          ? Icons.graphic_eq_rounded
                          : Icons.headphones_rounded,
                      color: _playing
                          ? activeColor
                          : Sa7biTheme.goldBright,
                      size: 20,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderProfileButton extends StatelessWidget {
  const _HeaderProfileButton({
    required this.onTap,
  });

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final profile = ProfileService.instance;

    return AnimatedBuilder(
      animation: profile.changes,
      builder: (context, child) {
        return Semantics(
          button: onTap != null,
          label: 'الملف الشخصي',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(13),
              child: SizedBox(
                width: 45,
                height: 46,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ProfileAvatar(
                      profile: profile,
                    ),
                    const SizedBox(height: 1),
                    SizedBox(
                      width: 45,
                      child: Text(
                        profile.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(
                          color: Sa7biTheme.textPrimary,
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
  const _ProfileAvatar({
    required this.profile,
  });

  final ProfileService profile;

  @override
  Widget build(BuildContext context) {
    final photo = profile.photoBytes;
    final hasReel = profile.hasReel;

    return Container(
      width: 32,
      height: 32,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: hasReel
            ? const SweepGradient(
                colors: <Color>[
                  Sa7biTheme.cyan,
                  Sa7biTheme.violet,
                  Sa7biTheme.goldBright,
                  Sa7biTheme.cyan,
                ],
              )
            : const LinearGradient(
                colors: <Color>[
                  Sa7biTheme.goldBright,
                  Sa7biTheme.violet,
                  Sa7biTheme.blue,
                ],
              ),
        boxShadow: [
          BoxShadow(
            color: (hasReel
                    ? Sa7biTheme.violet
                    : Sa7biTheme.gold)
                .withValues(alpha: 0.17),
            blurRadius: 7,
          ),
        ],
      ),
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Sa7biTheme.navyDeep,
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
      color: Sa7biTheme.goldBright,
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
                colors: <Color>[
                  Sa7biTheme.blueBright,
                  Sa7biTheme.violet,
                  Sa7biTheme.goldBright,
                  Sa7biTheme.blueBright,
                ],
              ),
            ),
          ),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Sa7biTheme.navyDeep,
              border: Border.all(
                color: Sa7biTheme.gold.withValues(alpha: 0.75),
                width: 1.1,
              ),
            ),
            child: ClipOval(
              child: Image.asset(
                'app_icon.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.auto_awesome_rounded,
                    color: Sa7biTheme.goldBright,
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
