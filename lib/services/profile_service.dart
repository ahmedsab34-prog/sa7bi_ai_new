import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// خدمة بيانات المستخدم الشخصية في صاحبي AI.
///
/// مصدر واحد لبيانات المستخدم في التطبيق كله:
/// - الصفحة الشخصية.
/// - الهيدر.
/// - الشات.
/// - خلصانة AI.
/// - صورة المستخدم بجانب رسائله.
/// - اسم المستخدم.
/// - مؤشر وجود Reel.
///
/// أي تغيير في البيانات يرسل إشعارًا عبر [changes] حتى تستطيع
/// الواجهات الموجودة بالفعل تحديث نفسها بدون إعادة تشغيل التطبيق.
class ProfileService {
  ProfileService._();

  static final ProfileService instance =
      ProfileService._();

  // ============================================================
  // Storage keys
  // ============================================================

  static const String profileNameKey =
      'profile_name';

  static const String profilePhotoKey =
      'profile_photo_base64';

  static const String profileReelNameKey =
      'profile_reel_name';

  // ============================================================
  // Default values
  // ============================================================

  static const String defaultProfileName =
      'صاحبي';

  // ============================================================
  // Reactive state
  // ============================================================

  /// يتغير رقمه عند حدوث أي تغيير في بيانات البروفايل.
  ///
  /// الواجهات التي تستمع إليه تعيد بناء نفسها تلقائيًا:
  /// - AppHeader
  /// - ChatUserAvatar
  /// - ProfileScreen
  /// - أي شاشة أخرى تستخدم بيانات المستخدم.
  final ValueNotifier<int> changes =
      ValueNotifier<int>(0);

  void _notifyChanged() {
    changes.value++;
  }

  // ============================================================
  // Internal state
  // ============================================================

  SharedPreferences? _preferences;

  bool _initialized = false;

  String _name = defaultProfileName;

  String _photoBase64 = '';

  String _reelName = '';

  // ============================================================
  // Getters
  // ============================================================

  bool get isInitialized => _initialized;

  String get name => _name;

  String get photoBase64 => _photoBase64;

  String get reelName => _reelName;

  bool get hasName =>
      _name.trim().isNotEmpty &&
      _name.trim() != defaultProfileName;

  bool get hasPhoto =>
      _photoBase64.trim().isNotEmpty;

  bool get hasReel =>
      _reelName.trim().isNotEmpty;

  /// اسم آمن للعرض في التطبيق.
  String get displayName {
    final value = _name.trim();

    if (value.isEmpty) {
      return defaultProfileName;
    }

    return value;
  }

  /// الصورة المحفوظة كـBytes.
  Uint8List? get photoBytes {
    if (_photoBase64.trim().isEmpty) {
      return null;
    }

    try {
      return base64Decode(_photoBase64);
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // Initialization
  // ============================================================

  /// قراءة بيانات البروفايل من الجهاز.
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _preferences =
        await SharedPreferences.getInstance();

    await _load();

    _initialized = true;

    // إبلاغ أي واجهة بدأت الاستماع قبل اكتمال التحميل.
    _notifyChanged();
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  Future<void> _load() async {
    final prefs = _preferences;

    if (prefs == null) {
      return;
    }

    final savedName =
        prefs.getString(profileNameKey);

    final savedPhoto =
        prefs.getString(profilePhotoKey);

    final savedReel =
        prefs.getString(profileReelNameKey);

    if (savedName != null &&
        savedName.trim().isNotEmpty) {
      _name = savedName.trim();
    } else {
      _name = defaultProfileName;
    }

    if (savedPhoto != null) {
      _photoBase64 = savedPhoto;
    } else {
      _photoBase64 = '';
    }

    if (savedReel != null) {
      _reelName = savedReel.trim();
    } else {
      _reelName = '';
    }
  }

  /// إعادة قراءة البيانات من SharedPreferences.
  Future<void> refresh() async {
    await _ensureInitialized();

    await _load();

    _notifyChanged();
  }

  // ============================================================
  // Name
  // ============================================================

  /// حفظ اسم المستخدم.
  Future<bool> saveName(String value) async {
    await _ensureInitialized();

    final cleaned = value.trim();

    if (cleaned.isEmpty) {
      return false;
    }

    final prefs = _preferences;

    if (prefs == null) {
      return false;
    }

    final success = await prefs.setString(
      profileNameKey,
      cleaned,
    );

    if (!success) {
      return false;
    }

    _name = cleaned;

    _notifyChanged();

    return true;
  }

  /// تغيير الاسم.
  Future<bool> updateName(String value) {
    return saveName(value);
  }

  // ============================================================
  // Photo
  // ============================================================

  /// حفظ صورة المستخدم كـBase64.
  Future<bool> savePhotoBase64(
    String base64Value,
  ) async {
    await _ensureInitialized();

    final cleaned = base64Value.trim();

    if (cleaned.isEmpty) {
      return false;
    }

    // التأكد أن القيمة Base64 صحيحة.
    try {
      base64Decode(cleaned);
    } catch (_) {
      return false;
    }

    final prefs = _preferences;

    if (prefs == null) {
      return false;
    }

    final success = await prefs.setString(
      profilePhotoKey,
      cleaned,
    );

    if (!success) {
      return false;
    }

    _photoBase64 = cleaned;

    _notifyChanged();

    return true;
  }

  /// حفظ الصورة مباشرة من Bytes.
  Future<bool> savePhotoBytes(
    Uint8List bytes,
  ) async {
    if (bytes.isEmpty) {
      return false;
    }

    final encoded = base64Encode(bytes);

    return savePhotoBase64(encoded);
  }

  /// حذف صورة المستخدم.
  Future<bool> clearPhoto() async {
    await _ensureInitialized();

    final prefs = _preferences;

    if (prefs == null) {
      return false;
    }

    final success =
        await prefs.remove(profilePhotoKey);

    if (!success) {
      return false;
    }

    _photoBase64 = '';

    _notifyChanged();

    return true;
  }

  // ============================================================
  // Reel
  // ============================================================

  /// حفظ اسم/معرّف الـReel الخاص بالمستخدم.
  ///
  /// في المرحلة الحالية يتم حفظ اسم الملف/المعرّف.
  /// تخزين الفيديو نفسه منفصل عن بيانات البروفايل.
  Future<bool> saveReelName(
    String value,
  ) async {
    await _ensureInitialized();

    final cleaned = value.trim();

    final prefs = _preferences;

    if (prefs == null) {
      return false;
    }

    if (cleaned.isEmpty) {
      final success =
          await prefs.remove(profileReelNameKey);

      if (!success) {
        return false;
      }

      _reelName = '';

      _notifyChanged();

      return true;
    }

    final success = await prefs.setString(
      profileReelNameKey,
      cleaned,
    );

    if (!success) {
      return false;
    }

    _reelName = cleaned;

    _notifyChanged();

    return true;
  }

  Future<bool> clearReel() {
    return saveReelName('');
  }

  // ============================================================
  // Clear profile
  // ============================================================

  /// حذف بيانات البروفايل بالكامل.
  Future<void> clearProfile() async {
    await _ensureInitialized();

    final prefs = _preferences;

    _name = defaultProfileName;
    _photoBase64 = '';
    _reelName = '';

    if (prefs != null) {
      await prefs.remove(profileNameKey);
      await prefs.remove(profilePhotoKey);
      await prefs.remove(profileReelNameKey);
    }

    _notifyChanged();
  }

  // ============================================================
  // Convenience methods
  // ============================================================

  /// إرجاع صورة المستخدم إذا كانت موجودة.
  Uint8List? getUserPhoto() {
    return photoBytes;
  }

  /// إرجاع الاسم الذي سيظهر في الشات.
  String getChatDisplayName() {
    return displayName;
  }

  /// بيانات مختصرة للاستخدام في واجهات أخرى.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name': displayName,
      'photoBase64': _photoBase64,
      'reelName': _reelName,
      'hasPhoto': hasPhoto,
      'hasReel': hasReel,
    };
  }

  /// تنظيف الـNotifier عند عدم الحاجة للخدمة.
  ///
  /// لا يتم استدعاؤها من التطبيق أثناء التشغيل الطبيعي،
  /// لأن ProfileService عبارة عن Singleton طوال عمر التطبيق.
  void dispose() {
    changes.dispose();
  }
}
