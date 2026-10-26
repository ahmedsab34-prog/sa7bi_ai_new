
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../config/service_keys.dart';
import '../models/chat_message.dart';
import 'chat_history_service.dart';
import 'chat_theme_service.dart';

/// مدير حالة المحادثة.
class ChatController extends ChangeNotifier {
  ChatController({
    required String serviceKey,
  }) : _serviceKey = _normalizeServiceKey(serviceKey) {
    _theme = ChatThemeService.forService(_serviceKey);
  }

  final String _serviceKey;

  final ChatHistoryService _history =
      ChatHistoryService.instance;

  final List<ChatMessage> _messages = <ChatMessage>[];

  late ChatThemeData _theme;

  bool _isLoading = false;
  bool _isInitialized = false;
  bool _disposed = false;

  // مشاركة نفس عملية تحميل سجل المحادثة عند الاستدعاء المتزامن.
  Future<void>? _initializationFuture;

  String get serviceKey => _serviceKey;

  List<ChatMessage> get messages =>
      List<ChatMessage>.unmodifiable(_messages);

  ChatThemeData get theme => _theme;

  bool get isLoading => _isLoading;

  bool get isInitialized => _isInitialized;

  bool get isKhalasana =>
      _serviceKey == ServiceKeys.khalasana;

  Future<void> initialize() {
    if (_isInitialized) {
      return Future<void>.value();
    }

    final pending = _initializationFuture;
    if (pending != null) {
      return pending;
    }

    final future = _initializeInternal();
    _initializationFuture = future;
    return future;
  }

  Future<void> _initializeInternal() async {
    try {
      final saved = await _history.load(_serviceKey);

      if (_disposed) return;

      _messages
        ..clear()
        ..addAll(saved.map(ChatMessage.fromJson));

      if (_messages.isNotEmpty) {
        _updateThemeFromLatestMessage();
      } else {
        _theme = ChatThemeService.forService(_serviceKey);
      }

      _isInitialized = true;
      _notifyIfAlive();
    } catch (error, stackTrace) {
      debugPrint('ChatController.initialize error: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (_disposed) return;

      _messages.clear();
      _theme = ChatThemeService.forService(_serviceKey);

      // نسمح باستدعاء initialize لاحقًا بدل اعتبار
      // التحميل الفاشل ناجحًا.
      _isInitialized = false;
      rethrow;
    } finally {
      _initializationFuture = null;
    }
  }

  Future<void> addTextMessage({
    required String text,
    required bool isUser,
  }) async {
    if (_disposed) return;

    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    final message = ChatMessage.text(
      isUser: isUser,
      text: cleanText,
    );

    _messages.add(message);
    _updateThemeForMessage(cleanText);
    _trimMessages();

    _notifyIfAlive();
    await _save();
  }

  Future<void> addImageMessage({
    required String text,
    required bool isUser,
    required Uint8List image,
  }) async {
    if (_disposed || image.isEmpty) return;

    final cleanText = text.trim();

    final message = ChatMessage.image(
      isUser: isUser,
      text: cleanText,
      image: image,
    );

    _messages.add(message);

    if (cleanText.isNotEmpty) {
      _updateThemeForMessage(cleanText);
    }

    _trimMessages();

    _notifyIfAlive();
    await _save();
  }

  Future<void> addVideoMessage({
    required String text,
    required bool isUser,
  }) async {
    if (_disposed) return;

    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    final message = ChatMessage.video(
      isUser: isUser,
      text: cleanText,
    );

    _messages.add(message);
    _updateThemeForMessage(cleanText);
    _trimMessages();

    _notifyIfAlive();
    await _save();
  }

  void setLoading(bool value) {
    if (_disposed || _isLoading == value) {
      return;
    }

    _isLoading = value;
    _notifyIfAlive();
  }

  void updateThemeFromText(String text) {
    if (_disposed) return;

    final nextTheme = ChatThemeService.detectFromText(
      text,
      serviceKey: _serviceKey,
    );

    if (_theme.id == nextTheme.id) {
      return;
    }

    _theme = nextTheme;
    _notifyIfAlive();
  }

  Future<bool> clearChat() async {
    if (_disposed) return false;

    final result = await _history.clear(_serviceKey);

    if (!result || _disposed) {
      return false;
    }

    _messages.clear();
    _theme = ChatThemeService.forService(_serviceKey);

    _notifyIfAlive();
    return true;
  }

  int get messageCount => _messages.length;

  bool get isEmpty => _messages.isEmpty;

  void _updateThemeForMessage(String text) {
    final nextTheme = ChatThemeService.detectFromText(
      text,
      serviceKey: _serviceKey,
    );

    _theme = nextTheme;
  }

  void _updateThemeFromLatestMessage() {
    if (_messages.isEmpty) {
      _theme = ChatThemeService.forService(_serviceKey);
      return;
    }

    final latest = _messages.last;

    if (latest.text.trim().isEmpty) {
      _theme = ChatThemeService.forService(_serviceKey);
      return;
    }

    _theme = ChatThemeService.detectFromText(
      latest.text,
      serviceKey: _serviceKey,
    );
  }

  Future<void> _save() async {
    if (_disposed) return;

    try {
      await _history.save(
        _serviceKey,
        _messages
            .map((message) => message.toJson())
            .toList(),
      );
    } catch (error, stackTrace) {
      debugPrint('ChatController.save error: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _trimMessages() {
    const maxMessages = ChatHistoryService.maxMessages;

    if (_messages.length <= maxMessages) {
      return;
    }

    _messages.removeRange(
      0,
      _messages.length - maxMessages,
    );
  }

  void _notifyIfAlive() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  static String _normalizeServiceKey(String value) {
    final key = value.trim();

    if (ServiceKeys.isValid(key)) {
      return key;
    }

    return ServiceKeys.general;
  }
}
