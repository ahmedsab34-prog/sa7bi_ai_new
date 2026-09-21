import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../config/service_keys.dart';
import 'storage_service.dart';

/// مسؤول عن حفظ واسترجاع سجل كل محادثة بشكل مستقل.
///
/// المميزات:
/// - كل خدمة لها سجل منفصل.
/// - يدعم محادثة صاحبي AI العامة.
/// - يدعم خلصانة AI.
/// - يدعم الأقسام العشرة.
/// - الحد الأقصى 80 رسالة.
/// - يحافظ على ترتيب الرسائل.
/// - يعتمد على StorageService بدل التعامل المباشر مع SharedPreferences.
/// - يستخدم ServiceKeys ثابتة حتى لا تتأثر اللغة أو اسم الشاشة بتغيير مفتاح التخزين.
class ChatHistoryService {
  ChatHistoryService._();

  static final ChatHistoryService instance =
      ChatHistoryService._();

  static const int maxMessages = 80;

  /// مفتاح أساسي موحد لسجلات المحادثات.
  static const String _storagePrefix = 'chat_history_';

  StorageService get _storage => StorageService.instance;

  /// يرجع مفتاح التخزين الخاص بالخدمة.
  String _key(String serviceKey) {
    final normalized = serviceKey.trim();

    if (normalized.isEmpty) {
      return '${_storagePrefix}${ServiceKeys.general}';
    }

    return '$_storagePrefix$normalized';
  }

  /// يضمن أن الرسالة قابلة للحفظ.
  ///
  /// نقوم بتنظيف البيانات الأساسية فقط، بدون حذف أي محتوى كتبه المستخدم.
  Map<String, dynamic> _normalizeMessage(
    Map<String, dynamic> message,
  ) {
    final normalized = <String, dynamic>{};

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

  /// تحميل تاريخ المحادثة.
  Future<List<Map<String, dynamic>>> load(
    String serviceKey,
  ) async {
    try {
      final raw = await _storage.getString(_key(serviceKey));

      if (raw == null || raw.trim().isEmpty) {
        return <Map<String, dynamic>>[];
      }

      final decoded = jsonDecode(raw);

      if (decoded is! List) {
        return <Map<String, dynamic>>[];
      }

      final messages = <Map<String, dynamic>>[];

      for (final item in decoded) {
        if (item is Map) {
          messages.add(
            _normalizeMessage(
              Map<String, dynamic>.from(item),
            ),
          );
        }
      }

      if (messages.length <= maxMessages) {
        return messages;
      }

      return messages.sublist(
        messages.length - maxMessages,
      );
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

      final limited = normalized.length <= maxMessages
          ? normalized
          : normalized.sublist(
              normalized.length - maxMessages,
            );

      return await _storage.setString(
        _key(serviceKey),
        jsonEncode(limited),
      );
    } catch (e) {
      debugPrint(
        'ChatHistoryService.save error: $e',
      );
      return false;
    }
  }

  /// إضافة رسالة واحدة مع الاحتفاظ بآخر 80 رسالة فقط.
  Future<bool> addMessage(
    String serviceKey,
    Map<String, dynamic> message,
  ) async {
    final messages = await load(serviceKey);

    messages.add(
      _normalizeMessage(message),
    );

    if (messages.length > maxMessages) {
      messages.removeRange(
        0,
        messages.length - maxMessages,
      );
    }

    return save(serviceKey, messages);
  }

  /// حذف محادثة خدمة واحدة فقط.
  Future<bool> clear(
    String serviceKey,
  ) async {
    try {
      return await _storage.remove(
        _key(serviceKey),
      );
    } catch (e) {
      debugPrint(
        'ChatHistoryService.clear error: $e',
      );
      return false;
    }
  }

  /// هل توجد محادثة محفوظة لهذه الخدمة؟
  Future<bool> hasHistory(
    String serviceKey,
  ) async {
    final messages = await load(serviceKey);
    return messages.isNotEmpty;
  }

  /// عدد الرسائل المحفوظة.
  Future<int> messageCount(
    String serviceKey,
  ) async {
    final messages = await load(serviceKey);
    return messages.length;
  }

  /// حذف كل سجلات المحادثات التي نعرف مفاتيحها.
  ///
  /// لا يتم استخدام هذا أثناء التشغيل العادي.
  /// موجود فقط للحالات التي نحتاج فيها تنظيف بيانات التطبيق.
  Future<void> clearAllKnownChats() async {
    for (final key in ServiceKeys.chatServices) {
      await clear(key);
    }
  }
}
