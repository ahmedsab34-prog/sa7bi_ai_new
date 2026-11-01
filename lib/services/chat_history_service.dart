import 'package:flutter/foundation.dart';

import '../config/service_keys.dart';
import 'storage_service.dart';
import 'venting_security_service.dart';

/// Responsible for loading and saving each chat's independent history.
///
/// All ordinary chats retain their existing StorageService keys and format.
/// The venting chat is routed to its encrypted local vault instead.
class ChatHistoryService {
  ChatHistoryService._();

  static final ChatHistoryService instance = ChatHistoryService._();

  /// Maximum number of messages saved for each conversation.
  static const int maxMessages = 80;

  StorageService get _storage => StorageService.instance;
  VentingSecurityService get _ventingSecurity =>
      VentingSecurityService.instance;

  bool _isVenting(String serviceKey) => serviceKey == ServiceKeys.venting;

  List<Map<String, dynamic>> _limit(
    List<Map<String, dynamic>> messages,
  ) {
    if (messages.length <= maxMessages) {
      return List<Map<String, dynamic>>.from(messages);
    }
    return messages.sublist(messages.length - maxMessages);
  }

  Map<String, dynamic> _normalizeMessage(Map<String, dynamic> message) {
    final normalized = <String, dynamic>{};
    message.forEach((key, value) {
      if (value == null) return;
      if (value is String ||
          value is num ||
          value is bool ||
          value is List ||
          value is Map) {
        normalized[key] = value;
      } else {
        normalized[key] = value.toString();
      }
    });
    return normalized;
  }

  Future<List<Map<String, dynamic>>> load(String serviceKey) async {
    // Do not convert a locked/corrupt private vault into an empty conversation.
    // That would hide the lock or make old history appear to have disappeared.
    if (_isVenting(serviceKey)) {
      final messages = await _ventingSecurity.loadHistory();
      return _limit(messages.map(_normalizeMessage).toList());
    }

    try {
      final messages = await _storage.getChatHistory(serviceKey);
      final normalized = messages.map(_normalizeMessage).toList();
      return _limit(normalized);
    } catch (error) {
      debugPrint('ChatHistoryService.load error: $error');
      return <Map<String, dynamic>>[];
    }
  }

  Future<bool> save(
    String serviceKey,
    List<Map<String, dynamic>> messages,
  ) async {
    final normalized = messages.map(_normalizeMessage).toList();
    final limited = _limit(normalized);

    if (_isVenting(serviceKey)) {
      return _ventingSecurity.saveHistory(limited);
    }

    try {
      return await _storage.saveChatHistory(serviceKey, limited);
    } catch (error) {
      debugPrint('ChatHistoryService.save error: $error');
      return false;
    }
  }

  Future<bool> addMessage(
    String serviceKey,
    Map<String, dynamic> message,
  ) async {
    final messages = await load(serviceKey);
    messages.add(_normalizeMessage(message));
    return save(serviceKey, messages);
  }

  Future<bool> clear(String serviceKey) async {
    if (_isVenting(serviceKey)) {
      return _ventingSecurity.clearHistory();
    }

    try {
      return await _storage.clearChatHistory(serviceKey);
    } catch (error) {
      debugPrint('ChatHistoryService.clear error: $error');
      return false;
    }
  }

  Future<bool> hasHistory(String serviceKey) async {
    final messages = await load(serviceKey);
    return messages.isNotEmpty;
  }

  Future<int> messageCount(String serviceKey) async {
    final messages = await load(serviceKey);
    return messages.length;
  }

  /// Administrative cleanup. Venting must be unlocked before it can be cleared.
  Future<void> clearAllKnownChats() async {
    for (final key in ServiceKeys.chatServices) {
      await clear(key);
    }
  }
}
