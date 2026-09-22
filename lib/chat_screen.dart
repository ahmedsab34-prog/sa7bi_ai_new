import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'config/credits_config.dart';
import 'config/service_keys.dart';
import 'models/chat_message.dart';
import 'services/ai_request_service.dart';
import 'services/chat_controller.dart';
import 'services/chat_image_service.dart';
import 'services/chat_media_service.dart';
import 'services/chat_voice_service.dart';
import 'services/credits_service.dart';
import 'services/profile_service.dart';
import 'widgets/chat_screen_body.dart';

/// شاشة المحادثة الرئيسية.
///
/// هذه الشاشة Orchestrator فقط:
/// - ChatController: الرسائل + التاريخ + الثيم.
/// - ProfileService: اسم وصورة المستخدم.
/// - ChatMediaService: الكاميرا والصور والفيديو.
/// - ChatVoiceService: الكلام وتحويل النص لصوت.
/// - ChatImageService: توليد الصور + Credits.
/// - AiRequestService: طلبات النص وتحليل الصور.
/// - ChatScreenBody: واجهة الشات.
class ChatScreen extends StatefulWidget {
  final String? serviceTitle;
  final String? serviceContext;

  /// المفتاح الصريح للخدمة.
  ///
  /// استخدامه أفضل من محاولة معرفة الخدمة من العنوان
  /// أو من نص الـ context.
  final String? serviceKey;

  const ChatScreen({
    super.key,
    this.serviceTitle,
    this.serviceContext,
    this.serviceKey,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final ChatController _chatController;
  late final ProfileService _profileService;

  final ChatMediaService _mediaService = ChatMediaService();

  final ChatVoiceService _voiceService = ChatVoiceService();

  final ChatImageService _imageService = ChatImageService();

  final CreditsService _creditsService = CreditsService.instance;

  final TextEditingController _textController =
      TextEditingController();

  final FocusNode _focusNode = FocusNode();

  final ScrollController _scrollController =
      ScrollController();

  bool _initialized = false;
  bool _listening = false;
  bool _generatingImage = false;

  // ============================================================
  // SERVICE KEY
  // ============================================================

  String get _serviceKey {
    final explicitKey =
        (widget.serviceKey ?? '').trim();

    if (explicitKey.isNotEmpty &&
        ServiceKeys.isValid(explicitKey)) {
      return explicitKey;
    }

    return _inferServiceKey();
  }

  String _inferServiceKey() {
    final title =
        (widget.serviceTitle ?? '').trim();

    final contextValue =
        (widget.serviceContext ?? '').trim();

    final combined =
        '$title $contextValue'.toLowerCase();

    if (combined.contains('خلصانة') ||
        combined.contains('khalasana')) {
      return ServiceKeys.khalasana;
    }

    if (combined.contains('المطبخ') ||
        combined.contains('طبخ') ||
        combined.contains('kitchen')) {
      return ServiceKeys.kitchen;
    }

    if (combined.contains('التجارة') ||
        combined.contains('تجارة') ||
        combined.contains('merchant')) {
      return ServiceKeys.merchant;
    }

    if (combined.contains('الصيدلية') ||
        combined.contains('صيدلية') ||
        combined.contains('pharmacy')) {
      return ServiceKeys.pharmacy;
    }

    if (combined.contains('الحرف') ||
        combined.contains('حرفيين') ||
        combined.contains('tradesperson')) {
      return ServiceKeys.tradesperson;
    }

    if (combined.contains('العبادة') ||
        combined.contains('عبادة') ||
        combined.contains('worship')) {
      return ServiceKeys.worship;
    }

    if (combined.contains('التسوق') ||
        combined.contains('تسوق') ||
        combined.contains('shopping')) {
      return ServiceKeys.shopping;
    }

    if (combined.contains('التواصل') ||
        combined.contains('تواصل') ||
        combined.contains('social')) {
      return ServiceKeys.social;
    }

    if (combined.contains('فضفضة') ||
        combined.contains('venting')) {
      return ServiceKeys.venting;
    }

    if (combined.contains('الهوايات') ||
        combined.contains('الرياضة') ||
        combined.contains('هوايات') ||
        combined.contains('hobbies') ||
        combined.contains('sports')) {
      return ServiceKeys.hobbiesSports;
    }

    if (combined.contains('البودكاست') ||
        combined.contains('بودكاست') ||
        combined.contains('podcast')) {
      return ServiceKeys.podcasts;
    }

    return ServiceKeys.general;
  }

  String get _title {
    final value =
        (widget.serviceTitle ?? '').trim();

    if (value.isEmpty) {
      return _chatController.isKhalasana
          ? 'خلصانة AI'
          : 'صاحبي AI';
    }

    return value;
  }

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _chatController = ChatController(
      serviceKey: _serviceKey,
    );

    _profileService =
        ProfileService.instance;

    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _profileService.initialize();

      await _creditsService.initialize();

      await _chatController.initialize();

      await _voiceService.initializeTts();

      if (!mounted) return;

      setState(() {
        _initialized = true;
      });

      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _initialized = true;
      });
    }
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();

    _voiceService.dispose();
    _chatController.dispose();

    super.dispose();
  }

  // ============================================================
  // TEXT CHAT
  // ============================================================

  Future<void> _send() async {
    final text =
        _textController.text.trim();

    if (text.isEmpty ||
        _chatController.isLoading ||
        _listening ||
        !_initialized) {
      return;
    }

    _textController.clear();

    // طلب إنشاء صورة من الرسالة.
    if (_looksLikeImageRequest(text)) {
      await _generateImage(text);
      return;
    }

    final history =
        _buildAiHistory();

    final textCost =
        CreditsConfig.textMessageCost;

    await _creditsService.initialize();

    // ----------------------------------------------------------
    // CHECK CREDIT
    // ----------------------------------------------------------

    if (textCost > 0) {
      final canAfford =
          await _creditsService.canAfford(
        textCost,
      );

      if (!canAfford) {
        _showMessage(
          'رصيدك من Credits غير كافٍ لهذه الرسالة.',
        );
        return;
      }

      final spent =
          await _creditsService.spend(
        textCost,
      );

      if (!spent) {
        _showMessage(
          'تعذر استخدام Credits حاليًا.',
        );
        return;
      }
    }

    // ----------------------------------------------------------
    // SAVE USER MESSAGE
    // ----------------------------------------------------------

    await _chatController.addTextMessage(
      text: text,
      isUser: true,
    );

    _scrollToBottom();

    _chatController.setLoading(true);

    // ----------------------------------------------------------
    // AI REQUEST
    // ----------------------------------------------------------

    try {
      final reply =
          await AiRequestService.getResponse(
        prompt: text,
        serviceContext:
            widget.serviceContext,
        history: history,
      );

      if (!mounted) return;

      await _chatController.addTextMessage(
        text: reply,
        isUser: false,
      );
    } on AiRequestException catch (error) {
      if (textCost > 0) {
        await _creditsService.add(
          textCost,
        );
      }

      if (!mounted) return;

      await _chatController.addTextMessage(
        text: error.message,
        isUser: false,
      );
    } catch (_) {
      if (textCost > 0) {
        await _creditsService.add(
          textCost,
        );
      }

      if (!mounted) return;

      await _chatController.addTextMessage(
        text:
            'حصلت مشكلة مؤقتة في الاتصال بصاحبي. حاول مرة تانية.',
        isUser: false,
      );
    } finally {
      _chatController.setLoading(false);

      _scrollToBottom();
    }
  }

  // ============================================================
  // AI HISTORY
  // ============================================================

  List<Map<String, String>>
      _buildAiHistory() {
    return _chatController.messages
        .where(
          (message) =>
              message.text.trim().isNotEmpty &&
              message.image == null &&
              !message.isVideo,
        )
        .map(
          (message) =>
              <String, String>{
            'role': message.isUser
                ? 'user'
                : 'assistant',
            'content':
                message.text.trim(),
          },
        )
        .toList();
  }

  // ============================================================
  // CAMERA
  // ============================================================

  Future<void> _takePhoto() async {
    if (_chatController.isLoading) {
      return;
    }

    final permission =
        await Permission.camera.request();

    if (!permission.isGranted) {
      _showMessage(
        'اسمح للتطبيق باستخدام الكاميرا.',
      );
      return;
    }

    final bytes =
        await _mediaService.takePhoto();

    if (bytes == null ||
        bytes.isEmpty) {
      _showMessage(
        'تعذر التقاط الصورة.',
      );
      return;
    }

    await _analyzeImageBytes(
      bytes,
    );
  }

  // ============================================================
  // PICK IMAGE / GALLERY
  // ============================================================

  Future<void> _pickImage() async {
    if (_chatController.isLoading) {
      return;
    }

    final bytes =
        await _mediaService.pickPhoto();

    if (bytes == null ||
        bytes.isEmpty) {
      return;
    }

    await _analyzeImageBytes(
      bytes,
    );
  }

  // ============================================================
  // IMAGE ANALYSIS
  // ============================================================

  Future<void> _analyzeImageBytes(
    Uint8List bytes,
  ) async {
    if (_chatController.isLoading ||
        bytes.isEmpty) {
      return;
    }

    final cost =
        CreditsConfig.imageAnalysisCost;

    await _creditsService.initialize();

    if (cost > 0) {
      final canAfford =
          await _creditsService.canAfford(
        cost,
      );

      if (!canAfford) {
        _showMessage(
          'رصيدك من Credits غير كافٍ لتحليل الصورة.',
        );
        return;
      }

      final spent =
          await _creditsService.spend(
        cost,
      );

      if (!spent) {
        _showMessage(
          'تعذر استخدام Credits لتحليل الصورة.',
        );
        return;
      }
    }

    await _chatController.addImageMessage(
      text:
          'أرسلت صورة لتحليلها.',
      isUser: true,
      image: bytes,
    );

    _scrollToBottom();

    _chatController.setLoading(true);

    try {
      final reply =
          await _analyzeBytesWithAi(
        bytes,
      );

      if (!mounted) return;

      await _chatController.addTextMessage(
        text: reply,
        isUser: false,
      );
    } on AiRequestException catch (error) {
      if (cost > 0) {
        await _creditsService.add(
          cost,
        );
      }

      if (!mounted) return;

      await _chatController.addTextMessage(
        text: error.message,
        isUser: false,
      );
    } catch (_) {
      if (cost > 0) {
        await _creditsService.add(
          cost,
        );
      }

      if (!mounted) return;

      await _chatController.addTextMessage(
        text:
            'تعذر تحليل الصورة حاليًا. حاول مرة أخرى.',
        isUser: false,
      );
    } finally {
      _chatController.setLoading(false);

      _scrollToBottom();
    }
  }

  Future<String> _analyzeBytesWithAi(
    Uint8List bytes,
  ) async {
    if (bytes.isEmpty) {
      throw const AiRequestException(
        'الصورة فارغة.',
      );
    }

    final file =
        XFile.fromData(
      bytes,
      name: 'chat_image.jpg',
      mimeType: 'image/jpeg',
    );

    return AiRequestService.analyzeImage(
      file: file,
      serviceContext:
          widget.serviceContext,
      prompt:
          'حلل الصورة المرسلة بدقة وباختصار. '
          'اذكر أهم الأشياء الظاهرة فيها، '
          'ولو الصورة تحتوي على نص فاقرأه وفسره قدر الإمكان. '
          'إذا كان هناك شيء غير واضح، قل ذلك بدل التخمين.',
    );
  }

  // ============================================================
  // VIDEO
  // ============================================================

  Future<void> _pickVideo() async {
    if (_chatController.isLoading) {
      return;
    }

    final video =
        await _mediaService.pickVideo();

    if (video == null) {
      return;
    }

    final fileName =
        video.name.trim().isEmpty
            ? 'فيديو'
            : video.name;

    await _chatController.addVideoMessage(
      text:
          'أرسلت فيديو: $fileName\n\n'
          'تم استلام الفيديو. تحليل محتوى الفيديو يحتاج '
          'طبقة رؤية فيديو مخصصة، ولن ندّعي أن التحليل تم '
          'وهو غير متاح بعد.',
      isUser: true,
    );

    _scrollToBottom();
  }

  // ============================================================
  // SPEECH TO TEXT
  // ============================================================

  Future<void> _toggleSpeechToText() async {
    if (_chatController.isLoading) {
      return;
    }

    if (_listening) {
      await _voiceService.stopListening();

      if (!mounted) return;

      setState(() {
        _listening = false;
      });

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

    final started =
        await _voiceService.startListening(
      onResult: (
        String text,
        bool isFinal,
      ) {
        if (!mounted) return;

        if (text.trim().isNotEmpty) {
          _textController.text =
              text.trim();

          _textController.selection =
              TextSelection.fromPosition(
            TextPosition(
              offset:
                  _textController.text.length,
            ),
          );
        }

        if (isFinal) {
          setState(() {
            _listening = false;
          });

          if (_textController.text
              .trim()
              .isNotEmpty) {
            _send();
          }
        } else {
          setState(() {
            _listening = true;
          });
        }
      },
      localeId: 'ar-EG',
    );

    if (!mounted) return;

    if (!started) {
      setState(() {
        _listening = false;
      });

      _showMessage(
        'التعرف على الصوت غير متاح على الهاتف حاليًا.',
      );

      return;
    }

    setState(() {
      _listening = true;
    });
  }

  // ============================================================
  // TEXT TO SPEECH
  // ============================================================

  Future<void> _voiceAction() async {
    ChatMessage? latestAi;

    for (final message
        in _chatController.messages.reversed) {
      if (!message.isUser &&
          message.text.trim().isNotEmpty) {
        latestAi = message;
        break;
      }
    }

    if (latestAi == null) {
      _showMessage(
        'لسه مفيش رد من صاحبي عشان يتقرأ.',
      );
      return;
    }

    if (_voiceService.isSpeaking) {
      await _voiceService.stopSpeaking();
      return;
    }

    final cleaned =
        _cleanSpeech(
      latestAi.text,
    );

    await _voiceService.speak(
      cleaned,
      language: 'ar-EG',
      rate: 0.48,
      pitch: 1.0,
      volume: 1.0,
    );

    if (mounted) {
      setState(() {});
    }
  }

  // ============================================================
  // IMAGE GENERATION
  // ============================================================

  Future<void> _generateImage(
    String prompt,
  ) async {
    if (_chatController.isLoading ||
        _generatingImage) {
      return;
    }

    setState(() {
      _generatingImage = true;
    });

    await _chatController.addTextMessage(
      text:
          'طلب إنشاء صورة:\n$prompt',
      isUser: true,
    );

    _scrollToBottom();

    _chatController.setLoading(true);

    final result =
        await _imageService.generate(
      prompt,
    );

    if (!mounted) return;

    if (!result.isSuccess) {
      await _chatController.addTextMessage(
        text:
            result.error ??
                'تعذر إنشاء الصورة حاليًا.',
        isUser: false,
      );

      _chatController.setLoading(false);

      setState(() {
        _generatingImage = false;
      });

      _scrollToBottom();
      return;
    }

    if (result.bytes != null &&
        result.bytes!.isNotEmpty) {
      await _chatController.addImageMessage(
        text:
            'تم إنشاء الصورة.',
        isUser: false,
        image: result.bytes!,
      );
    } else if (result.imageUrl != null &&
        result.imageUrl!.trim().isNotEmpty) {
      await _chatController.addTextMessage(
        text:
            'تم إنشاء الصورة:\n${result.imageUrl}',
        isUser: false,
      );
    } else {
      await _chatController.addTextMessage(
        text:
            'تم إنشاء الصورة.',
        isUser: false,
      );
    }

    _chatController.setLoading(false);

    setState(() {
      _generatingImage = false;
    });

    _scrollToBottom();
  }

  // ============================================================
  // IMAGE GENERATOR DIALOG
  // ============================================================

  Future<void> _showImageGenerator() async {
    if (_chatController.isLoading ||
        _generatingImage) {
      return;
    }

    final promptController =
        TextEditingController();

    final prompt =
        await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor:
              const Color(0xFF151923),
          title: Text(
            _chatController.isKhalasana
                ? 'خلصانة AI — إنشاء صورة'
                : 'إنشاء صورة',
            textDirection:
                TextDirection.rtl,
            style: const TextStyle(
              color: Colors.white,
              fontWeight:
                  FontWeight.w900,
            ),
          ),
          content: TextField(
            controller:
                promptController,
            maxLines: 5,
            autofocus: true,
            textDirection:
                TextDirection.rtl,
            textAlign:
                TextAlign.right,
            style: const TextStyle(
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
                  const Color(0xFF202532),
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
                dialogContext,
              ),
              child:
                  const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(
                dialogContext,
                promptController.text,
              ),
              child:
                  const Text('إنشاء'),
            ),
          ],
        );
      },
    );

    promptController.dispose();

    if (prompt == null ||
        prompt.trim().isEmpty) {
      return;
    }

    await _generateImage(
      prompt.trim(),
    );
  }

  // ============================================================
  // CLEAR CHAT
  // ============================================================

  Future<void> _clearChat() async {
    if (_chatController.isLoading) {
      return;
    }

    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
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
                dialogContext,
                false,
              ),
              child:
                  const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                dialogContext,
                true,
              ),
              child:
                  const Text('مسح'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await _chatController.clearChat();

    if (!mounted) return;

    _showMessage(
      'تم مسح محادثة $_title فقط.',
    );
  }

  // ============================================================
  // SCROLL
  // ============================================================

  void _scrollToBottom() {
    WidgetsBinding.instance
        .addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      final max =
          _scrollController
              .position
              .maxScrollExtent;

      _scrollController.animateTo(
        max,
        duration:
            const Duration(
          milliseconds: 220,
        ),
        curve:
            Curves.easeOut,
      );
    });
  }

  // ============================================================
  // IMAGE REQUEST DETECTION
  // ============================================================

  bool _looksLikeImageRequest(
    String text,
  ) {
    final value = text
        .toLowerCase()
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا');

    const imageWords = <String>[
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

    const actionWords = <String>[
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

  // ============================================================
  // SPEECH CLEANER
  // ============================================================

  String _cleanSpeech(
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

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
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
            style: const TextStyle(
              color: Colors.white,
            ),
          ),
        ),
      );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    if (!_initialized) {
      return const Scaffold(
        backgroundColor:
            Color(0xFF070A10),
        body: Center(
          child:
              CircularProgressIndicator(
            color:
                Color(0xFFFFD76A),
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation:
          _chatController,
      builder: (
        context,
        _,
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
            title: Text(
              _title,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  const TextStyle(
                fontSize: 17,
                fontWeight:
                    FontWeight.w900,
              ),
            ),
            actions: [
              if (_voiceService
                  .isSpeaking)
                IconButton(
                  tooltip:
                      'إيقاف الصوت',
                  onPressed:
                      () async {
                    await _voiceService
                        .stopSpeaking();

                    if (mounted) {
                      setState(() {});
                    }
                  },
                  icon:
                      const Icon(
                    Icons
                        .volume_off_rounded,
                    color:
                        Color(
                      0xFFFFD76A,
                    ),
                  ),
                ),
            ],
          ),
          body:
              ChatScreenBody(
            chatController:
                _chatController,
            profileService:
                _profileService,
            textController:
                _textController,
            focusNode:
                _focusNode,
            scrollController:
                _scrollController,
            title:
                _title,
            topic:
                _chatController
                        .isKhalasana
                    ? 'محادثة تتغير حسب الموضوع'
                    : widget
                        .serviceContext,
            enabled:
                !_chatController
                    .isLoading,
            isListening:
                _listening,
            isGeneratingImage:
                _generatingImage,
            onSend:
                _send,
            onCamera:
                _takePhoto,
            onGallery:
                _pickImage,
            onVideo:
                _pickVideo,
            onVoice:
                _voiceAction,
            onText: () {
              _focusNode
                  .requestFocus();
            },
            onSpeechToText:
                _toggleSpeechToText,
            onImageGeneration:
                _showImageGenerator,
            onClear:
                _clearChat,
          ),
        );
      },
    );
  }
}
