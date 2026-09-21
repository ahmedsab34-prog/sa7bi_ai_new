import 'package:flutter/material.dart';

/// شريط التحكم السفلي للمحادثة.
///
/// مسؤول عن شكل وأحداث أزرار الشات فقط.
/// لا يحتوي على منطق AI أو الكاميرا أو الصوت؛
/// ChatScreen هو الذي ينفذ الأحداث التي يتم تمريرها هنا.
class ChatInputBar extends StatelessWidget {
  final TextEditingController controller;

  final VoidCallback onSend;
  final VoidCallback onCamera;
  final VoidCallback onVideo;
  final VoidCallback onVoice;
  final VoidCallback onSpeechToText;
  final VoidCallback onImageGeneration;

  final bool isLoading;
  final bool isListening;
  final bool isSpeaking;
  final bool enabled;

  final String hintText;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onCamera,
    required this.onVideo,
    required this.onVoice,
    required this.onSpeechToText,
    required this.onImageGeneration,
    this.isLoading = false,
    this.isListening = false,
    this.isSpeaking = false,
    this.enabled = true,
    this.hintText = 'اكتب رسالتك...',
  });

  @override
  Widget build(BuildContext context) {
    final canInteract = enabled && !isLoading;

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(
          10,
          6,
          10,
          10,
        ),
        padding: const EdgeInsets.fromLTRB(
          8,
          8,
          8,
          8,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF101522).withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.10),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.30),
              blurRadius: 20,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildToolRow(canInteract),
            const SizedBox(height: 7),
            _buildTextRow(canInteract),
          ],
        ),
      ),
    );
  }

  Widget _buildToolRow(bool canInteract) {
    return SizedBox(
      height: 42,
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          _ToolButton(
            icon: Icons.camera_alt_rounded,
            label: 'كاميرا',
            onTap: canInteract ? onCamera : null,
          ),
          _ToolButton(
            icon: Icons.videocam_rounded,
            label: 'فيديو',
            onTap: canInteract ? onVideo : null,
          ),
          _ToolButton(
            icon: isSpeaking
                ? Icons.volume_off_rounded
                : Icons.mic_rounded,
            label: 'صوت',
            onTap: canInteract ? onVoice : null,
            active: isSpeaking,
          ),
          _ToolButton(
            icon: isListening
                ? Icons.stop_circle_rounded
                : Icons.record_voice_over_rounded,
            label: 'نطق',
            onTap: canInteract ? onSpeechToText : null,
            active: isListening,
          ),
          _ToolButton(
            icon: Icons.image_rounded,
            label: 'صورة',
            onTap: canInteract ? onImageGeneration : null,
          ),
          const Spacer(),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color(0xFF63E6FF),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextRow(bool canInteract) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: canInteract,
            minLines: 1,
            maxLines: 5,
            textDirection: TextDirection.rtl,
            textInputAction: TextInputAction.newline,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.4,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintTextDirection: TextDirection.rtl,
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.42),
                fontSize: 14,
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.045),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 11,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(19),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(19),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(
                  Radius.circular(19),
                ),
                borderSide: BorderSide(
                  color: Color(0xFF63E6FF),
                  width: 1,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 7),
        _SendButton(
          enabled: canInteract,
          onTap: onSend,
        ),
      ],
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;

  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Tooltip(
        message: label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 42,
              height: 38,
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFF63E6FF)
                        .withValues(alpha: 0.14)
                    : Colors.white.withValues(alpha: 0.035),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: active
                      ? const Color(0xFF63E6FF)
                          .withValues(alpha: 0.45)
                      : Colors.white.withValues(alpha: 0.07),
                ),
              ),
              child: Icon(
                icon,
                size: 20,
                color: !enabled
                    ? Colors.white.withValues(alpha: 0.22)
                    : active
                        ? const Color(0xFF63E6FF)
                        : Colors.white.withValues(alpha: 0.78),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;

  const _SendButton({
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(19),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: enabled
                  ? const [
                      Color(0xFF63E6FF),
                      Color(0xFF7C5CFF),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.08),
                      Colors.white.withValues(alpha: 0.04),
                    ],
            ),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: const Color(0xFF63E6FF)
                          .withValues(alpha: 0.18),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            Icons.arrow_upward_rounded,
            color: enabled
                ? Colors.white
                : Colors.white.withValues(alpha: 0.25),
            size: 23,
          ),
        ),
      ),
    );
  }
}
