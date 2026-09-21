import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

class _Message {
  final bool user;
  final String text;
  final Uint8List? image;
  final bool video;

  const _Message({
    required this.user,
    required this.text,
    this.image,
    this.video = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'user': user,
      'text': text,
      'video': video,
      if (image != null) 'image': base64Encode(image!),
    };
  }

  factory _Message.fromJson(Map<String, dynamic> json) {
    Uint8List? image;

    final encoded = json['image'];

    if (encoded is String && encoded.isNotEmpty) {
      try {
        image = base64Decode(encoded);
      } catch (_) {
        image = null;
      }
    }

    return _Message(
      user: json['user'] == true,
      text: json['text']?.toString() ?? '',
      image: image,
      video: json['video'] == true,
    );
  }
}

class _ChatTheme {
  final Color primary;
  final Color secondary;
  final Color glow;
  final Color userBubble;
  final Color aiBubble;
  final IconData icon;

  const _ChatTheme({
    required this.primary,
    required this.secondary,
    required this.glow,
    required this.userBubble,
    required this.aiBubble,
    required this.icon,
  });
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController controller =
      TextEditingController();

  final ScrollController scrollController =
      ScrollController();

  final ImagePicker picker =
      ImagePicker();

  final stt.SpeechToText speech =
      stt.SpeechToText();

  final FlutterTts tts =
      FlutterTts();

  final List<_Message> messages =
      <_Message>[];

  bool loading = false;
  bool listening = false;
  bool speechReady = false;
  bool speaking = false;
  bool saving = false;

  late final _ChatTheme theme;
  late final String storageKey;

  @override
  void initState() {
    super.initState();

    theme = _themeForService(
      widget.serviceTitle ?? '',
    );

    storageKey = _storageKey();

    _setupTts();
    _loadHistory();
  }

  String _storageKey() {
    final title =
        (widget.serviceTitle ?? 'general')
            .trim()
            .toLowerCase();

    final contextValue =
        (widget.serviceContext ?? '')
            .trim()
            .toLowerCase();

    final raw =
        '$title|$contextValue';

    final safe = raw
        .replaceAll(
          RegExp(r'[^a-zA-Z0-9\u0600-\u06FF]+'),
          '_',
        );

    return 'sa7bi_chat_history_$safe';
  }

  _ChatTheme _themeForService(
    String title,
  ) {
    if (title.contains('المطبخ')) {
      return const _ChatTheme(
        primary: Color(0xFFFF9D42),
        secondary: Color(0xFFFFD166),
        glow: Color(0xFFFF7A18),
        userBubble: Color(0xFF673B18),
        aiBubble: Color(0xFF21170E),
        icon: Icons.restaurant_menu_rounded,
      );
    }

    if (title.contains('التجارة')) {
      return const _ChatTheme(
        primary: Color(0xFF37E58C),
        secondary: Color(0xFF00C853),
        glow: Color(0xFF00E676),
        userBubble: Color(0xFF124C35),
        aiBubble: Color(0xFF10211A),
        icon: Icons.storefront_rounded,
      );
    }

    if (title.contains('الصيدلية')) {
      return const _ChatTheme(
        primary: Color(0xFF45D9F5),
        secondary: Color(0xFF00B8D4),
        glow: Color(0xFF00E5FF),
        userBubble: Color(0xFF124452),
        aiBubble: Color(0xFF0C2025),
        icon: Icons.local_pharmacy_rounded,
      );
    }

    if (title.contains('الحرفيين')) {
      return const _ChatTheme(
        primary: Color(0xFFFFC857),
        secondary: Color(0xFFFFA000),
        glow: Color(0xFFFFB300),
        userBubble: Color(0xFF514016),
        aiBubble: Color(0xFF211D0E),
        icon: Icons.handyman_rounded,
      );
    }

    if (title.contains('العبادة')) {
      return const _ChatTheme(
        primary: Color(0xFF4DD6C0),
        secondary: Color(0xFF26A69A),
        glow: Color(0xFF00BFA5),
        userBubble: Color(0xFF16483F),
        aiBubble: Color(0xFF0E2421),
        icon: Icons.mosque_rounded,
      );
    }

    if (title.contains('التسوق')) {
      return const _ChatTheme(
        primary: Color(0xFFFF5E9C),
        secondary: Color(0xFFE91E63),
        glow: Color(0xFFFF4081),
        userBubble: Color(0xFF542039),
        aiBubble: Color(0xFF25121B),
        icon: Icons.shopping_cart_rounded,
      );
    }

    if (title.contains('التواصل')) {
      return const _ChatTheme(
        primary: Color(0xFF9B7CFF),
        secondary: Color(0xFF7C4DFF),
        glow: Color(0xFF651FFF),
        userBubble: Color(0xFF3D286B),
        aiBubble: Color(0xFF191329),
        icon: Icons.people_alt_rounded,
      );
    }

    if (title.contains('فضفضة')) {
      return const _ChatTheme(
        primary: Color(0xFFD17BFF),
        secondary: Color(0xFF9C27B0),
        glow: Color(0xFFE040FB),
        userBubble: Color(0xFF4B2057),
        aiBubble: Color(0xFF201125),
        icon: Icons.lock_rounded,
      );
    }

    if (title.contains('الهوايات') ||
        title.contains('الرياضة')) {
      return const _ChatTheme(
        primary: Color(0xFF51B7FF),
        secondary: Color(0xFF2196F3),
        glow: Color(0xFF2979FF),
        userBubble: Color(0xFF173E61),
        aiBubble: Color(0xFF102031),
        icon: Icons.sports_soccer_rounded,
      );
    }

    if (title.contains('البودكاست')) {
      return const _ChatTheme(
        primary: Color(0xFFFF67A4),
        secondary: Color(0xFFFF4081),
        glow: Color(0xFFF50057),
        userBubble: Color(0xFF542037),
        aiBubble: Color(0xFF24121B),
        icon: Icons.podcasts_rounded,
      );
    }

    return const _ChatTheme(
      primary: Color(0xFFFFD76A),
      secondary: Color(0xFF8B6CFF),
      glow: Color(0xFF67E8F9),
      userBubble: Color(0xFF38215E),
      aiBubble: Color(0xFF151D28),
      icon: Icons.auto_awesome_rounded,
    );
  }

  Future<void> _setupTts() async {
    try {
      await tts.setLanguage('ar-EG');
      await tts.setSpeechRate(0.48);
      await tts.setVolume(1);
      await tts.setPitch(1);

      tts.setStartHandler(() {
        if (!mounted) return;

        setState(() {
          speaking = true;
        });
      });

      tts.setCompletionHandler(() {
        if (!mounted) return;

        setState(() {
          speaking = false;
        });
      });

      tts.setCancelHandler(() {
        if (!mounted) return;

        setState(() {
          speaking = false;
        });
      });

      tts.setErrorHandler((_) {
        if (!mounted) return;

        setState(() {
          speaking = false;
        });
      });
    } catch (_) {}
  }

  Future<void> _loadHistory() async {
    try {
      final prefs =
          await SharedPreferences.getInstance();

      final raw =
          prefs.getString(storageKey);

      if (raw == null ||
          raw.trim().isEmpty) {
        return;
      }

      final decoded =
          jsonDecode(raw);

      if (decoded is! List) {
        return;
      }

      final loaded =
          <_Message>[];

      for (final item in decoded) {
        if (item is Map) {
          loaded.add(
            _Message.fromJson(
              Map<String, dynamic>.from(item),
            ),
          );
        }
      }

      if (!mounted) return;

      setState(() {
        messages.addAll(
          loaded.take(80),
        );
      });

      scrollBottom();
    } catch (_) {}
  }

  Future<void> _saveHistory() async {
    if (saving) return;

    saving = true;

    try {
      final prefs =
          await SharedPreferences.getInstance();

      final limited =
          messages.length > 80
              ? messages.sublist(
                  messages.length - 80,
                )
              : messages;

      final encoded =
          jsonEncode(
        limited
            .map((item) => item.toJson())
            .toList(),
      );

      await prefs.setString(
        storageKey,
        encoded,
      );
    } catch (_) {
      // عدم حفظ المحادثة لا يوقف التطبيق.
    } finally {
      saving = false;
    }
  }

  @override
  void dispose() {
    controller.dispose();
    scrollController.dispose();

    tts.stop();
    speech.stop();

    super.dispose();
  }

  Future<void> send() async {
    final text =
        controller.text.trim();

    if (text.isEmpty ||
        loading ||
        listening) {
      return;
    }

    controller.clear();

    if (_isImageRequest(text)) {
      await generateImage(text);
      return;
    }

    final history =
        messages
            .where(
              (item) =>
                  item.text
                      .trim()
                      .isNotEmpty &&
                  item.image == null &&
                  !item.video,
            )
            .map(
              (item) => {
                'role': item.user
                    ? 'user'
                    : 'assistant',
                'content': item.text,
              },
            )
            .toList();

    setState(() {
      messages.add(
        _Message(
          user: true,
          text: text,
        ),
      );

      loading = true;
    });

    await _saveHistory();
    scrollBottom();

    String reply;

    try {
      reply =
          await AiService.getResponse(
        text,
        serviceContext:
            widget.serviceContext,
        history: history,
      );
    } catch (_) {
      reply =
          'حصلت مشكلة مؤقتة في الاتصال بصاحبي. حاول مرة تانية.';
    }

    if (!mounted) return;

    setState(() {
      messages.add(
        _Message(
          user: false,
          text: reply,
        ),
      );

      loading = false;
    });

    await _saveHistory();
    scrollBottom();
  }

  bool _isImageRequest(
    String text,
  ) {
    final value =
        text
            .toLowerCase()
            .replaceAll('أ', 'ا')
            .replaceAll('إ', 'ا')
            .replaceAll('آ', 'ا');

    const imageWords = [
      'صورة',
      'صوره',
      'صور',
      'تصميم',
      'لوجو',
      'شعار',
      'بوستر',
      'image',
      'logo',
      'poster',
    ];

    const actionWords = [
      'اعمل',
      'اعملي',
      'اعمللي',
      'انشئ',
      'انشئلي',
      'صمم',
      'صمملي',
      'ارسم',
      'عايز',
      'محتاج',
      'create',
      'generate',
      'make',
      'draw',
    ];

    return imageWords.any(
          value.contains,
        ) &&
        actionWords.any(
          value.contains,
        );
  }

  Future<void> _showMediaOptions() async {
    if (loading) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor:
          const Color(0xFF11151F),
      shape:
          const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(26),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.fromLTRB(
              18,
              18,
              18,
              20,
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Container(
                  width: 45,
                  height: 4,
                  decoration:
                      BoxDecoration(
                    color:
                        Colors.white24,
                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'إرسال محتوى',
                  textDirection:
                      TextDirection.rtl,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                _MediaOption(
                  icon:
                      Icons.camera_alt_rounded,
                  title:
                      'الكاميرا',
                  color:
                      theme.primary,
                  onTap: () {
                    Navigator.pop(
                      sheetContext,
                    );
                    takePhoto();
                  },
                ),
                _MediaOption(
                  icon:
                      Icons.photo_library_rounded,
                  title:
                      'صورة من الهاتف',
                  color:
                      theme.secondary,
                  onTap: () {
                    Navigator.pop(
                      sheetContext,
                    );
                    pickImage();
                  },
                ),
                _MediaOption(
                  icon:
                      Icons.videocam_rounded,
                  title:
                      'فيديو من الهاتف',
                  color:
                      theme.glow,
                  onTap: () {
                    Navigator.pop(
                      sheetContext,
                    );
                    pickVideo();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> takePhoto() async {
    if (loading) return;

    final permission =
        await Permission.camera.request();

    if (!permission.isGranted) {
      message(
        'اسمح للتطبيق باستخدام الكاميرا.',
      );
      return;
    }

    try {
      final image =
          await picker.pickImage(
        source:
            ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1440,
      );

      if (image != null) {
        await analyzeImage(image);
      }
    } catch (_) {
      message(
        'تعذر فتح الكاميرا.',
      );
    }
  }

  Future<void> pickImage() async {
    if (loading) return;

    try {
      final image =
          await picker.pickImage(
        source:
            ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1440,
      );

      if (image != null) {
        await analyzeImage(image);
      }
    } catch (_) {
      message(
        'تعذر اختيار الصورة.',
      );
    }
  }

  Future<void> pickVideo() async {
    if (loading) return;

    try {
      final video =
          await picker.pickVideo(
        source:
            ImageSource.gallery,
        maxDuration:
            const Duration(
          minutes: 5,
        ),
      );

      if (video == null) return;

      final fileName =
          video.name.trim().isEmpty
              ? 'فيديو'
              : video.name;

      setState(() {
        messages.add(
          _Message(
            user: true,
            text:
                'أرسلت فيديو: $fileName\n\n'
                'تم استلام الفيديو. يمكنني استخدام محتواه في الخطوات المدعومة من النظام، '
                'بينما تحليل الفيديو نفسه سيُضاف إلى طبقة الرؤية المرئية لاحقًا.',
            video: true,
          ),
        );
      });

      await _saveHistory();
      scrollBottom();
    } catch (_) {
      message(
        'تعذر اختيار الفيديو.',
      );
    }
  }

  Future<void> analyzeImage(
    XFile image,
  ) async {
    if (loading) return;

    try {
      final bytes =
          await image.readAsBytes();

      if (bytes.isEmpty) {
        message(
          'لم أستطع قراءة الصورة.',
        );
        return;
      }

      setState(() {
        messages.add(
          _Message(
            user: true,
            text:
                'أرسلت صورة لتحليلها.',
            image: bytes,
          ),
        );

        loading = true;
      });

      await _saveHistory();
      scrollBottom();

      String reply;

      try {
        reply =
            await AiService.analyzeImage(
          image,
          prompt:
              'حلل الصورة بطريقة مفيدة حسب مجال هذه المحادثة. '
              'صف الأشياء الظاهرة بوضوح، '
              'واذكر أهم التفاصيل المفيدة. '
              'لا تخمن الأشياء غير الواضحة. '
              'إذا كانت الصورة غير كافية، قل ذلك بوضوح.',
          serviceContext:
              widget.serviceContext,
        );
      } catch (_) {
        reply =
            'تعذر تحليل الصورة حاليًا. تأكد من اتصال الإنترنت وحاول مرة أخرى.';
      }

      if (!mounted) return;

      setState(() {
        messages.add(
          _Message(
            user: false,
            text: reply,
          ),
        );

        loading = false;
      });

      await _saveHistory();
      scrollBottom();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      message(
        'حدث خطأ أثناء قراءة الصورة.',
      );
    }
  }

  Future<void> toggleListening() async {
    if (loading) return;

    if (listening) {
      await stopListening();
      return;
    }

    final permission =
        await Permission.microphone.request();

    if (!permission.isGranted) {
      message(
        'اسمح للتطبيق باستخدام الميكروفون.',
      );
      return;
    }

    try {
      if (!speechReady) {
        speechReady =
            await speech.initialize(
          onStatus: (status) {
            if (!mounted) return;

            if (status == 'done' ||
                status ==
                    'notListening') {
              setState(() {
                listening = false;
              });
            }
          },
          onError: (_) {
            if (!mounted) return;

            setState(() {
              listening = false;
            });
          },
        );
      }

      if (!speechReady) {
        message(
          'التعرف على الصوت غير متاح على الهاتف حاليًا.',
        );
        return;
      }

      setState(() {
        listening = true;
        controller.clear();
      });

      await speech.listen(
        onResult: onSpeechResult,
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
      await stopListening();

      message(
        'حدث تعليق بسيط في التعرف على الصوت.',
      );
    }
  }

  void onSpeechResult(
    SpeechRecognitionResult result,
  ) {
    if (!mounted) return;

    final text =
        result.recognizedWords.trim();

    if (text.isNotEmpty) {
      controller.text = text;

      controller.selection =
          TextSelection.fromPosition(
        TextPosition(
          offset:
              controller.text.length,
        ),
      );
    }

    setState(() {});

    if (result.finalResult) {
      stopListening();

      if (text.isNotEmpty) {
        send();
      }
    }
  }

  Future<void> stopListening() async {
    try {
      await speech.stop();
    } catch (_) {}

    if (!mounted) return;

    setState(() {
      listening = false;
    });
  }

  String cleanSpeech(
    String value,
  ) {
    var text = value;

    text = text.replaceAll(
      RegExp(
        r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]',
        unicode: true,
      ),
      ' ',
    );

    text = text.replaceAll(
      RegExp(r'[*_#~`]+'),
      ' ',
    );

    text = text.replaceAll(
      RegExp(r'\s+'),
      ' ',
    );

    return text.trim();
  }

  Future<void> speak(
    String text,
  ) async {
    final clean =
        cleanSpeech(text);

    if (clean.isEmpty) return;

    try {
      await tts.stop();

      setState(() {
        speaking = true;
      });

      await tts.speak(clean);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        speaking = false;
      });
    }
  }

  Future<void> stopSpeaking() async {
    try {
      await tts.stop();
    } catch (_) {}

    if (!mounted) return;

    setState(() {
      speaking = false;
    });
  }

  Future<void> generateImage(
    String prompt,
  ) async {
    if (loading) return;

    setState(() {
      messages.add(
        _Message(
          user: true,
          text:
              'طلب إنشاء صورة:\n$prompt',
        ),
      );

      loading = true;
    });

    await _saveHistory();
    scrollBottom();

    final result =
        await AiService.generateImage(
      prompt,
    );

    if (!mounted) return;

    if (!result.isSuccess) {
      setState(() {
        messages.add(
          _Message(
            user: false,
            text:
                result.error ??
                    'تعذر إنشاء الصورة حاليًا.',
          ),
        );

        loading = false;
      });

      await _saveHistory();
      scrollBottom();
      return;
    }

    setState(() {
      messages.add(
        _Message(
          user: false,
          text:
              'تم إنشاء الصورة.',
          image: result.bytes,
        ),
      );

      loading = false;
    });

    await _saveHistory();
    scrollBottom();
  }

  Future<void> showImageGenerator() async {
    if (loading) return;

    final input =
        TextEditingController();

    final prompt =
        await showDialog<String>(
      context: context,
      builder: (dialog) {
        return AlertDialog(
          backgroundColor:
              const Color(0xFF151923),
          title: const Text(
            'إنشاء صورة',
            textDirection:
                TextDirection.rtl,
            style: TextStyle(
              color: Colors.white,
              fontWeight:
                  FontWeight.w900,
            ),
          ),
          content: TextField(
            controller: input,
            maxLines: 4,
            autofocus: true,
            textDirection:
                TextDirection.rtl,
            style:
                const TextStyle(
              color: Colors.white,
            ),
            decoration:
                InputDecoration(
              hintText:
                  'اكتب وصف الصورة...',
              hintTextDirection:
                  TextDirection.rtl,
              filled: true,
              fillColor:
                  const Color(
                0xFF202532,
              ),
              border:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(
                  16,
                ),
                borderSide:
                    BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                dialog,
              ),
              child:
                  const Text('إلغاء'),
            ),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    theme.primary,
                foregroundColor:
                    Colors.black,
              ),
              onPressed: () =>
                  Navigator.pop(
                dialog,
                input.text,
              ),
              child:
                  const Text('إنشاء'),
            ),
          ],
        );
      },
    );

    input.dispose();

    if (prompt == null ||
        prompt.trim().isEmpty) {
      return;
    }

    await generateImage(
      prompt.trim(),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          const Color(0xFF070A10),
      appBar: AppBar(
        elevation: 0,
        backgroundColor:
            const Color(0xFF0C1018),
        foregroundColor:
            Colors.white,
        centerTitle: true,
        titleSpacing: 8,
        title: Row(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            _MiniServiceIcon(
              icon: theme.icon,
              color: theme.primary,
            ),
            const SizedBox(width: 9),
            Flexible(
              child: Text(
                widget.serviceTitle ??
                    'صاحبي AI',
                overflow:
                    TextOverflow.ellipsis,
                style:
                    const TextStyle(
                  fontSize: 17,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip:
                speaking
                    ? 'إيقاف الصوت'
                    : 'الصوت',
            onPressed:
                speaking
                    ? stopSpeaking
                    : null,
            icon: Icon(
              speaking
                  ? Icons.volume_off_rounded
                  : Icons.volume_up_rounded,
              color:
                  theme.primary,
            ),
          ),
          PopupMenuButton<String>(
            color:
                const Color(0xFF171B25),
            onSelected: (value) {
              if (value ==
                  'clear') {
                _clearHistory();
              }
            },
            itemBuilder:
                (_) => [
              const PopupMenuItem(
                value: 'clear',
                child: Text(
                  'مسح المحادثة',
                  textDirection:
                      TextDirection.rtl,
                  style: TextStyle(
                    color:
                        Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: _ChatBackground(
              theme: theme,
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _ServiceHeader(
                  title:
                      widget.serviceTitle ??
                          'صاحبي AI',
                  icon: theme.icon,
                  theme: theme,
                ),
                Expanded(
                  child:
                      messages.isEmpty
                          ? _welcome()
                          : ListView.builder(
                              controller:
                                  scrollController,
                              physics:
                                  const BouncingScrollPhysics(),
                              padding:
                                  const EdgeInsets.fromLTRB(
                                10,
                                6,
                                10,
                                12,
                              ),
                              itemCount:
                                  messages.length,
                              itemBuilder:
                                  (_, index) {
                                final item =
                                    messages[index];

                                return _Bubble(
                                  item: item,
                                  theme: theme,
                                  speak: speak,
                                );
                              },
                            ),
                ),
                if (listening)
                  _ListeningBar(
                    theme: theme,
                  ),
                if (loading)
                  LinearProgressIndicator(
                    minHeight: 2,
                    backgroundColor:
                        Colors.white10,
                    valueColor:
                        AlwaysStoppedAnimation<
                            Color>(
                      theme.primary,
                    ),
                  ),
                _InputBar(
                  controller:
                      controller,
                  loading:
                      loading,
                  listening:
                      listening,
                  theme: theme,
                  onMedia:
                      _showMediaOptions,
                  onVoice:
                      toggleListening,
                  onGenerate:
                      showImageGenerator,
                  onSend:
                      send,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _welcome() {
    final title =
        widget.serviceTitle ??
            'صاحبي AI';

    return Center(
      child: SingleChildScrollView(
        padding:
            const EdgeInsets.all(22),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration:
                  BoxDecoration(
                shape:
                    BoxShape.circle,
                gradient:
                    SweepGradient(
                  colors: [
                    theme.primary,
                    theme.secondary,
                    theme.glow,
                    theme.primary,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        theme.glow.withOpacity(
                      0.22,
                    ),
                    blurRadius: 28,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  theme.icon,
                  color:
                      Colors.white,
                  size: 40,
                ),
              ),
            ),
            const SizedBox(height: 15),
            Text(
              'أنا صاحبي في $title',
              textDirection:
                  TextDirection.rtl,
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight:
                    FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'اتكلم، اكتب، ابعت صورة أو استخدم الكاميرا، وأنا هساعدك.',
              textDirection:
                  TextDirection.rtl,
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                color:
                    Colors.white60,
                fontSize: 13,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              alignment:
                  WrapAlignment.center,
              spacing: 7,
              runSpacing: 7,
              children: [
                _HintChip(
                  icon:
                      Icons.mic_rounded,
                  text: 'صوت',
                  color:
                      theme.primary,
                ),
                _HintChip(
                  icon:
                      Icons.camera_alt_rounded,
                  text: 'صورة',
                  color:
                      theme.secondary,
                ),
                _HintChip(
                  icon:
                      Icons.auto_awesome_rounded,
                  text: 'إنشاء صورة',
                  color:
                      theme.glow,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _clearHistory() async {
    if (loading) return;

    final confirm =
        await showDialog<bool>(
      context: context,
      builder: (dialog) {
        return AlertDialog(
          backgroundColor:
              const Color(0xFF171B25),
          title: const Text(
            'مسح المحادثة؟',
            textDirection:
                TextDirection.rtl,
            style: TextStyle(
              color: Colors.white,
              fontWeight:
                  FontWeight.w900,
            ),
          ),
          content: const Text(
            'سيتم حذف المحادثة المحفوظة لهذه الخدمة فقط.',
            textDirection:
                TextDirection.rtl,
            style: TextStyle(
              color: Colors.white70,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                dialog,
                false,
              ),
              child:
                  const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                dialog,
                true,
              ),
              child:
                  const Text('مسح'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      final prefs =
          await SharedPreferences.getInstance();

      await prefs.remove(
        storageKey,
      );
    } catch (_) {}

    if (!mounted) return;

    setState(() {
      messages.clear();
    });
  }

  void scrollBottom() {
    WidgetsBinding.instance
        .addPostFrameCallback(
      (_) {
        if (!scrollController
            .hasClients) {
          return;
        }

        scrollController.animateTo(
          scrollController
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

  void message(
    String text,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor:
              const Color(0xFF202633),
          content: Text(
            text,
            textDirection:
                TextDirection.rtl,
            style:
                const TextStyle(
              color: Colors.white,
            ),
          ),
        ),
      );
  }
}

class _ChatBackground
    extends StatelessWidget {
  final _ChatTheme theme;

  const _ChatBackground({
    required this.theme,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return DecoratedBox(
      decoration:
          BoxDecoration(
        gradient:
            LinearGradient(
          begin:
              Alignment.topCenter,
          end:
              Alignment.bottomCenter,
          colors: [
            const Color(0xFF080B12),
            Color.lerp(
                  const Color(0xFF080B12),
                  theme.glow,
                  0.055,
                ) ??
                const Color(
                  0xFF080B12,
                ),
            const Color(0xFF070A10),
          ],
        ),
      ),
    );
  }
}

class _ServiceHeader
    extends StatelessWidget {
  final String title;
  final IconData icon;
  final _ChatTheme theme;

  const _ServiceHeader({
    required this.title,
    required this.icon,
    required this.theme,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        12,
        7,
        12,
        5,
      ),
      child: Container(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        decoration:
            BoxDecoration(
          color:
              Colors.white.withOpacity(
            0.035,
          ),
          borderRadius:
              BorderRadius.circular(
            16,
          ),
          border:
              Border.all(
            color:
                Colors.white.withOpacity(
              0.07,
            ),
          ),
        ),
        child: Row(
          textDirection:
              TextDirection.rtl,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration:
                  BoxDecoration(
                shape:
                    BoxShape.circle,
                color:
                    theme.primary
                        .withOpacity(
                  0.13,
                ),
                border:
                    Border.all(
                  color:
                      theme.primary
                          .withOpacity(
                    0.35,
                  ),
                ),
              ),
              child: Icon(
                icon,
                size: 18,
                color:
                    theme.primary,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                title,
                textDirection:
                    TextDirection.rtl,
                overflow:
                    TextOverflow.ellipsis,
                style:
                    const TextStyle(
                  color: Colors.white,
                  fontWeight:
                      FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
            Text(
              'محادثة خاصة',
              textDirection:
                  TextDirection.rtl,
              style:
                  TextStyle(
                color:
                    theme.primary,
                fontSize: 11,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InputBar
    extends StatelessWidget {
  final TextEditingController controller;
  final bool loading;
  final bool listening;
  final _ChatTheme theme;
  final VoidCallback onMedia;
  final VoidCallback onVoice;
  final VoidCallback onGenerate;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.loading,
    required this.listening,
    required this.theme,
    required this.onMedia,
    required this.onVoice,
    required this.onGenerate,
    required this.onSend,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.fromLTRB(
        8,
        7,
        8,
        9,
      ),
      decoration:
          BoxDecoration(
        color:
            const Color(0xFF0C1017)
                .withOpacity(
          0.97,
        ),
        border:
            const Border(
          top:
              BorderSide(
            color:
                Color(0x1AFFFFFF),
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            textDirection:
                TextDirection.rtl,
            crossAxisAlignment:
                CrossAxisAlignment.end,
            children: [
              _ControlButton(
                icon:
                    Icons.add_rounded,
                color:
                    theme.primary,
                tooltip:
                    'كاميرا / صورة / فيديو',
                onPressed:
                    loading
                        ? null
                        : onMedia,
              ),
              const SizedBox(width: 5),
              _ControlButton(
                icon: listening
                    ? Icons.stop_rounded
                    : Icons.mic_rounded,
                color: listening
                    ? const Color(
                        0xFFFF5E67,
                      )
                    : theme.secondary,
                tooltip:
                    'التحدث بالصوت',
                onPressed:
                    loading
                        ? null
                        : onVoice,
              ),
              const SizedBox(width: 5),
              _ControlButton(
                icon:
                    Icons.auto_awesome_rounded,
                color:
                    theme.glow,
                tooltip:
                    'إنشاء صورة',
                onPressed:
                    loading
                        ? null
                        : onGenerate,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: TextField(
                  controller:
                      controller,
                  enabled:
                      !loading,
                  textDirection:
                      TextDirection.rtl,
                  textAlign:
                      TextAlign.right,
                  minLines: 1,
                  maxLines: 3,
                  style:
                      const TextStyle(
                    color:
                        Colors.white,
                    fontSize: 14,
                    height: 1.25,
                  ),
                  decoration:
                      InputDecoration(
                    hintText:
                        listening
                            ? 'سامعك...'
                            : 'اكتب لصاحبي...',
                    hintTextDirection:
                        TextDirection.rtl,
                    hintStyle:
                        const TextStyle(
                      color:
                          Colors.white38,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor:
                        const Color(
                      0xFF171C26,
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    border:
                        OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(
                        18,
                      ),
                      borderSide:
                          BorderSide.none,
                    ),
                    focusedBorder:
                        OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(
                        18,
                      ),
                      borderSide:
                          BorderSide(
                        color:
                            theme.primary
                                .withOpacity(
                          0.45,
                        ),
                      ),
                    ),
                  ),
                  onSubmitted:
                      (_) => onSend(),
                ),
              ),
              const SizedBox(width: 6),
              _SendButton(
                color:
                    theme.primary,
                onPressed:
                    loading
                        ? null
                        : onSend,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ControlButton
    extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onPressed;

  const _ControlButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 39,
        height: 39,
        decoration:
            BoxDecoration(
          shape:
              BoxShape.circle,
          color:
              color.withOpacity(
            0.10,
          ),
          border:
              Border.all(
            color:
                color.withOpacity(
              0.30,
            ),
          ),
        ),
        child: IconButton(
          padding:
              EdgeInsets.zero,
          onPressed:
              onPressed,
          icon: Icon(
            icon,
            size: 19,
            color:
                onPressed == null
                    ? Colors.white24
                    : color,
          ),
        ),
      ),
    );
  }
}

class _SendButton
    extends StatelessWidget {
  final Color color;
  final VoidCallback? onPressed;

  const _SendButton({
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width: 41,
      height: 41,
      decoration:
          BoxDecoration(
        shape:
            BoxShape.circle,
        gradient:
            LinearGradient(
          colors: [
            color,
            color.withOpacity(
              0.68,
            ),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color:
                color.withOpacity(
              0.20,
            ),
            blurRadius: 10,
          ),
        ],
      ),
      child: IconButton(
        padding:
            EdgeInsets.zero,
        onPressed:
            onPressed,
        icon:
            const Icon(
          Icons.arrow_upward_rounded,
          color:
              Colors.black,
          size: 21,
        ),
      ),
    );
  }
}

class _ListeningBar
    extends StatelessWidget {
  final _ChatTheme theme;

  const _ListeningBar({
    required this.theme,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      margin:
          const EdgeInsets.fromLTRB(
        12,
        0,
        12,
        5,
      ),
      padding:
          const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 7,
      ),
      decoration:
          BoxDecoration(
        color:
            theme.primary
                .withOpacity(
          0.09,
        ),
        borderRadius:
            BorderRadius.circular(
          14,
        ),
        border:
            Border.all(
          color:
              theme.primary
                  .withOpacity(
            0.25,
          ),
        ),
      ),
      child: Row(
        textDirection:
            TextDirection.rtl,
        children: [
          Icon(
            Icons.graphic_eq_rounded,
            color:
                theme.primary,
            size: 19,
          ),
          const SizedBox(width: 8),
          Text(
            'سامعك... اتكلم براحتك',
            textDirection:
                TextDirection.rtl,
            style:
                TextStyle(
              color:
                  theme.primary,
              fontSize: 12,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble
    extends StatelessWidget {
  final _Message item;
  final _ChatTheme theme;
  final Future<void> Function(String) speak;

  const _Bubble({
    required this.item,
    required this.theme,
    required this.speak,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final isUser =
        item.user;

    final bubbleColor =
        isUser
            ? theme.userBubble
            : theme.aiBubble;

    return Align(
      alignment: isUser
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        constraints:
            BoxConstraints(
          maxWidth:
              MediaQuery.of(context)
                      .size
                      .width *
                  0.86,
        ),
        margin:
            const EdgeInsets.only(
          bottom: 7,
        ),
        padding:
            const EdgeInsets.fromLTRB(
          9,
          7,
          9,
          7,
        ),
        decoration:
            BoxDecoration(
          color:
              bubbleColor,
          borderRadius:
              BorderRadius.only(
            topLeft:
                const Radius.circular(
              17,
            ),
            topRight:
                const Radius.circular(
              17,
            ),
            bottomLeft:
                Radius.circular(
              isUser ? 17 : 5,
            ),
            bottomRight:
                Radius.circular(
              isUser ? 5 : 17,
            ),
          ),
          border:
              Border.all(
            color:
                isUser
                    ? theme.primary
                        .withOpacity(
                      0.22,
                    )
                    : Colors.white
                        .withOpacity(
                      0.075,
                    ),
          ),
        ),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          textDirection:
              isUser
                  ? TextDirection.rtl
                  : TextDirection.ltr,
          children: [
            _AvatarIcon(
              user: isUser,
              theme: theme,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    isUser
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                children: [
                  Text(
                    isUser
                        ? 'أنت'
                        : 'صاحبي AI',
                    textDirection:
                        TextDirection.rtl,
                    style:
                        TextStyle(
                      color:
                          isUser
                              ? theme.primary
                              : theme.secondary,
                      fontSize: 10,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                  if (item.image !=
                      null)
                    Padding(
                      padding:
                          const EdgeInsets.only(
                        top: 5,
                      ),
                      child:
                          ClipRRect(
                        borderRadius:
                            BorderRadius.circular(
                          11,
                        ),
                        child:
                            Image.memory(
                          item.image!,
                          width: 260,
                          height: 185,
                          fit:
                              BoxFit.cover,
                        ),
                      ),
                    ),
                  if (item.video)
                    Padding(
                      padding:
                          const EdgeInsets.only(
                        top: 5,
                      ),
                      child:
                          Container(
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration:
                            BoxDecoration(
                          color:
                              Colors.black
                                  .withOpacity(
                            0.20,
                          ),
                          borderRadius:
                              BorderRadius.circular(
                            11,
                          ),
                        ),
                        child:
                            Row(
                          mainAxisSize:
                              MainAxisSize.min,
                          children: [
                            Icon(
                              Icons
                                  .play_circle_fill_rounded,
                              color:
                                  theme.primary,
                              size: 22,
                            ),
                            const SizedBox(
                                width: 6),
                            const Text(
                              'فيديو',
                              textDirection:
                                  TextDirection.rtl,
                              style:
                                  TextStyle(
                                color:
                                    Colors.white,
                                fontSize:
                                    12,
                                fontWeight:
                                    FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (item.text
                      .trim()
                      .isNotEmpty)
                    Padding(
                      padding:
                          const EdgeInsets.only(
                        top: 3,
                      ),
                      child:
                          SelectableText(
                        item.text,
                        textDirection:
                            TextDirection.rtl,
                        textAlign:
                            TextAlign.right,
                        style:
                            const TextStyle(
                          color:
                              Colors.white,
                          fontSize:
                              14,
                          height:
                              1.30,
                        ),
                      ),
                    ),
                  if (!isUser &&
                      item.text
                          .trim()
                          .isNotEmpty)
                    Align(
                      alignment:
                          Alignment.centerRight,
                      child:
                          InkWell(
                        borderRadius:
                            BorderRadius.circular(
                          20,
                        ),
                        onTap: () =>
                            speak(
                          item.text,
                        ),
                        child:
                            Padding(
                          padding:
                              const EdgeInsets
                                  .only(
                            top: 2,
                            right: 2,
                          ),
                          child:
                              Icon(
                            Icons
                                .volume_up_rounded,
                            color:
                                theme.primary,
                            size: 17,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarIcon
    extends StatelessWidget {
  final bool user;
  final _ChatTheme theme;

  const _AvatarIcon({
    required this.user,
    required this.theme,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width: 27,
      height: 27,
      decoration:
          BoxDecoration(
        shape:
            BoxShape.circle,
        gradient:
            LinearGradient(
          colors: user
              ? [
                  theme.secondary,
                  theme.primary,
                ]
              : [
                  theme.glow,
                  theme.secondary,
                ],
        ),
      ),
      child: Icon(
        user
            ? Icons.person_rounded
            : theme.icon,
        size: 16,
        color:
            Colors.white,
      ),
    );
  }
}

class _MiniServiceIcon
    extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _MiniServiceIcon({
    required this.icon,
    required this.color,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width: 30,
      height: 30,
      decoration:
          BoxDecoration(
        shape:
            BoxShape.circle,
        color:
            color.withOpacity(
          0.12,
        ),
        border:
            Border.all(
          color:
              color.withOpacity(
            0.35,
          ),
        ),
      ),
      child: Icon(
        icon,
        size: 16,
        color:
            color,
      ),
    );
  }
}

class _HintChip
    extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _HintChip({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration:
          BoxDecoration(
        color:
            color.withOpacity(
          0.08,
        ),
        borderRadius:
            BorderRadius.circular(
          30,
        ),
        border:
            Border.all(
          color:
              color.withOpacity(
            0.22,
          ),
        ),
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color:
                color,
          ),
          const SizedBox(width: 5),
          Text(
            text,
            textDirection:
                TextDirection.rtl,
            style:
                TextStyle(
              color:
                  Colors.white70,
              fontSize: 11,
              fontWeight:
                  FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaOption
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _MediaOption({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 8,
      ),
      decoration:
          BoxDecoration(
        color:
            Colors.white.withOpacity(
          0.035,
        ),
        borderRadius:
            BorderRadius.circular(
          15,
        ),
        border:
            Border.all(
          color:
              Colors.white.withOpacity(
            0.07,
          ),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading:
            CircleAvatar(
          backgroundColor:
              color.withOpacity(
            0.12,
          ),
          child: Icon(
            icon,
            color:
                color,
          ),
        ),
        title: Text(
          title,
          textDirection:
              TextDirection.rtl,
          style:
              const TextStyle(
            color:
                Colors.white,
            fontWeight:
                FontWeight.w800,
          ),
        ),
        trailing:
            const Icon(
          Icons.chevron_left_rounded,
          color:
              Colors.white38,
        ),
      ),
    );
  }
}
