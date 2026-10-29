import 'dart:async';

import 'package:flutter/material.dart';

import '../audio_center_screen.dart';
import '../audio_player_service.dart';
import 'app_header.dart';

class AudioCenterWithHeader extends StatelessWidget {
  final VoidCallback onProfileTap;

  const AudioCenterWithHeader({
    super.key,
    required this.onProfileTap,
  });

  void _toggleAudio(BuildContext context) {
    final handler = AudioController.handler;

    if (handler == null || handler.mediaItem.value == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'افتح قسمًا واختر مقطعًا صوتيًا أولًا.',
              textDirection: TextDirection.rtl,
            ),
          ),
        );
      return;
    }

    if (AudioController.isPlayingNotifier.value) {
      unawaited(handler.pause());
    } else {
      unawaited(handler.play());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07111F),
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              onProfileTap: onProfileTap,
              onAudioTap: () => _toggleAudio(context),
            ),
            const Expanded(
              child: AudioCenterScreen(),
            ),
          ],
        ),
      ),
    );
  }
}
