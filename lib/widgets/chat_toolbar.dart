import 'package:flutter/material.dart';

/// شريط أدوات المحادثة.
///
/// كل الأدوات تظهر في نفس الشاشة بدون تمرير أفقي.
/// المنطق الحقيقي للأدوات موجود داخل ChatScreen والخدمات.
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(
          8,
          4,
          8,
          6,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 5,
          vertical: 6,
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
            Expanded(
              child: _ToolButton(
                icon: Icons.camera_alt_rounded,
                tooltip: 'الكاميرا',
                onPressed:
                    enabled ? onCamera : null,
              ),
            ),

            Expanded(
              child: _ToolButton(
                icon: Icons.photo_library_rounded,
                tooltip: 'الصور والمعرض',
                onPressed:
                    enabled ? onGallery : null,
              ),
            ),

            Expanded(
              child: _ToolButton(
                icon: Icons.videocam_rounded,
                tooltip: 'فيديو',
                onPressed:
                    enabled ? onVideo : null,
              ),
            ),

            Expanded(
              child: _ToolButton(
                icon: Icons.mic_rounded,
                tooltip: isListening
                    ? 'إيقاف التسجيل'
                    : 'صوت',
                active: isListening,
                onPressed:
                    enabled ? onVoice : null,
              ),
            ),

            Expanded(
              child: _ToolButton(
                icon: Icons.keyboard_rounded,
                tooltip: 'كتابة',
                onPressed:
                    enabled ? onText : null,
              ),
            ),

            Expanded(
              child: _ToolButton(
                icon: isListening
                    ? Icons.stop_circle_rounded
                    : Icons.graphic_eq_rounded,
                tooltip: isListening
                    ? 'إيقاف تحويل الكلام'
                    : 'تحويل الكلام إلى نص',
                active: isListening,
                onPressed:
                    enabled ? onSpeechToText : null,
              ),
            ),

            Expanded(
              child: _ToolButton(
                icon: isGeneratingImage
                    ? Icons.hourglass_top_rounded
                    : Icons.auto_awesome_rounded,
                tooltip: isGeneratingImage
                    ? 'جاري توليد الصورة'
                    : 'توليد صورة',
                active: isGeneratingImage,
                emphasized: true,
                onPressed:
                    enabled && !isGeneratingImage
                        ? onImageGeneration
                        : null,
              ),
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
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius:
                BorderRadius.circular(20),
            child: AnimatedContainer(
              duration:
                  const Duration(milliseconds: 180),
              width: 40,
              height: 40,
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
                          ? Colors.amber.withOpacity(0.30)
                          : Colors.white.withOpacity(0.08),
                  width: 1,
                ),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: Colors.white
                              .withOpacity(0.12),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : emphasized &&
                            !disabled
                        ? [
                            BoxShadow(
                              color: Colors.amber
                                  .withOpacity(0.12),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
              ),
              child: Icon(
                icon,
                size: 19,
                color: disabled
                    ? Colors.white.withOpacity(0.25)
                    : active
                        ? Colors.white
                        : emphasized
                            ? Colors.amber.shade200
                            : Colors.white.withOpacity(0.84),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
