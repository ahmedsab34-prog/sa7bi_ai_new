import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'config/app_config.dart';
import 'config/credits_config.dart';
import 'config/service_keys.dart';
import 'models/chat_message.dart';
import 'profile_screen.dart';
import 'services/ai_request_service.dart';
import 'services/chat_controller.dart';
import 'services/chat_image_service.dart';
import 'services/chat_media_service.dart';
import 'services/chat_voice_service.dart';
import 'services/credits_service.dart';
import 'services/image_intent_detector.dart';
import 'services/profile_service.dart';
import 'services/video_analysis_service.dart';
import 'widgets/audio_center_with_header.dart';
import 'widgets/app_header.dart';
import 'widgets/chat_screen_body.dart';

class ChatScreen extends StatefulWidget {
  final String? serviceTitle;
  final String? serviceContext;
  final String? serviceKey;

  /// True when this chat is embedded inside a parent portal that owns the header.
  final bool embedded;

  final VoidCallback? onProfileTap;
  final VoidCallback? onAudioTap;

  const ChatScreen({
    super.key,
    this.serviceTitle,
    this.serviceContext,
    this.serviceKey,
    this.embedded = false,
    this.onProfileTap,
    this.onAudioTap,
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
  final ImagePicker _imagePicker = ImagePicker();

  final TextEditingController _textController =
      TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  bool _initialized = false;
  bool _listening = false;
  bool _generatingImage = false;
  bool _sending = false;

  String get _serviceKey {
    final explicit = (widget.serviceKey ?? '').trim();

    if (explicit.isNotEmpty && ServiceKeys.isValid(explicit)) {
      return explicit;
    }

    return _inferServiceKey();
  }

  String _inferServiceKey() {
    final title = (widget.serviceTitle ?? '').trim();
    final contextValue = (widget.serviceContext ?? '').trim();
    final combined = '$title $contextValue'.toLowerCase();

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
    final value = (widget.serviceTitle ?? '').trim();

    if (value.isNotEmpty) {
      return value;
    }

    return _chatController.isKhalasana
        ? 'خلصانة AI'
        : 'صاحبي AI';
  }

  @override
  void initState() {
    super.initState();

    _chatController = ChatController(
      serviceKey: _serviceKey,
    );

    _profileService = ProfileService.instance;

    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await Future.wait([
        _profileService.initialize(),
        _creditsService.initialize(),
        _chatController.initialize(),
      ]);

      await _creditsService.refresh();

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
  // SHARED HEADER NAVIGATION
  // ============================================================

  void _openProfile() {
    final callback = widget.onProfileTap;

    if (callback != null) {
      callback();
      return;
    }

    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (profileContext) => ProfileScreen(
          onProfileTap: () {
            Navigator.of(profileContext).maybePop();
          },
          onAudio: _openAudioCenter,
        ),
      ),
    );
  }

  void _openAudioCenter() {
    final callback = widget.onAudioTap;

    if (callback != null) {
      callback();
      return;
    }

    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AudioCenterWithHeader(
          onProfileTap: _openProfile,
        ),
      ),
    );
  }

  // ============================================================
  // TEXT
  // ============================================================

  Future<void> _send() async {
    final text = _textController.text.trim();

    if (text.isEmpty ||
        _sending ||
        _chatController.isLoading ||
        _listening ||
        !_initialized) {
      return;
    }

    _sending = true;

    try {
      if (_looksLikeImageRequest(text)) {
        // امسح الطلب من خانة الكتابة قبل بدء إنشاء الصورة.
        _textController.clear();
        await _generateImage(text);
        return;
      }

      final history = _buildAiHistory();

      await _creditsService.initialize();

      final canAfford = await _creditsService.canAfford(
        CreditsConfig.textMessageCost,
      );

      if (!canAfford) {
        _showMessage('رصيدك من Credits غير كافٍ لهذه الرسالة.');
        return;
      }

      _textController.clear();

      await _chatController.addTextMessage(
        text: text,
        isUser: true,
      );

      _scrollToBottom();
      _chatController.setLoading(true);

      try {
        final reply = await AiRequestService.getResponse(
          prompt: text,
          serviceTitle: _title,
          serviceContext: widget.serviceContext,
          history: history,
        );

        if (mounted) {
          await _chatController.addTextMessage(
            text: reply,
            isUser: false,
          );
        }
      } on AiRequestException catch (error) {
        if (mounted) {
          await _chatController.addTextMessage(
            text: error.message,
            isUser: false,
          );
          if (_isSafeProviderFailure(error)) {
            _offerSafeTextRetry(text, history);
          }
        }
      } catch (_) {
        if (mounted) {
          await _chatController.addTextMessage(
            text: 'حصلت مشكلة مؤقتة في الاتصال بصاحبي. حاول مرة تانية.',
            isUser: false,
          );
        }
      } finally {
        _chatController.setLoading(false);
        await _creditsService.refresh();
        _scrollToBottom();
      }
    } finally {
      _sending = false;
      if (mounted) setState(() {});
    }
  }

  bool _isSafeProviderFailure(AiRequestException error) {
    return error.statusCode == 502 &&
        error.message ==
            'تعذر تشغيل الذكاء الاصطناعي حاليًا. حاول مرة أخرى.';
  }

  void _offerSafeTextRetry(
    String prompt,
    List<Map<String, String>> history,
  ) {
    if (!mounted) return;
    final savedHistory = history
        .map((item) => Map<String, String>.from(item))
        .toList(growable: false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF202633),
          duration: const Duration(seconds: 14),
          content: const Text(
            'فشل مزوّد الذكاء الاصطناعي. يمكنك إعادة المحاولة الآن.',
            textDirection: TextDirection.rtl,
            style: TextStyle(color: Colors.white),
          ),
          action: SnackBarAction(
            label: 'إعادة المحاولة',
            textColor: const Color(0xFFFFD76A),
            onPressed: () {
              _retryTextRequest(prompt, savedHistory);
            },
          ),
        ),
      );
  }

  Future<void> _retryTextRequest(
    String prompt,
    List<Map<String, String>> history,
  ) async {
    if (!mounted ||
        !_initialized ||
        _sending ||
        _generatingImage ||
        _chatController.isLoading) {
      return;
    }
    _sending = true;
    try {
      await _creditsService.initialize();
      final canAfford = await _creditsService.canAfford(
        CreditsConfig.textMessageCost,
      );
      if (!canAfford) {
        _showMessage('رصيدك من Credits غير كافٍ لإعادة المحاولة.');
        return;
      }
      _chatController.setLoading(true);
      try {
        final reply = await AiRequestService.getResponse(
          prompt: prompt,
          serviceTitle: _title,
          serviceContext: widget.serviceContext,
          history: history,
        );
        if (mounted) {
          await _chatController.addTextMessage(
            text: reply,
            isUser: false,
          );
        }
      } on AiRequestException catch (error) {
        if (mounted) {
          await _chatController.addTextMessage(
            text: error.message,
            isUser: false,
          );
          if (_isSafeProviderFailure(error)) {
            _offerSafeTextRetry(prompt, history);
          }
        }
      } catch (_) {
        if (mounted) {
          await _chatController.addTextMessage(
            text: 'حصلت مشكلة مؤقتة أثناء إعادة المحاولة.',
            isUser: false,
          );
        }
      } finally {
        _chatController.setLoading(false);
        await _creditsService.refresh();
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) {
        _showMessage('تعذر التحقق من الرصيد أو بدء إعادة المحاولة.');
      }
    } finally {
      _sending = false;
      if (mounted) setState(() {});
    }
  }

  List<Map<String, String>> _buildAiHistory() {
    return _chatController.messages
        .where(
          (message) =>
              message.text.trim().isNotEmpty &&
              message.image == null &&
              !message.isVideo,
        )
        .map(
          (message) => <String, String>{
            'role': message.isUser ? 'user' : 'assistant',
            'content': message.text.trim(),
          },
        )
        .toList();
  }

  // ============================================================
  // IMAGE PICKING
  // ============================================================

  Future<void> _takePhoto() async {
    if (_chatController.isLoading || _generatingImage) {
      return;
    }

    final permission = await Permission.camera.request();

    if (!permission.isGranted) {
      _showMessage('اسمح للتطبيق باستخدام الكاميرا.');
      return;
    }

    final bytes = await _mediaService.takePhoto();

    if (bytes == null || bytes.isEmpty) {
      _showMessage('تعذر التقاط الصورة.');
      return;
    }

    if (bytes.length >
        AppConfig.maximumImageSizeMb * 1024 * 1024) {
      _showMessage('الصورة كبيرة جدًا. الحد الأقصى هو 5 ميجابايت.');
      return;
    }

    await _handleSelectedImages([bytes]);
  }

  Future<void> _pickImage() async {
    if (_chatController.isLoading || _generatingImage) {
      return;
    }

    try {
      final files = await _imagePicker.pickMultiImage(
        imageQuality: 88,
        maxWidth: 2048,
        maxHeight: 2048,
        limit: 4,
      );

      if (files.isEmpty) return;

      final images = <Uint8List>[];
      final maximumImageBytes =
          AppConfig.maximumImageSizeMb * 1024 * 1024;

      for (final file in files.take(4)) {
        final bytes = await file.readAsBytes();

        if (bytes.isEmpty || bytes.length > maximumImageBytes) {
          continue;
        }

        images.add(bytes);
      }

      if (images.isEmpty) {
        _showMessage(
          'الصور المختارة أكبر من الحد المسموح أو تعذر قراءتها.',
        );
        return;
      }

      await _handleSelectedImages(images);
    } catch (_) {
      _showMessage('تعذر اختيار الصور.');
    }
  }

  Future<void> _handleSelectedImages(
    List<Uint8List> images,
  ) async {
    if (images.isEmpty ||
        _chatController.isLoading ||
        _generatingImage) {
      return;
    }

    final action = await _chooseImageAction(images.length);

    if (action == 'analyze') {
      await _analyzeImageCollection(images);
      return;
    }

    if (action == 'edit') {
      final prompt = await _showEditPrompt();

      if (prompt == null || prompt.trim().isEmpty) {
        return;
      }

      await _generateImage(
        prompt.trim(),
        images: images,
        isEditing: true,
      );
    }
  }

  Future<String?> _chooseImageAction(int count) async {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF151923),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  count > 1
                      ? 'اختر ماذا تريد أن أفعل بالصور ($count)'
                      : 'اختر ماذا تريد أن أفعل بالصورة',
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(
                    Icons.analytics_rounded,
                    color: Color(0xFFFFD76A),
                  ),
                  title: const Text(
                    'تحليل الصور',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: const Text(
                    'فهم الصور وقراءة النصوص والأشياء الظاهرة',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(color: Colors.white60),
                  ),
                  onTap: () => Navigator.pop(context, 'analyze'),
                ),
                const SizedBox(height: 6),
                ListTile(
                  leading: const Icon(
                    Icons.auto_fix_high_rounded,
                    color: Color(0xFFFFD76A),
                  ),
                  title: const Text(
                    'تعديل الصور بالذكاء الاصطناعي',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: const Text(
                    'غيّر أو أضف أو احذف أو حسّن محتوى الصور',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(color: Colors.white60),
                  ),
                  onTap: () => Navigator.pop(context, 'edit'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // IMAGE ANALYSIS
  // ============================================================

  Future<void> _analyzeImageCollection(
    List<Uint8List> images, {
    bool addUserMessage = true,
  }) async {
    if (images.isEmpty || _chatController.isLoading) {
      return;
    }

    final canAfford = await _creditsService.canAfford(
      CreditsConfig.imageAnalysisCost,
    );

    if (!canAfford) {
      _showMessage('رصيدك من Credits غير كافٍ لتحليل الصور.');
      return;
    }

    if (addUserMessage) {
      await _chatController.addImageMessage(
        text: images.length > 1
            ? 'أرسلت ${images.length} صور لتحليلها.'
            : 'أرسلت صورة لتحليلها.',
        isUser: true,
        image: images.first,
      );
    }

    _scrollToBottom();
    _chatController.setLoading(true);

    try {
      final reply = await AiRequestService.analyzeImages(
        images,
        serviceTitle: _title,
        serviceContext: widget.serviceContext,
        prompt:
            'حلل الصور المرفقة معًا بدقة. '
            'اذكر الأشياء المهمة والنصوص الواضحة. '
            'إذا كانت الصور مرتبطة ببعضها، اشرح العلاقة بينها. '
            'لا تخمن أي شيء غير ظاهر بوضوح.',
      );

      if (mounted) {
        await _chatController.addTextMessage(
          text: reply,
          isUser: false,
        );
      }
    } on AiRequestException catch (error) {
      if (mounted) {
        await _chatController.addTextMessage(
          text: error.message,
          isUser: false,
        );
        if (_isSafeProviderFailure(error)) {
          _offerSafeImageRetry(images);
        }
      }
    } catch (_) {
      if (mounted) {
        await _chatController.addTextMessage(
          text: 'تعذر تحليل الصور حاليًا.',
          isUser: false,
        );
      }
    } finally {
      _chatController.setLoading(false);
      await _creditsService.refresh();
