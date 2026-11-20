import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../audio_player_service.dart';
import '../models/sa7bi_hero_chat_sticker.dart';
import '../models/social_sticker.dart';
import '../services/social_attachment_service.dart';
import 'sa7bi_hero_sticker_kit.dart';
import 'social_sticker_kit.dart';

class SocialConnectAttachmentMessageView extends StatefulWidget {
  const SocialConnectAttachmentMessageView({
    super.key,
    required this.messageText,
    this.textColor = Colors.white,
  });

  final String messageText;
  final Color textColor;

  @override
  State<SocialConnectAttachmentMessageView> createState() =>
      _SocialConnectAttachmentMessageViewState();
}

class _SocialConnectAttachmentMessageViewState
    extends State<SocialConnectAttachmentMessageView> {
  SocialAttachmentMessage? _envelope;
  Future<File>? _download;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void didUpdateWidget(
    covariant SocialConnectAttachmentMessageView oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.messageText != widget.messageText) _prepare();
  }

  void _prepare() {
    _envelope = SocialAttachmentMessageCodec.decode(widget.messageText);
    final attachment = _envelope?.attachment;
    _download = attachment == null
        ? null
        : SocialAttachmentService.instance.downloadToTemporaryFile(
            attachmentId: attachment.id,
            fileName: attachment.fileName,
          );
  }

  @override
  Widget build(BuildContext context) {
    // Keep all previous static sticker tokens working in private and group chats.
    final classicSticker = Sa7biSticker.tryParse(widget.messageText);
    if (classicSticker != null) {
      return Sa7biStickerMessageView(sticker: classicSticker);
    }

    // New tokens show an actual animated GIF, or a tappable 3D character card.
    final heroSticker = Sa7biHeroChatSticker.tryParse(widget.messageText);
    if (heroSticker != null) {
      // The widget accepts the encoded message and resolves the sticker itself.
      return Sa7biHeroChatStickerMessageView(
        messageText: widget.messageText,
      );
    }

    final envelope = _envelope;
    if (envelope == null) {
      return SelectableText(
        widget.messageText,
        style: TextStyle(color: widget.textColor, height: 1.45),
      );
    }

    return FutureBuilder<File>(
      future: _download,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 9),
                Text(
                  'تحميل المرفق...',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return const Text(
            'تعذر تحميل المرفق. تحقق من الاتصال وحاول مرة أخرى.',
            style: TextStyle(color: Color(0xFFFFB4B4), fontSize: 12),
          );
        }

        return _SocialAttachmentPreview(
          attachment: envelope.attachment,
          caption: envelope.caption,
          file: snapshot.data!,
        );
      },
    );
  }
}

class _SocialAttachmentPreview extends StatelessWidget {
  const _SocialAttachmentPreview({
    required this.attachment,
    required this.caption,
    required this.file,
  });

  final SocialAttachment attachment;
  final String caption;
  final File file;

  @override
  Widget build(BuildContext context) {
    final type = attachment.contentType.toLowerCase();

    if (type.startsWith('image/')) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Image.file(
              file,
              width: 245,
              height: 185,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const _AttachmentFileCard(
                icon: Icons.broken_image_outlined,
                title: 'تعذر عرض الصورة',
                subtitle: 'يمكنك مشاركة الملف لفتحه بتطبيق آخر.',
              ),
            ),
          ),
          if (caption.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(caption, style: const TextStyle(color: Colors.white)),
          ],
          _AttachmentShareButton(file: file, caption: caption),
        ],
      );
    }

    if (type.startsWith('audio/')) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InlineAudioAttachment(
            file: file,
            fileName: attachment.fileName,
          ),
          if (caption.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(caption, style: const TextStyle(color: Colors.white70)),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AttachmentFileCard(
          icon: type == 'application/pdf'
              ? Icons.picture_as_pdf_rounded
              : Icons.insert_drive_file_rounded,
          title: attachment.fileName,
          subtitle: _formatSize(attachment.sizeBytes),
        ),
        _AttachmentShareButton(file: file, caption: caption),
        if (caption.isNotEmpty)
          Text(caption, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Uses the app's central background audio player; it does not create another
/// just_audio player for every voice message.
class _InlineAudioAttachment extends StatefulWidget {
  const _InlineAudioAttachment({
    required this.file,
    required this.fileName,
  });

  final File file;
  final String fileName;

  @override
  State<_InlineAudioAttachment> createState() =>
      _InlineAudioAttachmentState();
}

class _InlineAudioAttachmentState extends State<_InlineAudioAttachment> {
  Future<void> _toggle() async {
    try {
      final handler = AudioController.handler;
      final currentId = handler?.mediaItem.value?.id;
      if (currentId == widget.file.path) {
        final isPlaying = handler?.playbackState.value.playing ?? false;
        if (isPlaying) {
          await AudioController.pause();
        } else {
          await AudioController.play();
        }
      } else {
        await AudioController.playLocalFile(
          path: widget.file.path,
          title: widget.fileName,
          artist: 'رسالة صوتية - صاحبي Connect',
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تشغيل الرسالة الصوتية.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlaybackState>(
      stream: AudioController.handler?.playbackState,
      initialData: AudioController.handler?.playbackState.value,
      builder: (context, snapshot) {
        final handler = AudioController.handler;
        final currentId = handler?.mediaItem.value?.id;
        final isCurrent = currentId == widget.file.path;
        final isPlaying = isCurrent && (snapshot.data?.playing ?? false);

        return Container(
          constraints: const BoxConstraints(maxWidth: 245),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0x332A9D8F),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: isPlaying ? 'إيقاف مؤقت' : 'تشغيل الرسالة الصوتية',
                onPressed: _toggle,
                icon: Icon(
                  isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_fill,
                  color: const Color(0xFF75E0BE),
                  size: 30,
                ),
              ),
              Flexible(
                child: Text(
                  widget.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AttachmentFileCard extends StatelessWidget {
  const _AttachmentFileCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 245),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF202B3E),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF7FB4FF), size: 25),
          const SizedBox(width: 9),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentShareButton extends StatelessWidget {
  const _AttachmentShareButton({
    required this.file,
    required this.caption,
  });

  final File file;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () async {
        try {
          await Share.shareXFiles(
            <XFile>[XFile(file.path)],
            text: caption.isEmpty ? 'مرفق من صاحبي Connect' : caption,
          );
        } catch (_) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذرت مشاركة المرفق.')),
          );
        }
      },
      icon: const Icon(Icons.open_in_new_rounded, size: 16),
      label: const Text('فتح أو مشاركة الملف'),
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF9BC8FF),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
