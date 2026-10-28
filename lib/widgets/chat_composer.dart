
import 'package:flutter/material.dart';

import '../interactive_experiences_screen.dart';
import 'chat_toolbar.dart';

class ChatComposer extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLoading;
  final bool isListening;
  final bool isGeneratingImage;
  final VoidCallback onSend;
  final VoidCallback? onCamera;
  final VoidCallback? onGallery;
  final VoidCallback? onVideo;
  final VoidCallback? onVoice;
  final VoidCallback? onText;
  final VoidCallback? onSpeechToText;
  final VoidCallback? onImageGeneration;

  const ChatComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isLoading,
    required this.isListening,
    required this.isGeneratingImage,
    required this.onSend,
    this.onCamera,
    this.onGallery,
    this.onVideo,
    this.onVoice,
    this.onText,
    this.onSpeechToText,
    this.onImageGeneration,
  });

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _hasText = widget.controller.text.trim().isNotEmpty;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ChatComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
      _hasText = widget.controller.text.trim().isNotEmpty;
    }
  }

  void _onTextChanged() {
    final value = widget.controller.text.trim().isNotEmpty;
    if (!mounted || value == _hasText) return;
    setState(() => _hasText = value);
  }

  void _send() {
    if (widget.isLoading || widget.isGeneratingImage) return;
    if (widget.controller.text.trim().isEmpty) return;
    widget.onSend();
  }

  Future<void> _openExperiences() async {
    if (widget.isLoading || widget.isGeneratingImage) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => InteractiveExperiencesScreen(
          onShareResult: (message) {
            final value = message.trim();
            if (!mounted || value.isEmpty) return;

            widget.controller.text = value;
            widget.controller.selection = TextSelection.collapsed(
              offset: value.length,
            );
            widget.focusNode.requestFocus();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.isLoading || widget.isGeneratingImage;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(7, 3, 7, 5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.25),
          border: Border(
            top: BorderSide(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ChatToolbar(
              onCamera: disabled ? null : widget.onCamera,
              onGallery: disabled ? null : widget.onGallery,
              onVideo: disabled ? null : widget.onVideo,
              onVoice: disabled ? null : widget.onVoice,
              onText: disabled ? null : widget.onText,
              onSpeechToText:
                  disabled ? null : widget.onSpeechToText,
              onImageGeneration:
                  disabled ? null : widget.onImageGeneration,
              onExperiences: disabled ? null : _openExperiences,
              enabled: !disabled,
              isListening: widget.isListening,
              isGeneratingImage: widget.isGeneratingImage,
            ),
            const SizedBox(height: 3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    constraints: const BoxConstraints(
                      minHeight: 42,
                      maxHeight: 112,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.075),
                      borderRadius: BorderRadius.circular(21),
                      border: Border.all(
                        color: _hasText
                            ? const Color(0x6678E8F9)
                            : Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: TextField(
                      controller: widget.controller,
                      focusNode: widget.focusNode,
                      enabled: !disabled,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      keyboardType: TextInputType.multiline,
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.3,
                      ),
                      cursorColor: const Color(0xFF67E8F9),
                      decoration: InputDecoration(
                        hintText: widget.isListening
                            ? 'جاري الاستماع...'
                            : 'اكتب رسالتك لصاحبي...',
                        hintTextDirection: TextDirection.rtl,
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 13,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                      ),
                      onSubmitted: (_) {
                        if (!disabled && _hasText) _send();
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: disabled || !_hasText ? null : _send,
                    borderRadius: BorderRadius.circular(22),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: _hasText && !disabled
                            ? const LinearGradient(
                                colors: [
                                  Color(0xFF67E8F9),
                                  Color(0xFF9B8CFF),
                                ],
                              )
                            : null,
                        color: _hasText && !disabled
                            ? null
                            : Colors.white.withValues(alpha: 0.07),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.10),
                        ),
                      ),
                      child: widget.isLoading
                          ? const Padding(
                              padding: EdgeInsets.all(11),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Icon(
                              Icons.arrow_upward_rounded,
                              color: _hasText && !disabled
                                  ? const Color(0xFF080B14)
                                  : Colors.white.withValues(alpha: 0.35),
                              size: 23,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
