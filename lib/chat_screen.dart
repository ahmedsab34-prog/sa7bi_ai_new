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
  State<ChatScreen> createState() =>
      _ChatScreenState();
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

      _tts.setErrorHandler((_) {
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

  // ============================================================
  // TEXT
  // ============================================================

  Future<void> _sendText() async {
    final text = _controller.text.trim();

    if (text.isEmpty ||
        _isLoading ||
        _isListening) {
      return;
    }

    _controller.clear();

    // لو المستخدم يطلب صورة بشكل مباشر، نحوله لمسار الصور.
    if (_looksLikeImageRequest(text)) {
      await _generateImageFromPrompt(text);
      return;
    }

    final history = _messages
        .where(
          (m) =>
              m.text.trim().isNotEmpty &&
              m.image == null,
        )
        .map(
          (m) => {
            'role':
                m.isUser
                    ? 'user'
                    : 'assistant',
            'content':
                m.text,
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

    final reply =
        await AiService.getResponse(
      text,
      serviceContext:
          widget.serviceContext,
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

  bool _looksLikeImageRequest(
    String text,
  ) {
    final value = text
        .toLowerCase()
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا');

    final imageWords = [
      'صوره',
      'صورة',
      'صور',
      'تصميم',
      'لوجو',
      'شعار',
      'بوستر',
      'poster',
      'logo',
      'image',
      'generate image',
    ];

    final actionWords = [
      'اعمل',
      'اعملي',
      'اعمللي',
      'انشئ',
      'انشئلي',
      'صمم',
      'صمملي',
      'ارسم',
      'ارسملي',
      'اعمل لي',
      'عايز صوره',
      'عايز صورة',
      'محتاج صوره',
      'محتاج صورة',
      'generate',
      'create',
    ];

    final hasImageWord =
        imageWords.any(
      value.contains,
    );

    final hasActionWord =
        actionWords.any(
      value.contains,
    );

    return hasImageWord &&
        hasActionWord;
  }

  // ============================================================
  // IMAGE ANALYSIS
  // ============================================================

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
        source:
            ImageSource.camera,
        imageQuality: 60,
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
        source:
            ImageSource.gallery,
        imageQuality: 60,
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

    final bytes =
        await image.readAsBytes();

    setState(() {
      _messages.add(
        _ChatMessage(
          isUser: true,
          text:
              '📷 بعتهالك يا صَحبي… حلّلها.',
          image: bytes,
        ),
      );

      _isLoading = true;
    });

    _scrollToBottom();

    final reply =
        await AiService.analyzeImage(
      image,
      prompt:
          'حلل هذه الصورة بذكاء وبطريقة مفيدة. '
          'اشرح ما يظهر فيها بوضوح، '
          'وإذا كان هناك منتج أو طعام أو مشكلة أو مستند '
          'اذكر أهم التفاصيل المفيدة. '
          'لا تخمن الأشياء غير الواضحة.',
      serviceContext:
          widget.serviceContext,
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

  // ============================================================
  // VOICE
  // ============================================================

  Future<void> _toggleListening() async {
    if (_isLoading) return;

    if (_isListening) {
      await _stopListening();
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
          'التعرف على الصوت غير متاح حاليًا.',
        );
        return;
      }

      setState(() {
        _isListening = true;
        _controller.clear();
      });

      await _speech.listen(
        onResult:
            _onSpeechResult,
        listenOptions:
            stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          autoPunctuation: true,
        ),
        localeId: 'ar_EG',
        listenFor:
            const Duration(
          seconds: 35,
        ),
        pauseFor:
            const Duration(
          seconds: 2,
        ),
      );
    } catch (_) {
      await _stopListening();

      _showMessage(
        'الصوت حصل فيه تعليق بسيط. جرّب مرة ثانية.',
      );
    }
  }

  Future<void> _stopListening() async {
    try {
      await _speech.stop();
    } catch (_) {}

    if (!mounted) return;

    setState(() {
      _isListening = false;
    });
  }

  void _onSpeechResult(
    SpeechRecognitionResult result,
  ) {
    if (!mounted) return;

    _controller.text =
        result.recognizedWords;

    _controller.selection =
        TextSelection.fromPosition(
      TextPosition(
        offset:
            _controller.text.length,
      ),
    );

    if (result.finalResult) {
      _stopListening();

      final text =
          _controller.text.trim();

      if (text.isNotEmpty) {
        _sendText();
      }
    }

    setState(() {});
  }

  // ============================================================
  // TTS
  // ============================================================

  Future<void> _speak(
    String text,
  ) async {
    if (text.trim().isEmpty) {
      return;
    }

    try {
      await _tts.stop();

      if (mounted) {
        setState(() {
          _speaking = true;
        });
      }

      await _tts.setLanguage(
        'ar-EG',
      );

      await _tts.speak(text);
    } catch (_) {
      if (mounted) {
        setState(() {
          _speaking = false;
        });
      }
    }
  }

  Future<void> _stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (_) {}

    if (!mounted) return;

    setState(() {
      _speaking = false;
    });
  }

  // ============================================================
  // IMAGE GENERATION
  // ============================================================

  Future<void> _generateImageFromPrompt(
    String prompt,
  ) async {
    if (_isLoading) return;

    setState(() {
      _messages.add(
        _ChatMessage(
          isUser: true,
          text:
              '🎨 طلب صورة\n$prompt',
        ),
      );

      _isLoading = true;
    });

    _scrollToBottom();

    final result =
        await AiService.generateImage(
      prompt,
    );

    if (!mounted) return;

    if (!result.isSuccess) {
      setState(() {
        _messages.add(
          _ChatMessage(
            isUser: false,
            text:
                'حاولت أعمل الصورة، لكن خدمة الصور قالت:\n'
                '${result.error ?? 'حدث خطأ غير معروف.'}',
          ),
        );

        _isLoading = false;
      });

      _scrollToBottom();
      return;
    }

    setState(() {
      _messages.add(
        _ChatMessage(
          isUser: false,
          text:
              'خلصت ✨\nعملت لك الصورة المطلوبة.',
          image: result.bytes,
        ),
      );

      _isLoading = false;
    });

    _scrollToBottom();
  }

  Future<void> _generateImage() async {
    if (_isLoading) return;

    final controller =
        TextEditingController();

    final prompt =
        await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor:
              const Color(0xFF171A24),
          title: const Text(
            '🎨 إنشاء صورة',
            textDirection:
                TextDirection.rtl,
            style: TextStyle(
              color: Colors.white,
              fontWeight:
                  FontWeight.w900,
            ),
          ),
          content: TextField(
            controller:
                controller,
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
                  'اكتب وصف الصورة...',
              hintTextDirection:
                  TextDirection.rtl,
              hintStyle:
                  TextStyle(
                color:
                    Colors.white38,
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

    if (prompt == null ||
        prompt.trim().isEmpty) {
      return;
    }

    await _generateImageFromPrompt(
      prompt.trim(),
    );
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final title =
        widget.serviceTitle ??
            'صَحبي AI';

    return Scaffold(
      backgroundColor:
          const Color(0xFF070911),
      appBar: AppBar(
        backgroundColor:
            const Color(0xFF10131C),
        foregroundColor:
            Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          title,
          style:
              const TextStyle(
            fontWeight:
                FontWeight.w900,
          ),
        ),
        actions: [
          IconButton(
            tooltip:
                _speaking
                    ? 'إيقاف الصوت'
                    : 'قراءة الرد',
            onPressed:
                _speaking
                    ? _stopSpeaking
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
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior
                                  .onDrag,
                          padding:
                              const EdgeInsets
                                  .fromLTRB(
                            12,
                            14,
                            12,
                            12,
                          ),
                          itemCount:
                              _messages.length,
                          itemBuilder:
                              (context,
                                  index) {
                            return _MessageBubble(
                              message:
                                  _messages[index],
                              onSpeak:
                                  _speak,
                            );
                          },
                        ),
            ),

            if (_isListening)
              _buildListeningBar(),

            if (_isLoading)
              _buildLoadingBar(),

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
            const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration:
                  const BoxDecoration(
                shape:
                    BoxShape.circle,
                gradient:
                    SweepGradient(
                  colors: [
                    Color(
                      0xFFFFD76A,
                    ),
                    Color(
                      0xFF8B5CF6,
                    ),
                    Color(
                      0xFF22D3EE,
                    ),
                    Color(
                      0xFFFFD76A,
                    ),
                  ],
                ),
              ),
              padding:
                  const EdgeInsets.all(
                3,
              ),
              child: Container(
                decoration:
                    const BoxDecoration(
                  shape:
                      BoxShape.circle,
                  color:
                      Color(0xFF10131C),
                ),
                child:
                    const Center(
                  child: Text(
                    'س',
                    style:
                        TextStyle(
                      color:
                          Colors.white,
                      fontSize:
                          46,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(
              height: 20,
            ),
            const Text(
              'قول يا صاحبي 👋',
              textDirection:
                  TextDirection.rtl,
              style:
                  TextStyle(
                color:
                    Colors.white,
                fontSize:
                    25,
                fontWeight:
                    FontWeight.w900,
              ),
            ),
            const SizedBox(
              height: 10,
            ),
            const Text(
              'اكتب أو اتكلم أو ابعت صورة…\n'
              'ولو عايز صورة جديدة قول له: اعمل لي صورة 🎨',
              textDirection:
                  TextDirection.rtl,
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                color:
                    Colors.white60,
                fontSize:
                    15,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingBar() {
    return const Padding(
      padding:
          EdgeInsets.only(
        left: 18,
        right: 18,
        bottom: 7,
      ),
      child: Row(
        textDirection:
            TextDirection.rtl,
        children: [
          SizedBox(
            width: 15,
            height: 15,
            child:
                CircularProgressIndicator(
              strokeWidth: 2,
            ),
          ),
          SizedBox(
            width: 8,
          ),
          Text(
            'صَحبي بيفكر… ✨',
            style:
                TextStyle(
              color:
                  Colors.white60,
              fontSize:
                  13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListeningBar() {
    return Container(
      margin:
          const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 4,
      ),
      padding:
          const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 10,
      ),
      decoration:
          BoxDecoration(
        color:
            const Color(0x3322D3EE),
        borderRadius:
            BorderRadius.circular(
          16,
        ),
        border:
            Border.all(
          color:
              const Color(0x5533D9FF),
        ),
      ),
      child: Row(
        textDirection:
            TextDirection.rtl,
        children: [
          const Icon(
            Icons.mic_rounded,
            color:
                Color(0xFF67E8F9),
          ),
          const SizedBox(
            width: 8,
          ),
          const Expanded(
            child: Text(
              'سامعك… اتكلم براحتك 🎙️',
              textDirection:
                  TextDirection.rtl,
              style:
                  TextStyle(
                color:
                    Colors.white,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            onPressed:
                _stopListening,
            icon:
                const Icon(
              Icons.stop_circle,
              color:
                  Color(0xFFFF6B6B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding:
          const EdgeInsets.fromLTRB(
        10,
        8,
        10,
        10,
      ),
      decoration:
          const BoxDecoration(
        color:
            Color(0xFF0D1018),
        border:
            Border(
          top:
              BorderSide(
            color:
                Color(0x221FFFFFF),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.end,
        children: [
          _InputIconButton(
            icon:
                Icons.camera_alt_rounded,
            color:
                const Color(0xFFFFD76A),
            onTap:
                _takePhoto,
          ),
          _InputIconButton(
            icon:
                Icons.photo_library_rounded,
            color:
                const Color(0xFFB794F4),
            onTap:
                _pickImage,
          ),
          _InputIconButton(
            icon:
                Icons.image_rounded,
            color:
                const Color(0xFF67E8F9),
            onTap:
                _generateImage,
          ),
          _InputIconButton(
            icon:
                _isListening
                    ? Icons
                        .stop_rounded
                    : Icons
                        .mic_rounded,
            color:
                _isListening
                    ? const Color(
                        0xFFFF6B6B,
                      )
                    : const Color(
                        0xFF67E8F9,
                      ),
            onTap:
                _toggleListening,
          ),
          Expanded(
            child:
                TextField(
              controller:
                  _controller,
              enabled:
                  !_isLoading,
              minLines: 1,
              maxLines: 4,
              textDirection:
                  TextDirection.rtl,
              textInputAction:
                  TextInputAction.newline,
              style:
                  const TextStyle(
                color:
                    Colors.white,
                fontSize:
                    16,
              ),
              decoration:
                  InputDecoration(
                hintText:
                    _isListening
                        ? 'جاري الاستماع…'
                        : 'اكتب لصَحبي…',
                hintTextDirection:
                    TextDirection.rtl,
                hintStyle:
                    const TextStyle(
                  color:
                      Colors.white38,
                ),
                filled:
                    true,
                fillColor:
                    const Color(
                  0xFF171A24,
                ),
                contentPadding:
                    const EdgeInsets
                        .symmetric(
                  horizontal:
                      14,
                  vertical:
                      11,
                ),
                border:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius
                          .circular(
                    20,
                  ),
                  borderSide:
                      BorderSide.none,
                ),
              ),
              onSubmitted:
                  (_) {
                if (!_isLoading) {
                  _sendText();
                }
              },
            ),
          ),
          const SizedBox(
            width: 8,
          ),
          _InputIconButton(
            icon:
                Icons.send_rounded,
            color:
                const Color(0xFFFFD76A),
            onTap:
                _sendText,
          ),
        ],
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance
        .addPostFrameCallback(
      (_) {
        if (!_scrollController
            .hasClients) {
          return;
        }

        _scrollController
            .animateTo(
          _scrollController
              .position
              .maxScrollExtent,
          duration:
              const Duration(
            milliseconds: 220,
          ),
          curve:
              Curves.easeOut,
        );
      },
    );
  }

  void _showMessage(
    String message,
  ) {
    if (!mounted) return;

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
}

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;
  final Future<void> Function(String)
      onSpeak;

  const _MessageBubble({
    required this.message,
    required this.onSpeak,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final isUser =
        message.isUser;

    final emotion =
        isUser
            ? '👤'
            : _emotionFor(
                message.text,
              );

    return Align(
      alignment: isUser
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        constraints:
            const BoxConstraints(
          maxWidth: 370,
        ),
        margin:
            const EdgeInsets.only(
          bottom: 12,
        ),
        padding:
            const EdgeInsets.fromLTRB(
          14,
          11,
          14,
          10,
        ),
        decoration:
            BoxDecoration(
          gradient: isUser
              ? const LinearGradient(
                  begin:
                      Alignment.topRight,
                  end:
                      Alignment.bottomLeft,
                  colors: [
                    Color(
                      0xFF7546A8,
                    ),
                    Color(
                      0xFF38215E,
                    ),
                  ],
                )
              : const LinearGradient(
                  begin:
                      Alignment.topRight,
                  end:
                      Alignment.bottomLeft,
                  colors: [
                    Color(
                      0xFF1F2B39,
                    ),
                    Color(
                      0xFF121821,
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
                    0x665E3D88,
                  )
                : const Color(
                    0x3348D7FF,
                  ),
          ),
          boxShadow:
              const [
            BoxShadow(
              color:
                  Color(0x22000000),
              blurRadius:
                  10,
              offset:
                  Offset(0, 4),
            ),
          ],
        ),
        child:
            Column(
          crossAxisAlignment:
              CrossAxisAlignment
                  .start,
          children: [
            Row(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Text(
                  emotion,
                  style:
                      const TextStyle(
                    fontSize:
                        15,
                  ),
                ),
                const SizedBox(
                  width: 6,
                ),
                Text(
                  isUser
                      ? 'أنت'
                      : 'صَحبي AI',
                  textDirection:
                      TextDirection
                          .rtl,
                  style:
                      TextStyle(
                    color: isUser
                        ? const Color(
                            0xFFE9D5FF,
                          )
                        : const Color(
                            0xFF8BE9FD,
                          ),
                    fontSize:
                        12,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ],
            ),
            if (message.image !=
                null) ...[
              const SizedBox(
                height: 9,
              ),
              ClipRRect(
                borderRadius:
                    BorderRadius
                        .circular(
                  16,
                ),
                child:
                    Image.memory(
                  message.image!,
                  width:
                      330,
                  height:
                      230,
                  fit:
                      BoxFit.cover,
                  gaplessPlayback:
                      true,
                ),
              ),
            ],
            if (message.text
                .trim()
                .isNotEmpty) ...[
              const SizedBox(
                height: 8,
              ),
              SelectableText(
                message.text,
                textDirection:
                    TextDirection.rtl,
                textAlign:
                    TextAlign.right,
                style:
                    TextStyle(
                  color:
                      Colors.white,
                  fontSize:
                      16,
                  height:
                      1.55,
                  fontWeight:
                      isUser
                          ? FontWeight.w600
                          : FontWeight.w500,
                ),
              ),
            ],
            if (!isUser &&
                message.text
                    .trim()
                    .isNotEmpty)
              Align(
                alignment:
                    Alignment.centerLeft,
                child:
                    IconButton(
                  visualDensity:
                      VisualDensity
                          .compact,
                  onPressed:
                      () => onSpeak(
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
                    size:
                        20,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _emotionFor(
    String text,
  ) {
    final value =
        text.toLowerCase();

    if (value.contains('مبروك') ||
        value.contains('ممتاز') ||
        value.contains('رائع') ||
        value.contains('نجاح')) {
      return '🎉';
    }

    if (value.contains('حزين') ||
        value.contains('آسف') ||
        value.contains('صعب') ||
        value.contains('مشكلة')) {
      return '🤝';
    }

    if (value.contains('تحذير') ||
        value.contains('خطر') ||
        value.contains('انتبه')) {
      return '⚠️';
    }

    if (value.contains('فكرة') ||
        value.contains('إبداع') ||
        value.contains('تصميم')) {
      return '✨';
    }

    if (value.contains('سؤال') ||
        value.contains('معلومة')) {
      return '💡';
    }

    return '🤖';
  }
}

class _InputIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _InputIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return IconButton(
      onPressed:
          onTap,
      visualDensity:
          VisualDensity.compact,
      icon:
          Icon(
        icon,
        color:
            color,
        size:
            23,
      ),
    );
  }
}
