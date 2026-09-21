import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

/// خدمة بيانات المستخدم الشخصية في صاحبي AI.
///
/// تحفظ بيانات البروفايل محليًا بحيث تستخدمها:
/// - الصفحة الشخصية.
/// - الشات العام.
/// - خلصانة AI.
/// - جميع أقسام الخدمات.
/// - صورة المستخدم بجانب رسائله.
/// - اسم المستخدم بدل كلمة "أنت".
///
/// لا تحتوي هذه الخدمة على أي بيانات سرية.
class ProfileService {
  ProfileService._();

  static final ProfileService instance = ProfileService._();

  // ============================================================
  // Storage keys
  // ============================================================

  static const String profileNameKey = 'profile_name';

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

  /// إرجاع اسم المستخدم مع قيمة آمنة إذا لم يتم تحديد اسم.
  String get displayName {
    final value = _name.trim();

    if (value.isEmpty) {
      return defaultProfileName;
    }

    return value;
  }

  /// تحويل الصورة المحفوظة إلى Bytes لاستخدامها في Image.memory.
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
      _reelName = savedReel;
    } else {
      _reelName = '';
    }
  }

  /// إعادة تحميل بيانات البروفايل من التخزين.
  Future<void> refresh() async {
    await _ensureInitialized();

    await _load();
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

    _name = cleaned;

    final prefs = _preferences;

    if (prefs == null) {
      return false;
    }

    return prefs.setString(
      profileNameKey,
      _name,
    );
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

    // نتأكد أن القيمة فعلًا Base64 قابلة للفك.
    try {
      base64Decode(cleaned);
    } catch (_) {
      return false;
    }

    _photoBase64 = cleaned;

    final prefs = _preferences;

    if (prefs == null) {
      return false;
    }

    return prefs.setString(
      profilePhotoKey,
      _photoBase64,
    );
  }

  /// حفظ الصورة مباشرة من Bytes.
  Future<bool> savePhotoBytes(
    Uint8List bytes,
  ) async {
    if (bytes.isEmpty) {
      return false;
    }

    final encoded =
        base64Encode(bytes);

    return savePhotoBase64(encoded);
  }

  /// حذف صورة المستخدم.
  Future<bool> clearPhoto() async {
    await _ensureInitialized();

    _photoBase64 = '';

    final prefs = _preferences;

    if (prefs == null) {
      return false;
    }

    return prefs.remove(profilePhotoKey);
  }

  // ============================================================
  // Reel
  // ============================================================

  /// حفظ اسم/مسار تعريف الـReel الخاص بالمستخدم.
  ///
  /// في المرحلة الحالية نحفظ القيمة كما هي.
  /// تخزين ملف الفيديو نفسه سيظل منفصلًا عن بيانات البروفايل.
  Future<bool> saveReelName(String value) async {
    await _ensureInitialized();

    final cleaned = value.trim();

    _reelName = cleaned;

    final prefs = _preferences;

    if (prefs == null) {
      return false;
    }

    if (cleaned.isEmpty) {
      return prefs.remove(profileReelNameKey);
    }

    return prefs.setString(
      profileReelNameKey,
      cleaned,
    );
  }

  Future<bool> clearReel() async {
    return saveReelName('');
  }

  // ============================================================
  // Clear
  // ============================================================

  /// حذف بيانات البروفايل بالكامل.
  ///
  /// لا يُستدعى تلقائيًا.
  /// سيُستخدم فقط عند اختيار المستخدم حذف بياناته.
  Future<void> clearProfile() async {
    await _ensureInitialized();

    final prefs = _preferences;

    _name = defaultProfileName;
    _photoBase64 = '';
    _reelName = '';

    if (prefs == null) {
      return;
    }

    await prefs.remove(profileNameKey);
    await prefs.remove(profilePhotoKey);
    await prefs.remove(profileReelNameKey);
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

  /// بيانات مختصرة يمكن استخدامها لاحقًا في واجهات أخرى.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name': displayName,
      'photoBase64': _photoBase64,
      'reelName': _reelName,
      'hasPhoto': hasPhoto,
      'hasReel': hasReel,
    };
  }
}
