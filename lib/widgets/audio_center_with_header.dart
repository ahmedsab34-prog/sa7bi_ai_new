import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../audio_center_screen.dart';
import '../audio_downloads_screen.dart';
import '../audio_player_service.dart';
import '../services/audio_focus_coordinator.dart';
import 'app_header.dart';

class AudioCenterWithHeader extends StatelessWidget {
  final VoidCallback onProfileTap;

  const AudioCenterWithHeader({
    super.key,
    required this.onProfileTap,
  });

  void _openProfile(BuildContext context) {
    Navigator.of(context).pop();
    onProfileTap();
  }

  void _showMessage(
    BuildContext context,
    String message,
  ) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            textDirection: TextDirection.rtl,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _openDownloads(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const AudioDownloadsScreen(),
      ),
    );
  }

  void _toggleAudio(BuildContext context) {
    final handler = AudioController.handler;

    if (handler == null || handler.mediaItem.value == null) {
      _showMessage(
        context,
        'افتح قسمًا واختر مقطعًا صوتيًا أولًا.',
      );
      return;
    }

    if (AudioController.isPlayingNotifier.value) {
      unawaited(_pauseAudio(context, handler));
    } else {
      unawaited(_resumeAudio(context, handler));
    }
  }

  Future<void> _resumeAudio(
    BuildContext context,
    Sa7biAudioHandler handler,
  ) async {
    try {
      await AudioFocusCoordinator.stopAllSpeech();

      if (!context.mounted) return;

      await handler.play();
    } catch (_) {
      if (!context.mounted) return;

      _showMessage(
        context,
        'تعذر استئناف الصوت حاليًا.',
      );
    }
  }

  Future<void> _pauseAudio(
    BuildContext context,
    Sa7biAudioHandler handler,
  ) async {
    try {
      await handler.pause();
    } catch (_) {
      if (!context.mounted) return;

      _showMessage(
        context,
        'تعذر إيقاف الصوت مؤقتًا.',
      );
    }
  }

  Future<void> _pickLocalAudio(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
      );

      if (!context.mounted ||
          result == null ||
          result.files.isEmpty) {
        return;
      }

      final file = result.files.single;
      final path = file.path;

      if (path == null || path.trim().isEmpty) {
        _showMessage(
          context,
          'تعذر الوصول إلى الملف الصوتي.',
        );
        return;
      }

      await AudioFocusCoordinator.stopAllSpeech();

      if (!context.mounted) return;

      await AudioController.playLocalFile(
        path: path,
        title: file.name,
        artist: 'ملف صوتي من الهاتف',
      );

      if (!context.mounted) return;

      _showMessage(
        context,
        'بدأ تشغيل ${file.name}',
      );
    } catch (_) {
      if (!context.mounted) return;

      _showMessage(
        context,
        'تعذر فتح الملف الصوتي أو تشغيله.',
      );
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
              onProfileTap: () => _openProfile(context),
              onAudioTap: () => _toggleAudio(context),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                14,
                2,
                8,
                2,
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'مركز الصوت',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'تنزيلاتي الصوتية',
                    onPressed: () => _openDownloads(context),
                    icon: const Icon(
                      Icons.download_for_offline_rounded,
                      color: Color(0xFF63E6FF),
                    ),
                  ),
                  IconButton(
                    tooltip: 'تشغيل ملف من الهاتف',
                    onPressed: () => _pickLocalAudio(context),
                    icon: const Icon(
                      Icons.folder_open_rounded,
                      color: Color(0xFF83C8FF),
                    ),
                  ),
                ],
              ),
            ),
            const Expanded(
              child: AudioCenterScreen(
                showAppBar: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
