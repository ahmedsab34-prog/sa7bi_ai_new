import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'ai_service.dart';

class ChatScreen extends StatefulWidget {
  final String? serviceTitle;
  final String? serviceContext;

  const ChatScreen({
    super.key,
    this.serviceTitle,
    this.serviceContext,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatMessage {
  final bool isUser;
  final String text;
  final Uint8List? image;

  const _ChatMessage({
    required this.isUser,
    required this.text,
    this.image,
  });
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller =
      TextEditingController();

  final ScrollController _scrollController =
      ScrollController();

  final ImagePicker _picker =
      ImagePicker();

  final stt.SpeechToText _speech =
      stt.SpeechToText();

  final FlutterTts _tts =
      FlutterTts();

  final List<_ChatMessage> _messages = [];

  bool _isLoading = false;
  bool _isListening = false;
  bool _speechReady = false;
  bool _speaking = false;

  @override
  void initState() {
    super.initState();
    _setupTts();
  }

  Future<void> _setupTts() async {
    try {
      await _tts.setLanguage('ar-EG');
      await _tts.setSpeechRate(0.48);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      _tts.setStartHandler(() {
        if (!mounted) return;

        setState(() {
          _speaking = true;
        });
      });

      _tts.setCompletionHandler(() {
        if (!mounted) return;

        setState(() {
          _speaking = false;
        });
      });

      _tts.setCancelHandler(() {
        if (!mounted) return;

        setState(() {
          _speaking = false;
        });
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _tts.stop();
    _speech.stop();
    super.dispose();
  }

  Future<void> _sendText() async {
    final text = _controller.text.trim();

    if (text.isEmpty || _isLoading) {
      return;
    }

    _controller.clear();

    final history = _messages
        .where((m) => m.text.trim().isNotEmpty)
        .map(
          (m) => {
            'role': m.isUser
                ? 'user'
                : 'assistant',
            'content': m.text,
          },
        )
        .toList();

    setState(() {
      _messages.add(
        _ChatMessage(
          isUser: true,
          text: text,
        ),
      );

      _isLoading = true;
    });

    _scrollToBottom();

    final reply = await AiService.getResponse(
      text,
      serviceContext: widget.serviceContext,
      history: history,
    );

    if (!mounted) return;

    setState(() {
      _messages.add(
        _ChatMessage(
          isUser: false,
          text: reply,
        ),
      );

      _isLoading = false;
    });

    _scrollToBottom();
  }

  Future<void> _takePhoto() async {
    if (_isLoading) return;

    final permission =
        await Permission.camera.request();

    if (!permission.isGranted) {
      _showMessage(
        'اسمح للتطبيق باستخدام الكاميرا من إعدادات الهاتف.',
      );
      return;
    }

    try {
      final image =
          await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 65,
        maxWidth: 1280,
      );

      if (image == null) return;

      await _analyzeImage(image);
    } catch (_) {
      _showMessage(
        'حدث خطأ أثناء فتح الكاميرا.',
      );
    }
  }

  Future<void> _pickImage() async {
    if (_isLoading) return;

    try {
      final image =
          await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 65,
        maxWidth: 1280,
      );

      if (image == null) return;

      await _analyzeImage(image);
    } catch (_) {
      _showMessage(
        'حدث خطأ أثناء اختيار الصورة.',
      );
    }
  }

  Future<void> _analyzeImage(
    XFile image,
  ) async {
    if (_isLoading) return;

    setState(() {
      _messages.add(
        _ChatMessage(
          isUser: true,
          text: '📷 تحليل الصورة',
        ),
      );

      _isLoading = true;
    });

    _scrollToBottom();

    final reply =
        await AiService.analyzeImage(
      image,
      prompt:
          'حلل هذه الصورة. اشرح لي بوضوح ماذا ترى فيها، '
          'وإذا كانت تحتوي على منتج أو طعام أو مشكلة أو مستند '
          'فاشرح أهم التفاصيل المفيدة للمستخدم. '
          'لا تخمن معلومات غير واضحة.',
      serviceContext:
          widget.serviceContext,
    );

    if (!mounted) return;

    final bytes =
        await image.readAsBytes();

    setState(() {
      _messages.add(
        _ChatMessage(
          isUser: false,
          text: reply,
          image: bytes,
        ),
      );

      _isLoading = false;
    });

    _scrollToBottom();
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();

      if (mounted) {
        setState(() {
          _isListening = false;
        });
      }

      return;
    }

    final permission =
        await Permission.microphone.request();

    if (!permission.isGranted) {
      _showMessage(
        'اسمح للتطبيق باستخدام الميكروفون.',
      );
      return;
    }

    try {
      if (!_speechReady) {
        _speechReady =
            await _speech.initialize(
          onStatus: (status) {
            if (!mounted) return;

            if (status == 'done' ||
                status == 'notListening') {
              setState(() {
                _isListening = false;
              });
            }
          },
          onError: (_) {
            if (!mounted) return;

            setState(() {
              _isListening = false;
            });
          },
        );
      }

      if (!_speechReady) {
        _showMessage(
          'التعرف على الصوت غير متاح على الهاتف حاليًا.',
        );
        return;
      }

      setState(() {
        _isListening = true;
      });

      await _speech.listen(
        onResult: _onSpeechResult,

        // مهم:
        // لا نضع const هنا لأن SpeechListenOptions
        // في النسخة الحالية ليست const.
        listenOptions:
            stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          autoPunctuation: true,
        ),

        localeId: 'ar_EG',

        listenFor:
            const Duration(
          seconds: 45,
        ),

        pauseFor:
            const Duration(
          seconds: 3,
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _isListening = false;
        });
      }

      _showMessage(
        'حدث خطأ أثناء تشغيل الصوت.',
      );
    }
  }

  void _onSpeechResult(
    SpeechRecognitionResult result,
  ) {
    if (!mounted) return;

    setState(() {
      _controller.text =
          result.recognizedWords;

      _controller.selection =
          TextSelection.fromPosition(
        TextPosition(
          offset:
              _controller.text.length,
        ),
      );
    });

    if (result.finalResult) {
      _speech.stop();

      setState(() {
        _isListening = false;
      });

      if (_controller.text
          .trim()
          .isNotEmpty) {
        _sendText();
      }
    }
  }

  Future<void> _speak(String text) async {
    if (text.trim().isEmpty) return;

    try {
      await _tts.stop();

      await _tts.setLanguage(
        'ar-EG',
      );

      setState(() {
        _speaking = true;
      });

      await _tts.speak(text);
    } catch (_) {
      if (mounted) {
        setState(() {
          _speaking = false;
        });
      }
    }
  }

  Future<void> _generateImage() async {
    if (_isLoading) return;

    final prompt =
        await _askForImagePrompt();

    if (prompt == null ||
        prompt.trim().isEmpty) {
      return;
    }

    setState(() {
      _messages.add(
        _ChatMessage(
          isUser: true,
          text:
              '🎨 إنشاء صورة\n$prompt',
        ),
      );

      _isLoading = true;
    });

    _scrollToBottom();

    final image =
        await AiService.generateImage(
      prompt,
    );

    if (!mounted) return;

    if (image == null) {
      setState(() {
        _messages.add(
          const _ChatMessage(
            isUser: false,
            text:
                'لم أستطع إنشاء الصورة الآن. حاول مرة أخرى.',
          ),
        );

        _isLoading = false;
      });
    } else {
      setState(() {
        _messages.add(
          _ChatMessage(
            isUser: false,
            text:
                'تم إنشاء الصورة بالذكاء الاصطناعي ✨',
            image: image,
          ),
        );

        _isLoading = false;
      });
    }

    _scrollToBottom();
  }

  Future<String?> _askForImagePrompt() async {
    final controller =
        TextEditingController();

    final result =
        await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor:
              const Color(0xFF181824),
          title: const Text(
            'إنشاء صورة',
            textDirection:
                TextDirection.rtl,
            style: TextStyle(
              color: Colors.white,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 4,
            textDirection:
                TextDirection.rtl,
            style: const TextStyle(
              color: Colors.white,
            ),
            decoration:
                const InputDecoration(
              hintText:
                  'اكتب وصف الصورة التي تريدها...',
              hintTextDirection:
                  TextDirection.rtl,
              hintStyle: TextStyle(
                color: Colors.white38,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                context,
              ),
              child:
                  const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(
                context,
                controller.text,
              ),
              child:
                  const Text('إنشاء'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    return result;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance
        .addPostFrameCallback((_) {
      if (!_scrollController
          .hasClients) {
        return;
      }

      _scrollController.animateTo(
        _scrollController
            .position.maxScrollExtent,
        duration:
            const Duration(
          milliseconds: 300,
        ),
        curve: Curves.easeOut,
      );
    });
  }

  void _showMessage(
    String message,
  ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            textDirection:
                TextDirection.rtl,
          ),
          behavior:
              SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final title =
        widget.serviceTitle ??
            'صَحبي AI';

    return Scaffold(
      backgroundColor:
          const Color(0xFF080912),
      appBar: AppBar(
        backgroundColor:
            const Color(0xFF10121C),
        foregroundColor:
            Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          title,
          style: const TextStyle(
            fontWeight:
                FontWeight.w900,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _speaking
                ? () async {
                    await _tts.stop();

                    setState(() {
                      _speaking =
                          false;
                    });
                  }
                : null,
            icon: Icon(
              _speaking
                  ? Icons
                      .volume_off_rounded
                  : Icons
                      .volume_up_rounded,
              color:
                  const Color(
                0xFFFFD76A,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child:
                  _messages.isEmpty
                      ? _buildWelcome()
                      : ListView.builder(
                          controller:
                              _scrollController,
                          padding:
                              const EdgeInsets
                                  .all(14),
                          itemCount:
                              _messages.length,
                          itemBuilder:
                              (context,
                                  index) {
                            return _buildMessage(
                              _messages[index],
                            );
                          },
                        ),
            ),

            if (_isLoading)
              const Padding(
                padding:
                    EdgeInsets.only(
                  bottom: 8,
                ),
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                    SizedBox(
                      width: 8,
                    ),
                    Text(
                      'صَحبي بيجهز الرد...',
                      style: TextStyle(
                        color:
                            Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),

            _buildInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcome() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(26),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration:
                  const BoxDecoration(
                shape:
                    BoxShape.circle,
                gradient:
                    LinearGradient(
                  colors: [
                    Color(
                      0xFFFFD76A,
                    ),
                    Color(
                      0xFFFF8A00,
                    ),
                    Color(
                      0xFF7C4DFF,
                    ),
                  ],
                ),
              ),
              child:
                  const Center(
                child: Text(
                  'س',
                  style:
                      TextStyle(
                    color:
                        Colors.white,
                    fontSize: 48,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(
              height: 20,
            ),
            const Text(
              'قول بس عايز إيه 👋',
              textDirection:
                  TextDirection.rtl,
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                color:
                    Colors.white,
                fontSize: 24,
                fontWeight:
                    FontWeight.w900,
              ),
            ),
            const SizedBox(
              height: 10,
            ),
            const Text(
              'اكتب أو اتكلم أو ابعت صورة…\n'
              'وصَحبي AI هيتعامل معاها.',
              textDirection:
                  TextDirection.rtl,
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                color:
                    Colors.white70,
                fontSize: 15,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage(
    _ChatMessage message,
  ) {
    final isUser =
        message.isUser;

    return Align(
      alignment: isUser
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        constraints:
            const BoxConstraints(
          maxWidth: 360,
        ),
        margin:
            const EdgeInsets.only(
          bottom: 12,
        ),
        padding:
            const EdgeInsets.all(14),
        decoration:
            BoxDecoration(
          gradient: isUser
              ? const LinearGradient(
                  colors: [
                    Color(
                      0xFF5B2C83,
                    ),
                    Color(
                      0xFF342060,
                    ),
                  ],
                )
              : const LinearGradient(
                  colors: [
                    Color(
                      0xFF202532,
                    ),
                    Color(
                      0xFF131720,
                    ),
                  ],
                ),
          borderRadius:
              BorderRadius.only(
            topLeft:
                const Radius.circular(
              20,
            ),
            topRight:
                const Radius.circular(
              20,
            ),
            bottomLeft:
                Radius.circular(
              isUser ? 20 : 5,
            ),
            bottomRight:
                Radius.circular(
              isUser ? 5 : 20,
            ),
          ),
          border:
              Border.all(
            color: isUser
                ? const Color(
                    0x445F3C88,
                  )
                : const Color(
                    0x22FFFFFF,
                  ),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment
                  .stretch,
          children: [
            if (message.image !=
                null)
              ClipRRect(
                borderRadius:
                    BorderRadius
                        .circular(
                  14,
                ),
                child:
                    Image.memory(
                  message.image!,
                  fit:
                      BoxFit.cover,
                ),
              ),
            if (message.image !=
                null)
              const SizedBox(
                height: 10,
              ),
            Text(
              message.text,
              textDirection:
                  TextDirection.rtl,
              style:
                  const TextStyle(
                color:
                    Colors.white,
                fontSize: 16,
                height: 1.55,
              ),
            ),
            if (!isUser &&
                message.text
                    .trim()
                    .isNotEmpty)
              Align(
                alignment:
                    Alignment
                        .bottomLeft,
                child:
                    IconButton(
                  onPressed: () =>
                      _speak(
                    message.text,
                  ),
                  icon:
                      const Icon(
                    Icons
                        .volume_up_rounded,
                    color:
                        Color(
                      0xFFFFD76A,
                    ),
                    size: 21,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding:
          const EdgeInsets.fromLTRB(
        8,
        8,
        8,
        10,
      ),
      decoration:
          const BoxDecoration(
        color:
            Color(0xFF10121C),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _toolButton(
                icon: Icons
                    .camera_alt_rounded,
                tooltip:
                    'الكاميرا',
                onTap:
                    _takePhoto,
              ),
              _toolButton(
                icon: Icons
                    .photo_library_rounded,
                tooltip:
                    'الصور',
                onTap:
                    _pickImage,
              ),
              _toolButton(
                icon: Icons
                    .image_rounded,
                tooltip:
                    'إنشاء صورة',
                onTap:
                    _generateImage,
              ),
              _toolButton(
                icon: _isListening
                    ? Icons
                        .stop_rounded
                    : Icons
                        .mic_rounded,
                tooltip: _isListening
                    ? 'إيقاف الصوت'
                    : 'تحدث',
                active:
                    _isListening,
                onTap:
                    _toggleListening,
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(
            height: 6,
          ),
          Row(
            crossAxisAlignment:
                CrossAxisAlignment
                    .end,
            children: [
              Expanded(
                child: TextField(
                  controller:
                      _controller,
                  minLines: 1,
                  maxLines: 5,
                  textDirection:
                      TextDirection.rtl,
                  style:
                      const TextStyle(
                    color:
                        Colors.white,
                    fontSize: 16,
                  ),
                  decoration:
                      InputDecoration(
                    hintText:
                        'اكتب رسالتك...',
                    hintTextDirection:
                        TextDirection
                            .rtl,
                    hintStyle:
                        const TextStyle(
                      color:
                          Colors.white38,
                    ),
                    filled: true,
                    fillColor:
                        const Color(
                      0xFF1A1D28,
                    ),
                    border:
                        OutlineInputBorder(
                      borderRadius:
                          BorderRadius
                              .circular(
                        22,
                      ),
                      borderSide:
                          BorderSide
                              .none,
                    ),
                    contentPadding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 17,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted:
                      (_) =>
                          _sendText(),
                ),
              ),
              const SizedBox(
                width: 8,
              ),
              Container(
                decoration:
                    const BoxDecoration(
                  shape:
                      BoxShape.circle,
                  gradient:
                      LinearGradient(
                    colors: [
                      Color(
                        0xFFFFD76A,
                      ),
                      Color(
                        0xFFFF8A00,
                      ),
                    ],
                  ),
                ),
                child:
                    IconButton(
                  onPressed:
                      _isLoading
                          ? null
                          : _sendText,
                  icon:
                      const Icon(
                    Icons
                        .send_rounded,
                    color:
                        Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _toolButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return Padding(
      padding:
          const EdgeInsets.only(
        right: 3,
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed:
            _isLoading
                ? null
                : onTap,
        icon: Icon(
          icon,
          color: active
              ? const Color(
                  0xFFFF4D6D,
                )
              : const Color(
                  0xFFFFD76A,
                ),
        ),
      ),
    );
  }
}
