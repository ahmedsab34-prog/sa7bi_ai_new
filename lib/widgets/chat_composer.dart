import 'package:flutter/material.dart';

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
  State<ChatComposer> createState() =>
      _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();

    widget.controller.addListener(
      _onTextChanged,
    );

    _hasText =
        widget.controller.text.trim().isNotEmpty;
  }

  @override
  void dispose() {
    widget.controller.removeListener(
      _onTextChanged,
    );

    super.dispose();
  }

  void _onTextChanged() {
    final hasText =
        widget.controller.text.trim().isNotEmpty;

    if (hasText != _hasText && mounted) {
      setState(() {
        _hasText = hasText;
      });
    }
  }

  void _send() {
    if (widget.isLoading ||
        widget.isGeneratingImage) {
      return;
    }

    if (widget.controller.text.trim().isEmpty) {
      return;
    }

    widget.onSend();
  }

  @override
  Widget build(BuildContext context) {
    final disabled =
        widget.isLoading ||
        widget.isGeneratingImage;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          8,
          6,
          8,
          8,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.25),
          border: Border(
            top: BorderSide(
              color: Colors.white.withOpacity(0.10),
              width: 1,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // =====================================================
            // أدوات المحادثة
            // =====================================================

            ChatToolbar(
              onCamera:
                  disabled ? null : widget.onCamera,
              onGallery:
                  disabled ? null : widget.onGallery,
              onVideo:
                  disabled ? null : widget.onVideo,
              onVoice:
                  disabled ? null : widget.onVoice,
              onText:
                  disabled ? null : widget.onText,
              onSpeechToText:
                  disabled
                      ? null
                      : widget.onSpeechToText,
              onImageGeneration:
                  disabled
                      ? null
                      : widget.onImageGeneration,
              enabled: !disabled,
              isListening:
                  widget.isListening,
              isGeneratingImage:
                  widget.isGeneratingImage,
            ),

            const SizedBox(height: 5),

            // =====================================================
            // مربع الكتابة + زر الإرسال
            // =====================================================

            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: AnimatedContainer(
                    duration:
                        const Duration(
                      milliseconds: 180,
                    ),
                    constraints:
                        const BoxConstraints(
                      minHeight: 50,
                      maxHeight: 135,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(
                        0.095,
                      ),
                      borderRadius:
                          BorderRadius.circular(25),
                      border: Border.all(
                        color: _hasText
                            ? Colors.white.withOpacity(
                                0.24,
                              )
                            : Colors.white.withOpacity(
                                0.13,
                              ),
                        width: 1,
                      ),
                      boxShadow: _hasText
                          ? [
                              BoxShadow(
                                color:
                                    Colors.white
                                        .withOpacity(
                                  0.05,
                                ),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: TextField(
                      controller:
                          widget.controller,
                      focusNode:
                          widget.focusNode,
                      enabled: !disabled,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction:
                          TextInputAction.newline,
                      keyboardType:
                          TextInputType.multiline,
                      textDirection:
                          TextDirection.rtl,
                      textAlign:
                          TextAlign.right,
                      style:
                          const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        height: 1.35,
                      ),
                      cursorColor:
                          Colors.white,
                      decoration:
                          InputDecoration(
                        hintText:
                            widget.isListening
                                ? 'جاري الاستماع...'
                                : 'اكتب رسالتك لصاحبي...',
                        hintTextDirection:
                            TextDirection.rtl,
                        hintStyle:
                            TextStyle(
                          color: Colors.white
                              .withOpacity(0.48),
                          fontSize: 15,
                        ),
                        border:
                            InputBorder.none,
                        contentPadding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 18,
                          vertical: 13,
                        ),
                      ),
                      onSubmitted: (_) {
                        if (!disabled &&
                            _hasText) {
                          _send();
                        }
                      },
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // =================================================
                // زر الإرسال
                // =================================================

                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap:
                        disabled || !_hasText
                            ? null
                            : _send,
                    borderRadius:
                        BorderRadius.circular(25),
                    child:
                        AnimatedContainer(
                      duration:
                          const Duration(
                        milliseconds: 200,
                      ),
                      width: 50,
                      height: 50,
                      decoration:
                          BoxDecoration(
                        shape: BoxShape.circle,
                        gradient:
                            _hasText && !disabled
                                ? const LinearGradient(
                                    begin:
                                        Alignment
                                            .topLeft,
                                    end:
                                        Alignment
                                            .bottomRight,
                                    colors: [
                                      Color(
                                        0xFFFFE08A,
                                      ),
                                      Color(
                                        0xFFFFB347,
                                      ),
                                    ],
                                  )
                                : LinearGradient(
                                    begin:
                                        Alignment
                                            .topLeft,
                                    end:
                                        Alignment
                                            .bottomRight,
                                    colors: [
                                      Color(
                                        0x22FFFFFF,
                                      ),
                                      Color(
                                        0x0FFFFFFF,
                                      ),
                                    ],
                                  ),
                        border: Border.all(
                          color:
                              _hasText && !disabled
                                  ? Colors.white
                                      .withOpacity(
                                      0.28,
                                    )
                                  : Colors.white
                                      .withOpacity(
                                      0.08,
                                    ),
                        ),
                        boxShadow:
                            _hasText && !disabled
                                ? [
                                    BoxShadow(
                                      color:
                                          const Color(
                                        0xFFFFD76A,
                                      ).withOpacity(
                                        0.30,
                                      ),
                                      blurRadius: 14,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                      ),
                      child:
                          widget.isLoading
                              ? const Padding(
                                  padding:
                                      EdgeInsets.all(
                                    14,
                                  ),
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    valueColor:
                                        AlwaysStoppedAnimation<
                                            Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Icon(
                                  Icons
                                      .arrow_upward_rounded,
                                  color:
                                      _hasText &&
                                              !disabled
                                          ? Colors.black
                                          : Colors.white
                                              .withOpacity(
                                            0.30,
                                          ),
                                  size: 26,
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
