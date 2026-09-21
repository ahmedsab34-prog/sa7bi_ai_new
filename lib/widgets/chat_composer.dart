import 'package:flutter/material.dart';

import 'chat_toolbar.dart';

/// منطقة إدخال الرسالة في المحادثة.
///
/// المسؤوليات:
/// - خانة كتابة الرسالة.
/// - زر الإرسال.
/// - إظهار/إخفاء لوحة الأدوات.
/// - دمج ChatToolbar مع خانة الكتابة.
///
/// لا تحتوي على منطق OpenAI أو الحفظ أو الكاميرا.
/// هذه المسؤوليات تظل في ChatScreen / الخدمات المتخصصة.
class ChatComposer extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;

  final VoidCallback? onSend;

  final VoidCallback? onCamera;
  final VoidCallback? onVideo;
  final VoidCallback? onVoice;
  final VoidCallback? onText;
  final VoidCallback? onSpeechToText;
  final VoidCallback? onImageGeneration;

  final bool enabled;
  final bool isListening;
  final bool isGeneratingImage;

  final String hintText;

  const ChatComposer({
    super.key,
    required this.controller,
    this.focusNode,
    this.onSend,
    this.onCamera,
    this.onVideo,
    this.onVoice,
    this.onText,
    this.onSpeechToText,
    this.onImageGeneration,
    this.enabled = true,
    this.isListening = false,
    this.isGeneratingImage = false,
    this.hintText = 'اكتب رسالتك...',
  });

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  bool _showTools = false;

  bool get _hasText => widget.controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant ChatComposer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _send() {
    if (!widget.enabled || !_hasText) {
      return;
    }

    widget.onSend?.call();
  }

  void _toggleTools() {
    if (!widget.enabled) {
      return;
    }

    setState(() {
      _showTools = !_showTools;
    });

    if (_showTools) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_showTools)
            ChatToolbar(
              onCamera: widget.onCamera,
              onVideo: widget.onVideo,
              onVoice: widget.onVoice,
              onText: () {
                _hideToolsAndFocus();
                widget.onText?.call();
              },
              onSpeechToText: widget.onSpeechToText,
              onImageGeneration: widget.onImageGeneration,
              enabled: widget.enabled,
              isListening: widget.isListening,
              isGeneratingImage: widget.isGeneratingImage,
            ),

          _buildInputRow(),
        ],
      ),
    );
  }

  Widget _buildInputRow() {
    final disabled = !widget.enabled;

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 4, 10, 8),
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.085),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withOpacity(0.14),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _roundButton(
            icon: _showTools
                ? Icons.keyboard_arrow_down_rounded
                : Icons.add_rounded,
            tooltip: _showTools ? 'إخفاء الأدوات' : 'الأدوات',
            onPressed: disabled ? null : _toggleTools,
          ),

          const SizedBox(width: 4),

          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: 42,
                maxHeight: 120,
              ),
              child: TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                enabled: widget.enabled,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                textDirection: TextDirection.rtl,
                keyboardType: TextInputType.multiline,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15.5,
                  height: 1.35,
                ),
                cursorColor: Colors.white,
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintTextDirection: TextDirection.rtl,
                  hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.45),
                    fontSize: 15,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                ),
                onSubmitted: (_) {
                  _send();
                },
              ),
            ),
          ),

          const SizedBox(width: 4),

          _sendButton(disabled),
        ],
      ),
    );
  }

  Widget _sendButton(bool disabled) {
    final canSend = !disabled && _hasText;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: canSend ? _send : null,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: canSend
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFFD76A),
                      Color(0xFFFFB84D),
                    ],
                  )
                : null,
            color: canSend
                ? null
                : Colors.white.withOpacity(0.055),
            border: Border.all(
              color: canSend
                  ? Colors.white.withOpacity(0.30)
                  : Colors.white.withOpacity(0.08),
            ),
          ),
          child: Icon(
            Icons.arrow_upward_rounded,
            size: 22,
            color: canSend
                ? Colors.black.withOpacity(0.82)
                : Colors.white.withOpacity(0.28),
          ),
        ),
      ),
    );
  }

  Widget _roundButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    final disabled = onPressed == null;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(21),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(
                disabled ? 0.025 : 0.055,
              ),
              border: Border.all(
                color: Colors.white.withOpacity(
                  disabled ? 0.04 : 0.09,
                ),
              ),
            ),
            child: Icon(
              icon,
              size: 22,
              color: disabled
                  ? Colors.white.withOpacity(0.22)
                  : Colors.white.withOpacity(0.78),
            ),
          ),
        ),
      ),
    );
  }

  void _hideToolsAndFocus() {
    setState(() {
      _showTools = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.enabled) {
        return;
      }

      widget.focusNode?.requestFocus();
    });
  }
}
