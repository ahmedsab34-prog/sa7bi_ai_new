import 'package:flutter/foundation.dart';

import '../config/service_keys.dart';
import 'storage_service.dart';

/// مسؤول عن حفظ واسترجاع سجل كل محادثة بشكل مستقل.
///
/// يستخدم مفاتيح StorageService الموحدة حتى لا تتكون
/// نسختان مختلفتان من سجل المحادثة.
class ChatHistoryService {
  ChatHistoryService._();

  static final ChatHistoryService instance =
      ChatHistoryService._();

  /// الحد الأقصى للرسائل المحفوظة لكل محادثة.
  static const int maxMessages = 80;

  StorageService get _storage =>
      StorageService.instance;

  /// الاحتفاظ بآخر 80 رسالة فقط.
  List<Map<String, dynamic>> _limit(
    List<Map<String, dynamic>> messages,
  ) {
    if (messages.length <= maxMessages) {
      return List<Map<String, dynamic>>.from(
        messages,
      );
    }

    return messages.sublist(
      messages.length - maxMessages,
    );
  }

  /// تنظيف الرسالة قبل التخزين.
  ///
  /// نحافظ على البيانات البسيطة التي يستخدمها الشات:
  /// النص، الدور، الوقت، الصورة، وأي بيانات إضافية قابلة
  /// للتخزين بصيغة SharedPreferences/JSON.
  Map<String, dynamic> _normalizeMessage(
    Map<String, dynamic> message,
  ) {
    final normalized =
        <String, dynamic>{};

    message.forEach((key, value) {
      if (value == null) {
        return;
      }

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

  /// تحميل تاريخ المحادثة الخاصة بالخدمة.
  Future<List<Map<String, dynamic>>> load(
    String serviceKey,
  ) async {
    try {
      final messages =
          await _storage.getChatHistory(
        serviceKey,
      );

      final normalized = messages
          .map(_normalizeMessage)
          .toList();

      return _limit(normalized);
    } catch (e) {
      debugPrint(
        'ChatHistoryService.load error: $e',
      );

      return <Map<String, dynamic>>[];
    }
  }

  /// حفظ تاريخ المحادثة بالكامل.
  Future<bool> save(
    String serviceKey,
    List<Map<String, dynamic>> messages,
  ) async {
    try {
      final normalized = messages
          .map(_normalizeMessage)
          .toList();

      final limited = _limit(normalized);

      return await _storage.saveChatHistory(
        serviceKey,
        limited,
      );
    } catch (e) {
      debugPrint(
        'ChatHistoryService.save error: $e',
      );

      return false;
    }
  }

  /// إضافة رسالة واحدة إلى المحادثة.
  ///
  /// إذا تجاوزت المحادثة 80 رسالة يتم الاحتفاظ
  /// بآخر 80 رسالة فقط.
  Future<bool> addMessage(
    String serviceKey,
    Map<String, dynamic> message,
  ) async {
    final messages =
        await load(serviceKey);

    messages.add(
      _normalizeMessage(message),
    );

    return save(
      serviceKey,
      messages,
    );
  }

  /// حذف محادثة خدمة واحدة فقط.
  ///
  /// لا يؤثر على باقي المحادثات.
  Future<bool> clear(
    String serviceKey,
  ) async {
    try {
      return await _storage.clearChatHistory(
        serviceKey,
      );
    } catch (e) {
      debugPrint(
        'ChatHistoryService.clear error: $e',
      );

      return false;
    }
  }

  /// معرفة هل توجد رسائل محفوظة لهذه الخدمة.
  Future<bool> hasHistory(
    String serviceKey,
  ) async {
    final messages =
        await load(serviceKey);

    return messages.isNotEmpty;
  }

  /// عدد الرسائل المحفوظة للخدمة.
  Future<int> messageCount(
    String serviceKey,
  ) async {
    final messages =
        await load(serviceKey);

    return messages.length;
  }

  /// حذف جميع محادثات الخدمات المعروفة.
  ///
  /// هذه الدالة للاستخدام الإداري أو عند تنظيف بيانات
  /// التطبيق، وليست جزءًا من الاستخدام الطبيعي للشات.
  Future<void> clearAllKnownChats() async {
    for (final key in ServiceKeys.chatServices) {
      await clear(key);
    }
  }
}
