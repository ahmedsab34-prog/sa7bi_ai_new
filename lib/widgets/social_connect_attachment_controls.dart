
import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/social_community_service.dart';
import '../services/social_messaging_attachments.dart';
import '../services/social_messaging_service.dart';
import '../services/social_voice_recording_service.dart';

/// أدوات إرسال الملفات والرسائل الصوتية في صاحبي Connect.
class SocialConnectAttachmentControls extends StatefulWidget {
  const SocialConnectAttachmentControls({
    super.key,
    required this.scopeType,
    required this.scopeId,
    required this.onMessageSent,
  }) : assert(
          scopeType == 'conversation' || scopeType == 'group',
        );

  final String scopeType;
  final String scopeId;
  final VoidCallback onMessageSent;

  static const Map<String, String> _mimeTypes = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
    'gif': 'image/gif',
    'm4a': 'audio/mp4',
    'aac': 'audio/aac',
    'mp3': 'audio/mpeg',
    'ogg': 'audio/ogg',
    'weba': 'audio/webm',
    'pdf': 'application/pdf',
    'txt': 'text/plain',
  };

  static String? contentTypeForFileName(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) {
      return null;
    }

    return _mimeTypes[
      fileName.substring(dot + 1).toLowerCase()
    ];
  }

  @override
  State<SocialConnectAttachmentControls> createState() =>
      _SocialConnectAttachmentControlsState();
}

class _SocialConnectAttachmentControlsState
    extends State<SocialConnectAttachmentControls> {
  final SocialVoiceRecordingService _voice =
      SocialVoiceRecordingService.instance;

  bool _busy = false;
  bool _recording = false;

  @override
  void dispose() {
    if (_recording) {
      unawaited(_voice.cancel());
    }
    super.dispose();
  }

  Future<void> _pickFile() async {
    if (_busy || _recording) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions:
            SocialConnectAttachmentControls._mimeTypes.keys.toList(),
        allowMultiple: false,
        withData: false,
      );

      if (!mounted || result == null || result.files.isEmpty) {
        return;
      }

      final selected = result.files.single;
      final path = selected.path;

      final mime =
          SocialConnectAttachmentControls.contentTypeForFileName(
        selected.name,
      );

      if (path == null || path.trim().isEmpty) {
        _show('تعذر الوصول إلى الملف المختار.');
        return;
      }

      if (mime == null) {
        _show('نوع الملف غير مدعوم.');
        return;
      }

      await _sendFile(File(path), mime);
    } catch (error) {
      if (mounted) {
        _show(_friendly(error, 'تعذر اختيار الملف.'));
      }
    }
  }

  Future<void> _toggleRecording() async {
    if (_busy) return;

    if (!_recording) {
      try {
        await _voice.start();

        if (!mounted) {
          await _voice.cancel();
          return;
        }

        setState(() => _recording = true);

        _show(
          'بدأ التسجيل. اضغط الميكروفون مرة أخرى لإيقافه وإرساله.',
        );
      } catch (error) {
        if (mounted) {
          _show(
            _friendly(error, 'تعذر بدء التسجيل الصوتي.'),
          );
        }
      }

      return;
    }

    setState(() {
      _recording = false;
      _busy = true;
    });

    File? recordedFile;

    try {
      recordedFile = await _voice.stop();

      await _sendFile(
        recordedFile,
        'audio/mp4',
        manageBusy: false,
      );
    } catch (error) {
      if (mounted) {
        _show(
          _friendly(error, 'تعذر إنهاء التسجيل الصوتي.'),
        );
      }
    } finally {
      if (recordedFile != null) {
        try {
          if (await recordedFile.exists()) {
            await recordedFile.delete();
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _sendFile(
    File file,
    String mime, {
    bool manageBusy = true,
  }) async {
    if (manageBusy) {
      if (_busy) return;
      setState(() => _busy = true);
    }

    try {
      if (!await file.exists()) {
        throw const FileSystemException(
          'Selected file does not exist.',
        );
      }

      if (widget.scopeType == 'conversation') {
        await SocialMessagingService.instance
            .sendPrivateAttachment(
          conversationId: widget.scopeId,
          file: file,
          contentType: mime,
        );
      } else {
        await SocialCommunityService.instance
            .sendGroupAttachment(
          groupId: widget.scopeId,
          file: file,
          contentType: mime,
        );
      }

      if (!mounted) return;

      widget.onMessageSent();

      _show('تم إرسال المرفق بنجاح.');
    } catch (error) {
      if (mounted) {
        _show(_friendly(error, 'تعذر إرسال المرفق.'));
      }
    } finally {
      if (manageBusy && mounted) {
        setState(() => _busy = false);
      }
    }
  }

  String _friendly(Object error, String fallback) {
    if (error is SocialVoiceRecordingException) {
      return error.message;
    }

    final dynamic candidate = error;

    try {
      final value = candidate.message;

      if (value is String && value.trim().isNotEmpty) {
        return value;
      }
    } catch (_) {}

    return fallback;
  }

  void _show(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textDirection: TextDirection.rtl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'إرفاق صورة أو ملف',
          onPressed:
              _busy || _recording ? null : _pickFile,
          icon: _busy
              ? const SizedBox(
                  width: 19,
                  height: 19,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : const Icon(
                  Icons.attach_file_rounded,
                  color: Color(0xFF7FB4FF),
                ),
        ),
        IconButton(
          tooltip: _recording
              ? 'إيقاف التسجيل وإرساله'
              : 'تسجيل رسالة صوتية',
          onPressed: _busy ? null : _toggleRecording,
          icon: Icon(
            _recording
                ? Icons.stop_circle_rounded
                : Icons.mic_rounded,
            color: _recording
                ? const Color(0xFFFF6868)
                : const Color(0xFF57D99A),
          ),
        ),
      ],
    );
  }
}
