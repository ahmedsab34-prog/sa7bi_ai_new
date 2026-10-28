
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio_player_service.dart';
import '../services/profile_service.dart';

/// الهيدر الموحد لتطبيق صاحبي AI.
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Sa7biLogo(),
          const SizedBox(width: 6),
          const Expanded(child: _HeaderWelcome()),
          const SizedBox(width: 5),
          _HeaderAudioButton(onTap: onAudioTap),
          const SizedBox(width: 5),
          _HeaderProfileButton(onTap: onProfileTap),
        ],
      ),
    );
  }
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
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);

    _timer = Timer.periodic(
      const Duration(seconds: 5),
      (_) {
        if (!mounted) return;
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
        final glow = 0.04 + _controller.value * 0.05;

        return Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
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
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD76A)
                    .withValues(alpha: glow),
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
                    key: ValueKey<int>(_index),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'صاحبي AI معاك كل يوم',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 8,
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

class _HeaderAudioButton extends StatelessWidget {
  final VoidCallback? onTap;

  const _HeaderAudioButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AudioController.isPlayingNotifier,
      builder: (context, isPlaying, child) {
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
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _PulsingAudioButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPlaying != widget.isPlaying) {
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
    return Semantics(
      button: true,
      label: 'مركز الصوت',
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 43,
          height: 43,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return _AudioIndicator(
                progress: widget.isPlaying
                    ? _controller.value
                    : 0,
                isPlaying: widget.isPlaying,
              );
            },
          ),
        ),
      ),
    );
  }
}
