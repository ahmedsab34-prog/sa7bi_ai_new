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

class _Message {
  final bool user;
  final String text;
  final Uint8List? image;

  const _Message({
    required this.user,
    required this.text,
    this.image,
  });
}

class _ChatScreenState
    extends State<ChatScreen> {
  final controller =
      TextEditingController();

  final scrollController =
      ScrollController();

  final picker =
      ImagePicker();

  final speech =
      stt.SpeechToText();

  final tts =
      FlutterTts();

  final messages =
      <_Message>[];

  bool loading = false;
  bool listening = false;
  bool speechReady = false;
  bool speaking = false;

  @override
  void initState() {
    super.initState();
    _setupTts();
  }

  Future<void> _setupTts() async {
    try {
      await tts.setLanguage('ar-EG');
      await tts.setSpeechRate(0.48);
      await tts.setVolume(1);
      await tts.setPitch(1);

      tts.setStartHandler(() {
        if (!mounted) return;
        setState(() => speaking = true);
      });

      tts.setCompletionHandler(() {
        if (!mounted) return;
        setState(() => speaking = false);
      });

      tts.setCancelHandler(() {
        if (!mounted) return;
        setState(() => speaking = false);
      });

      tts.setErrorHandler((_) {
        if (!mounted) return;
        setState(() => speaking = false);
      });
    } catch (_) {}
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

    if (
      text.isEmpty ||
      loading ||
      listening
    ) {
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
                  item.image == null,
            )
            .map(
              (item) => {
                'role':
                    item.user
                        ? 'user'
                        : 'assistant',
                'content':
                    item.text,
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

    scrollBottom();

    final reply =
        await AiService.getResponse(
      text,
      serviceContext:
          widget.serviceContext,
      history: history,
    );

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

    final imageWords = [
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

    final actionWords = [
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
        imageQuality: 60,
        maxWidth: 1280,
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
        imageQuality: 60,
        maxWidth: 1280,
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

      scrollBottom();

      final reply =
          await AiService.analyzeImage(
        image,
        prompt:
            'حلل الصورة بطريقة مفيدة. '
            'صف الأشياء الظاهرة بوضوح، '
            'واذكر أهم التفاصيل المفيدة. '
            'لا تخمن الأشياء غير الواضحة.',
        serviceContext:
            widget.serviceContext,
      );

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

      scrollBottom();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      message(
        'حدث خطأ أثناء تحليل الصورة.',
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

            if (
              status == 'done' ||
              status == 'notListening'
            ) {
              setState(
                () => listening = false,
              );
            }
          },
          onError: (_) {
            if (!mounted) return;

            setState(
              () => listening = false,
            );
          },
        );
      }

      if (!speechReady) {
        message(
          'التعرف على الصوت غير متاح.',
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

    setState(
      () => listening = false,
    );
  }

  String cleanSpeech(
    String value,
  ) {
    var text = value;

    // إزالة الرموز والإيموجي من الكلام المنطوق
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

      setState(
        () => speaking = true,
      );

      await tts.speak(clean);
    } catch (_) {
      if (!mounted) return;

      setState(
        () => speaking = false,
      );
    }
  }

  Future<void> stopSpeaking() async {
    try {
      await tts.stop();
    } catch (_) {}

    if (!mounted) return;

    setState(
      () => speaking = false,
    );
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
                'تعذر إنشاء الصورة.',
          ),
        );

        loading = false;
      });

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
              const Color(0xFF171A24),
          title: const Text(
            'إنشاء صورة',
            textDirection:
                TextDirection.rtl,
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
                const InputDecoration(
              hintText:
                  'اكتب وصف الصورة...',
              hintTextDirection:
                  TextDirection.rtl,
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

    if (
      prompt == null ||
      prompt.trim().isEmpty
    ) {
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
          const Color(0xFF070911),
      appBar: AppBar(
        backgroundColor:
            const Color(0xFF10131C),
        foregroundColor:
            Colors.white,
        centerTitle: true,
        title: Text(
          widget.serviceTitle ??
              'صاحبي AI',
          style:
              const TextStyle(
            fontWeight:
                FontWeight.w900,
          ),
        ),
        actions: [
          IconButton(
            onPressed:
                speaking
                    ? stopSpeaking
                    : null,
            icon: Icon(
              speaking
                  ? Icons.volume_off_rounded
                  : Icons.volume_up_rounded,
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
                  messages.isEmpty
                      ? _welcome()
                      : ListView.builder(
                          controller:
                              scrollController,
                          padding:
                              const EdgeInsets.all(
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
                              speak: speak,
                            );
                          },
                        ),
            ),

            if (listening)
              const Padding(
                padding:
                    EdgeInsets.all(8),
                child: Text(
                  'سامعك... اتكلم براحتك',
                  textDirection:
                      TextDirection.rtl,
                  style: TextStyle(
                    color:
                        Color(0xFF67E8F9),
                  ),
                ),
              ),

            if (loading)
              const LinearProgressIndicator(
                minHeight: 2,
              ),

            _input(),
          ],
        ),
      ),
    );
  }

  Widget _welcome() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(25),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration:
                  const BoxDecoration(
                shape:
                    BoxShape.circle,
                gradient:
                    SweepGradient(
                  colors: [
                    Color(0xFFFFD76A),
                    Color(0xFF7864FF),
                    Color(0xFF63E6FF),
                    Color(0xFFFFD76A),
                  ],
                ),
              ),
              child: const Center(
                child: Text(
                  'س',
                  style:
                      TextStyle(
                    color:
                        Colors.white,
                    fontSize: 45,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(
              height: 18,
            ),
            const Text(
              'قول يا صاحبي',
              textDirection:
                  TextDirection.rtl,
              style:
                  TextStyle(
                fontSize: 25,
                fontWeight:
                    FontWeight.w900,
              ),
            ),
            const SizedBox(
              height: 8,
            ),
            const Text(
              'اكتب أو اتكلم أو ابعت صورة أو اطلب إنشاء صورة.',
              textDirection:
                  TextDirection.rtl,
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                color:
                    Colors.white60,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _input() {
    return Container(
      padding:
          const EdgeInsets.fromLTRB(
        6,
        7,
        6,
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
                Color(0x22FFFFFF),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.end,
        children: [
          IconButton(
            onPressed:
                takePhoto,
            icon:
                const Icon(
              Icons.camera_alt_rounded,
              color:
                  Color(0xFFFFD76A),
            ),
          ),
          IconButton(
            onPressed:
                pickImage,
            icon:
                const Icon(
              Icons.photo_library_rounded,
              color:
                  Color(0xFFB794F4),
            ),
          ),
          IconButton(
            onPressed:
                showImageGenerator,
            icon:
                const Icon(
              Icons.auto_awesome_rounded,
              color:
                  Color(0xFF67E8F9),
            ),
          ),
          IconButton(
            onPressed:
                toggleListening,
            icon: Icon(
              listening
                  ? Icons.stop_rounded
                  : Icons.mic_rounded,
              color:
                  listening
                      ? const Color(
                          0xFFFF6B6B,
                        )
                      : const Color(
                          0xFF67E8F9,
                        ),
            ),
          ),
          Expanded(
            child: TextField(
              controller:
                  controller,
              enabled:
                  !loading,
              maxLines: 4,
              textDirection:
                  TextDirection.rtl,
              style:
                  const TextStyle(
                color:
                    Colors.white,
              ),
              decoration:
                  InputDecoration(
                hintText:
                    listening
                        ? 'جاري الاستماع...'
                        : 'اكتب لصاحبي...',
                hintTextDirection:
                    TextDirection.rtl,
                filled: true,
                fillColor:
                    const Color(
                  0xFF171A24,
                ),
                border:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(
                    20,
                  ),
                  borderSide:
                      BorderSide.none,
                ),
              ),
              onSubmitted: (_) =>
                  send(),
            ),
          ),
          IconButton(
            onPressed:
                send,
            icon:
                const Icon(
              Icons.send_rounded,
              color:
                  Color(0xFFFFD76A),
            ),
          ),
        ],
      ),
    );
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
          content: Text(
            text,
            textDirection:
                TextDirection.rtl,
          ),
        ),
      );
  }
}

class _Bubble
    extends StatelessWidget {
  final _Message item;
  final Future<void> Function(
    String,
  ) speak;

  const _Bubble({
    required this.item,
    required this.speak,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Align(
      alignment:
          item.user
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
            const EdgeInsets.all(13),
        decoration:
            BoxDecoration(
          gradient:
              LinearGradient(
            colors: item.user
                ? const [
                    Color(0xFF7546A8),
                    Color(0xFF38215E),
                  ]
                : const [
                    Color(0xFF1F2B39),
                    Color(0xFF121821),
                  ],
          ),
          borderRadius:
              BorderRadius.circular(
            20,
          ),
          border:
              Border.all(
            color: item.user
                ? const Color(
                    0x665E3D88,
                  )
                : const Color(
                    0x3348D7FF,
                  ),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              item.user
                  ? 'أنت'
                  : 'صاحبي AI',
              textDirection:
                  TextDirection.rtl,
              style:
                  TextStyle(
                color: item.user
                    ? const Color(
                        0xFFE9D5FF,
                      )
                    : const Color(
                        0xFF8BE9FD,
                      ),
                fontWeight:
                    FontWeight.w900,
              ),
            ),
            if (item.image != null)
              Padding(
                padding:
                    const EdgeInsets.only(
                  top: 8,
                ),
                child:
                    ClipRRect(
                  borderRadius:
                      BorderRadius.circular(
                    15,
                  ),
                  child:
                      Image.memory(
                    item.image!,
                    width: 330,
                    height: 230,
                    fit:
                        BoxFit.cover,
                  ),
                ),
              ),
            if (item.text.isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.only(
                  top: 8,
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
                    fontSize: 16,
                    height: 1.55,
                  ),
                ),
              ),
            if (
              !item.user &&
              item.text.trim().isNotEmpty
            )
              IconButton(
                onPressed:
                    () => speak(
                  item.text,
                ),
                icon:
                    const Icon(
                  Icons.volume_up_rounded,
                  color:
                      Color(0xFFFFD76A),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
