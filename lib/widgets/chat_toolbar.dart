
import 'package:flutter/material.dart';

/// شريط أدوات محادثة مدمج مع الحفاظ على جميع الأدوات.
class ChatToolbar extends StatelessWidget {
  final VoidCallback? onCamera;
  final VoidCallback? onGallery;
  final VoidCallback? onVideo;
  final VoidCallback? onVoice;
  final VoidCallback? onText;
  final VoidCallback? onSpeechToText;
  final VoidCallback? onImageGeneration;
  final VoidCallback? onExperiences;

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
    this.onExperiences,
    this.enabled = true,
    this.isListening = false,
    this.isGeneratingImage = false,
  });

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
            _ToolButton(
              icon: Icons.camera_alt_rounded,
              tooltip: 'الكاميرا',
              onPressed: enabled ? onCamera : null,
            ),
            _ToolButton(
              icon: Icons.photo_library_rounded,
              tooltip: 'الصور والمعرض',
              onPressed: enabled ? onGallery : null,
            ),
            _ToolButton(
              icon: Icons.videocam_rounded,
              tooltip: 'فيديو',
              onPressed: enabled ? onVideo : null,
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
            _ToolButton(
              icon: Icons.sports_esports_rounded,
              tooltip: 'الألعاب والتجارب التفاعلية',
              emphasized: true,
              onPressed: enabled ? onExperiences : null,
            ),
          ],
        ),
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
