import 'package:flutter/material.dart';

/// شريط أدوات محادثة مدمج.
/// الصورة والفيديو أصبحا تحت زر وسائط واحد.
/// لا يوجد زر ألعاب هنا؛ الألعاب لها تبويب مستقل.
class ChatToolbar extends StatelessWidget {
  final VoidCallback? onCamera;
  final VoidCallback? onGallery;
  final VoidCallback? onVideo;
  final VoidCallback? onVoice;
  final VoidCallback? onText;
  final VoidCallback? onSpeechToText;
  final VoidCallback? onImageGeneration;

  final bool enabled;
  final bool isListening;
  final bool isGeneratingImage;

  const ChatToolbar({
    super.key,
    this.onCamera,
    this.onGallery,
    this.onVideo,
    this.onVoice,
    this.onText,
    this.onSpeechToText,
    this.onImageGeneration,
    this.enabled = true,
    this.isListening = false,
    this.isGeneratingImage = false,
  });

  Future<void> _openMediaMenu(BuildContext context) async {
    if (!enabled) return;

    final hasMediaAction =
        onCamera != null ||
        onGallery != null ||
        onVideo != null;

    if (!hasMediaAction) return;

    final action = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: const Color(0xFF111827),
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(22),
        ),
      ),
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                14,
                4,
                14,
                18,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'إرسال صورة أو فيديو',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (onCamera != null)
                    _MediaChoiceTile(
                      icon: Icons.camera_alt_rounded,
                      title: 'التقاط صورة بالكاميرا',
                      subtitle: 'تصوير صورة جديدة للتحليل',
                      onTap: () {
                        Navigator.pop(sheetContext, 1);
                      },
                    ),

                  if (onGallery != null)
                    _MediaChoiceTile(
                      icon: Icons.photo_library_rounded,
                      title: 'اختيار صورة من المعرض',
                      subtitle: 'إرسال صورة محفوظة على الجهاز',
                      onTap: () {
                        Navigator.pop(sheetContext, 2);
                      },
                    ),

                  if (onVideo != null)
                    _MediaChoiceTile(
                      icon: Icons.videocam_rounded,
                      title: 'اختيار فيديو',
                      subtitle: 'إرسال فيديو لتحليل محتواه',
                      onTap: () {
                        Navigator.pop(sheetContext, 3);
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (!context.mounted || !enabled) return;

    switch (action) {
      case 1:
        onCamera?.call();
        break;
      case 2:
        onGallery?.call();
        break;
      case 3:
        onVideo?.call();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(5, 2, 5, 3),
      padding: const EdgeInsets.symmetric(
        horizontal: 3,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.09),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onCamera != null ||
                onGallery != null ||
                onVideo != null)
              _ToolButton(
                icon: Icons.add_a_photo_rounded,
                tooltip: 'صورة أو فيديو',
                onPressed: enabled
                    ? () => _openMediaMenu(context)
                    : null,
              ),

            _ToolButton(
              icon: Icons.mic_rounded,
              tooltip: isListening ? 'إيقاف التسجيل' : 'صوت',
              active: isListening,
              onPressed: enabled ? onVoice : null,
            ),

            _ToolButton(
              icon: Icons.keyboard_rounded,
              tooltip: 'كتابة',
              onPressed: enabled ? onText : null,
            ),

            _ToolButton(
              icon: isListening
                  ? Icons.stop_circle_rounded
                  : Icons.graphic_eq_rounded,
              tooltip: isListening
                  ? 'إيقاف تحويل الكلام'
                  : 'تحويل الكلام إلى نص',
              active: isListening,
              onPressed: enabled ? onSpeechToText : null,
            ),

            _ToolButton(
              icon: isGeneratingImage
                  ? Icons.hourglass_top_rounded
                  : Icons.auto_awesome_rounded,
              tooltip: isGeneratingImage
                  ? 'جاري توليد الصورة'
                  : 'توليد صورة',
              active: isGeneratingImage,
              emphasized: true,
              onPressed: enabled && !isGeneratingImage
                  ? onImageGeneration
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaChoiceTile extends StatelessWidget {
  const _MediaChoiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 2,
      ),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0x2267E8F9),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(
          icon,
          color: const Color(0xFF67E8F9),
          size: 21,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 10,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_left_rounded,
        color: Colors.white38,
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool active;
  final bool emphasized;

  const _ToolButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;

    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(15),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: active
                    ? const Color(0x3367E8F9)
                    : emphasized
                        ? const Color(0x229B8CFF)
                        : Colors.white.withValues(alpha: 0.035),
                shape: BoxShape.circle,
                border: Border.all(
                  color: active
                      ? const Color(0x8867E8F9)
                      : emphasized
                          ? const Color(0x559B8CFF)
                          : Colors.white.withValues(alpha: 0.07),
                ),
              ),
              child: Icon(
                icon,
                size: 17,
                color: disabled
                    ? Colors.white.withValues(alpha: 0.23)
                    : active
                        ? const Color(0xFF67E8F9)
                        : emphasized
                            ? const Color(0xFFB7AFFF)
                            : Colors.white.withValues(alpha: 0.82),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
