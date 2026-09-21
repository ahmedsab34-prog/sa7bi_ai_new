import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../config/service_keys.dart';
import '../models/chat_message.dart';
import 'chat_history_service.dart';
import 'chat_theme_service.dart';

/// مدير حالة المحادثة.
///
/// مسؤول عن:
/// - الرسائل الحالية.
/// - تحميل المحادثة المحفوظة.
/// - حفظ الرسائل.
/// - حذف محادثة الخدمة الحالية.
/// - تحديد الثيم الحالي.
/// - تغيير الثيم ديناميكيًا في خلصانة AI.
///
/// لا يتعامل مع واجهة Flutter مباشرة،
/// ولا يتعامل مع OpenAI أو الصوت أو الكاميرا.
/// هذه المسؤوليات تظل في الطبقات المتخصصة.
class ChatController extends ChangeNotifier {
  ChatController({
    required String serviceKey,
  }) : _serviceKey = _normalizeServiceKey(serviceKey) {
    _theme = ChatThemeService.forService(_serviceKey);
  }

  final String _serviceKey;

  final ChatHistoryService _history =
      ChatHistoryService.instance;

  final List<ChatMessage> _messages =
      <ChatMessage>[];

  ChatThemeData _theme;

  bool _isLoading = false;
  bool _isInitialized = false;

  String get serviceKey => _serviceKey;

  List<ChatMessage> get messages =>
      List<ChatMessage>.unmodifiable(_messages);

  ChatThemeData get theme => _theme;

  bool get isLoading => _isLoading;

  bool get isInitialized => _isInitialized;

  bool get isKhalasana =>
      _serviceKey == ServiceKeys.khalasana;

  /// تهيئة المحادثة وتحميل التاريخ المحفوظ.
  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    try {
      final saved =
          await _history.load(_serviceKey);

      _messages
        ..clear()
        ..addAll(
          saved.map(ChatMessage.fromJson),
        );

      if (_messages.isNotEmpty) {
        _updateThemeFromLatestMessage();
      } else {
        _theme =
            ChatThemeService.forService(
          _serviceKey,
        );
      }
    } catch (e) {
      debugPrint(
        'ChatController.initialize error: $e',
      );

      _messages.clear();

      _theme =
          ChatThemeService.forService(
        _serviceKey,
      );
    }

    _isInitialized = true;
    notifyListeners();
  }

  /// إضافة رسالة نصية.
  Future<void> addTextMessage({
    required String text,
    required bool isUser,
  }) async {
    final cleanText = text.trim();

    if (cleanText.isEmpty) {
      return;
    }

    final message = ChatMessage.text(
      isUser: isUser,
      text: cleanText,
    );

    _messages.add(message);

    _updateThemeForMessage(
      cleanText,
    );

    _trimMessages();

    notifyListeners();

    await _save();
  }

  /// إضافة رسالة صورة.
  Future<void> addImageMessage({
    required String text,
    required bool isUser,
    required Uint8List image,
  }) async {
    if (image.isEmpty) {
      return;
    }

    final cleanText = text.trim();

    final message = ChatMessage.image(
      isUser: isUser,
      text: cleanText,
      image: image,
    );

    _messages.add(message);

    if (cleanText.isNotEmpty) {
      _updateThemeForMessage(
        cleanText,
      );
    }

    _trimMessages();

    notifyListeners();

    await _save();
  }

  /// إضافة رسالة فيديو.
  ///
  /// يتم حفظها كرسالة فيديو حتى تظل موجودة
  /// في سجل المحادثة، بدون افتراض طريقة تحليل الفيديو.
  Future<void> addVideoMessage({
    required String text,
    required bool isUser,
  }) async {
    final cleanText = text.trim();

    if (cleanText.isEmpty) {
      return;
    }

    final message = ChatMessage.video(
      isUser: isUser,
      text: cleanText,
    );

    _messages.add(message);

    _updateThemeForMessage(
      cleanText,
    );

    _trimMessages();

    notifyListeners();

    await _save();
  }

  /// تغيير حالة تحميل رد الذكاء الاصطناعي.
  void setLoading(bool value) {
    if (_isLoading == value) {
      return;
    }

    _isLoading = value;
    notifyListeners();
  }

  /// تحديث الثيم يدويًا حسب النص.
  void updateThemeFromText(
    String text,
  ) {
    final nextTheme =
        ChatThemeService.detectFromText(
      text,
      serviceKey: _serviceKey,
    );

    if (_theme.id == nextTheme.id) {
      return;
    }

    _theme = nextTheme;
    notifyListeners();
  }

  /// حذف محادثة هذه الخدمة فقط.
  Future<bool> clearChat() async {
    final result =
        await _history.clear(_serviceKey);

    if (!result) {
      return false;
    }

    _messages.clear();

    _theme =
        ChatThemeService.forService(
      _serviceKey,
    );

    notifyListeners();

    return true;
  }

  /// عدد الرسائل الحالية.
  int get messageCount =>
      _messages.length;

  /// هل المحادثة فارغة؟
  bool get isEmpty =>
      _messages.isEmpty;

  void _updateThemeForMessage(
    String text,
  ) {
    final nextTheme =
        ChatThemeService.detectFromText(
      text,
      serviceKey: _serviceKey,
    );

    _theme = nextTheme;
  }

  void _updateThemeFromLatestMessage() {
    if (_messages.isEmpty) {
      _theme =
          ChatThemeService.forService(
        _serviceKey,
      );
      return;
    }

    final latest = _messages.last;

    if (latest.text.trim().isEmpty) {
      _theme =
          ChatThemeService.forService(
        _serviceKey,
      );
      return;
    }

    _theme =
        ChatThemeService.detectFromText(
      latest.text,
      serviceKey: _serviceKey,
    );
  }

  Future<void> _save() async {
    try {
      await _history.save(
        _serviceKey,
        _messages
            .map(
              (message) => message.toJson(),
            )
            .toList(),
      );
    } catch (e) {
      debugPrint(
        'ChatController.save error: $e',
      );
    }
  }

  void _trimMessages() {
    const maxMessages =
        ChatHistoryService.maxMessages;

    if (_messages.length <= maxMessages) {
      return;
    }

    _messages.removeRange(
      0,
      _messages.length - maxMessages,
    );
  }

  static String _normalizeServiceKey(
    String value,
  ) {
    final key = value.trim();

    if (ServiceKeys.isValid(key)) {
      return key;
    }

    return ServiceKeys.general;
  }
}
