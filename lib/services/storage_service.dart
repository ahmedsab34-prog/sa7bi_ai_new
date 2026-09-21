import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// خدمة التخزين العامة في صاحبي AI.
///
/// الهدف منها توحيد التعامل مع SharedPreferences بدل تكرار
/// نفس كود التخزين داخل كل شاشة وخدمة.
///
/// تستخدم حاليًا للبيانات البسيطة:
/// - String
/// - int
/// - double
/// - bool
/// - JSON
/// - List<String>
///
/// بيانات الشات نفسها تظل مرتبطة بمفتاح الخدمة الخاص بها،
/// ويمكن استخدام هذه الخدمة للوصول إليها بدون تغيير شكلها.
class StorageService {
  StorageService._();

  static final StorageService instance =
      StorageService._();

  SharedPreferences? _preferences;

  bool _initialized = false;

  /// هل الخدمة جاهزة؟
  bool get isInitialized => _initialized;

  // ============================================================
  // Initialization
  // ============================================================

  /// تهيئة SharedPreferences مرة واحدة.
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _preferences =
        await SharedPreferences.getInstance();

    _initialized = true;
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  SharedPreferences get _prefs {
    final prefs = _preferences;

    if (prefs == null) {
      throw StateError(
        'StorageService has not been initialized.',
      );
    }

    return prefs;
  }

  // ============================================================
  // String
  // ============================================================

  Future<String?> getString(
    String key,
  ) async {
    await _ensureInitialized();

    return _prefs.getString(key);
  }

  Future<bool> setString(
    String key,
    String value,
  ) async {
    await _ensureInitialized();

    return _prefs.setString(
      key,
      value,
    );
  }

  // ============================================================
  // Integer
  // ============================================================

  Future<int?> getInt(
    String key,
  ) async {
    await _ensureInitialized();

    return _prefs.getInt(key);
  }

  Future<bool> setInt(
    String key,
    int value,
  ) async {
    await _ensureInitialized();

    return _prefs.setInt(
      key,
      value,
    );
  }

  // ============================================================
  // Double
  // ============================================================

  Future<double?> getDouble(
    String key,
  ) async {
    await _ensureInitialized();

    return _prefs.getDouble(key);
  }

  Future<bool> setDouble(
    String key,
    double value,
  ) async {
    await _ensureInitialized();

    return _prefs.setDouble(
      key,
      value,
    );
  }

  // ============================================================
  // Boolean
  // ============================================================

  Future<bool?> getBool(
    String key,
  ) async {
    await _ensureInitialized();

    return _prefs.getBool(key);
  }

  Future<bool> setBool(
    String key,
    bool value,
  ) async {
    await _ensureInitialized();

    return _prefs.setBool(
      key,
      value,
    );
  }

  // ============================================================
  // List<String>
  // ============================================================

  Future<List<String>?> getStringList(
    String key,
  ) async {
    await _ensureInitialized();

    return _prefs.getStringList(key);
  }

  Future<bool> setStringList(
    String key,
    List<String> value,
  ) async {
    await _ensureInitialized();

    return _prefs.setStringList(
      key,
      value,
    );
  }

  // ============================================================
  // JSON
  // ============================================================

  /// حفظ أي Map كـJSON String.
  Future<bool> setJson(
    String key,
    Map<String, dynamic> value,
  ) async {
    await _ensureInitialized();

    try {
      final encoded = jsonEncode(value);

      return _prefs.setString(
        key,
        encoded,
      );
    } catch (_) {
      return false;
    }
  }

  /// قراءة Map محفوظة بصيغة JSON.
  Future<Map<String, dynamic>?> getJson(
    String key,
  ) async {
    await _ensureInitialized();

    final value = _prefs.getString(key);

    if (value == null ||
        value.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(value);

      if (decoded is Map) {
        return Map<String, dynamic>.from(
          decoded,
        );
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  /// حفظ List من البيانات كـJSON.
  Future<bool> setJsonList(
    String key,
    List<dynamic> value,
  ) async {
    await _ensureInitialized();

    try {
      final encoded = jsonEncode(value);

      return _prefs.setString(
        key,
        encoded,
      );
    } catch (_) {
      return false;
    }
  }

  /// قراءة List محفوظة بصيغة JSON.
  Future<List<dynamic>?> getJsonList(
    String key,
  ) async {
    await _ensureInitialized();

    final value = _prefs.getString(key);

    if (value == null ||
        value.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(value);

      if (decoded is List) {
        return decoded;
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  // ============================================================
  // Remove
  // ============================================================

  /// حذف قيمة واحدة.
  Future<bool> remove(
    String key,
  ) async {
    await _ensureInitialized();

    return _prefs.remove(key);
  }

  /// التأكد من وجود مفتاح.
  Future<bool> contains(
    String key,
  ) async {
    await _ensureInitialized();

    return _prefs.containsKey(key);
  }

  // ============================================================
  // Generic helpers
  // ============================================================

  /// قراءة قيمة String مع قيمة افتراضية.
  Future<String> getStringOrDefault(
    String key, {
    String defaultValue = '',
  }) async {
    final value = await getString(key);

    if (value == null) {
      return defaultValue;
    }

    return value;
  }

  /// قراءة int مع قيمة افتراضية.
  Future<int> getIntOrDefault(
    String key, {
    int defaultValue = 0,
  }) async {
    final value = await getInt(key);

    if (value == null) {
      return defaultValue;
    }

    return value;
  }

  /// قراءة bool مع قيمة افتراضية.
  Future<bool> getBoolOrDefault(
    String key, {
    bool defaultValue = false,
  }) async {
    final value = await getBool(key);

    if (value == null) {
      return defaultValue;
    }

    return value;
  }

  // ============================================================
  // Chat storage helpers
  // ============================================================

  /// إنشاء مفتاح موحد لتاريخ شات معين.
  ///
  /// مثال:
  /// general
  /// khalasana
  /// kitchen
  /// shopping
  ///
  /// كل خدمة تحصل على تاريخ مستقل.
  String chatHistoryKey(
    String serviceKey,
  ) {
    final normalized = _normalizeKey(
      serviceKey,
    );

    return 'sa7bi_chat_history_$normalized';
  }

  /// حفظ تاريخ شات كامل.
  Future<bool> saveChatHistory(
    String serviceKey,
    List<Map<String, dynamic>> messages,
  ) async {
    final key = chatHistoryKey(serviceKey);

    return setJsonList(
      key,
      messages,
    );
  }

  /// قراءة تاريخ شات.
  Future<List<Map<String, dynamic>>> getChatHistory(
    String serviceKey,
  ) async {
    final key = chatHistoryKey(serviceKey);

    final data = await getJsonList(key);

    if (data == null) {
      return <Map<String, dynamic>>[];
    }

    final result =
        <Map<String, dynamic>>[];

    for (final item in data) {
      if (item is Map) {
        result.add(
          Map<String, dynamic>.from(item),
        );
      }
    }

    return result;
  }

  /// مسح تاريخ شات خدمة واحدة فقط.
  Future<bool> clearChatHistory(
    String serviceKey,
  ) async {
    final key = chatHistoryKey(serviceKey);

    return remove(key);
  }

  // ============================================================
  // Internal helpers
  // ============================================================

  String _normalizeKey(
    String value,
  ) {
    var result = value.trim().toLowerCase();

    result = result.replaceAll(
      RegExp(r'\s+'),
      '_',
    );

    result = result.replaceAll(
      RegExp(r'[^a-z0-9_\-]+'),
      '_',
    );

    result = result.replaceAll(
      RegExp(r'_+'),
      '_',
    );

    result = result.replaceAll(
      RegExp(r'^_+|_+$'),
      '',
    );

    if (result.isEmpty) {
      result = 'general';
    }

    return result;
  }
}
