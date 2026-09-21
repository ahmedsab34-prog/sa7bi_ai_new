import 'package:flutter/material.dart';

/// شريط الأدوات السفلي للمحادثة.
///
/// يحتوي فقط على الأدوات الأساسية:
/// - الكاميرا
/// - الفيديو
/// - الصوت
/// - الكتابة
/// - تحويل الكلام إلى نص
/// - توليد الصور
///
/// هذا الملف مسؤول عن شكل الشريط واستدعاء الأحداث فقط.
/// منطق الكاميرا والصوت والذكاء الاصطناعي يظل في ChatScreen.
class ChatToolbar extends StatelessWidget {
  final VoidCallback? onCamera;
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
    this.onVideo,
    this.onVoice,
    this.onText,
    this.onSpeechToText,
    this.onImageGeneration,
    this.enabled = true,
    this.isListening = false,
    this.isGeneratingImage = false,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 4, 10, 8),
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 7,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.075),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withOpacity(0.13),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.20),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          children: [
            _ToolButton(
              icon: Icons.camera_alt_rounded,
              tooltip: 'الكاميرا',
              onPressed: enabled ? onCamera : null,
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
            const Spacer(),
            _ToolButton(
              icon: isGeneratingImage
                  ? Icons.hourglass_top_rounded
                  : Icons.auto_awesome_rounded,
              tooltip: 'توليد صورة',
              active: isGeneratingImage,
              onPressed: enabled && !isGeneratingImage
                  ? onImageGeneration
                  : null,
              emphasized: true,
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(18),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: active
                    ? Colors.white.withOpacity(0.18)
                    : emphasized
                        ? Colors.amber.withOpacity(0.13)
                        : Colors.white.withOpacity(0.045),
                shape: BoxShape.circle,
                border: Border.all(
                  color: active
                      ? Colors.white.withOpacity(0.32)
                      : emphasized
                          ? Colors.amber.withOpacity(0.28)
                          : Colors.white.withOpacity(0.08),
                ),
              ),
              child: Icon(
                icon,
                size: 20,
                color: disabled
                    ? Colors.white.withOpacity(0.25)
                    : active
                        ? Colors.white
                        : emphasized
                            ? Colors.amber.shade200
                            : Colors.white.withOpacity(0.82),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
