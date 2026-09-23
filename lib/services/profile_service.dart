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
/// - صورة المستخدم.
/// - الاسم.
/// - الـReel.
/// - الـBio.
/// - الـStatus.
class ProfileService {
  ProfileService._();

  static final ProfileService instance =
      ProfileService._();

  // ============================================================
  // STORAGE KEYS
  // ============================================================

  static const String profileNameKey =
      'profile_name';

  static const String profilePhotoKey =
      'profile_photo_base64';

  static const String profileReelNameKey =
      'profile_reel_name';

  static const String profileBioKey =
      'profile_bio';

  static const String profileStatusKey =
      'profile_status';

  // ============================================================
  // DEFAULT VALUES
  // ============================================================

  static const String defaultProfileName =
      'صاحبي';

  static const String defaultProfileBio =
      '';

  static const String defaultProfileStatus =
      '';

  // ============================================================
  // REACTIVE STATE
  // ============================================================

  final ValueNotifier<int> changes =
      ValueNotifier<int>(0);

  void _notifyChanged() {
    changes.value++;
  }

  // ============================================================
  // INTERNAL STATE
  // ============================================================

  SharedPreferences? _preferences;

  bool _initialized = false;

  String _name =
      defaultProfileName;

  String _photoBase64 = '';

  String _reelName = '';

  String _bio =
      defaultProfileBio;

  String _status =
      defaultProfileStatus;

  // ============================================================
  // GETTERS
  // ============================================================

  bool get isInitialized =>
      _initialized;

  String get name =>
      _name;

  String get photoBase64 =>
      _photoBase64;

  String get reelName =>
      _reelName;

  String get bio =>
      _bio;

  String get status =>
      _status;

  bool get hasName =>
      _name.trim().isNotEmpty &&
      _name.trim() !=
          defaultProfileName;

  bool get hasPhoto =>
      _photoBase64.trim().isNotEmpty;

  bool get hasReel =>
      _reelName.trim().isNotEmpty;

  bool get hasBio =>
      _bio.trim().isNotEmpty;

  bool get hasStatus =>
      _status.trim().isNotEmpty;

  String get displayName {
    final value =
        _name.trim();

    if (value.isEmpty) {
      return defaultProfileName;
    }

    return value;
  }

  Uint8List? get photoBytes {
    if (_photoBase64.trim().isEmpty) {
      return null;
    }

    try {
      return base64Decode(
        _photoBase64,
      );
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // INITIALIZATION
  // ============================================================

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _preferences =
        await SharedPreferences
            .getInstance();

    await _load();

    _initialized = true;

    _notifyChanged();
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  Future<void> _load() async {
    final prefs =
        _preferences;

    if (prefs == null) {
      return;
    }

    final savedName =
        prefs.getString(
      profileNameKey,
    );

    final savedPhoto =
        prefs.getString(
      profilePhotoKey,
    );

    final savedReel =
        prefs.getString(
      profileReelNameKey,
    );

    final savedBio =
        prefs.getString(
      profileBioKey,
    );

    final savedStatus =
        prefs.getString(
      profileStatusKey,
    );

    _name =
        savedName != null &&
                savedName.trim().isNotEmpty
            ? savedName.trim()
            : defaultProfileName;

    _photoBase64 =
        savedPhoto ?? '';

    _reelName =
        savedReel?.trim() ?? '';

    _bio =
        savedBio?.trim() ?? '';

    _status =
        savedStatus?.trim() ?? '';
  }

  Future<void> refresh() async {
    await _ensureInitialized();

    await _load();

    _notifyChanged();
  }

  // ============================================================
  // NAME
  // ============================================================

  Future<bool> saveName(
    String value,
  ) async {
    await _ensureInitialized();

    final cleaned =
        value.trim();

    if (cleaned.isEmpty) {
      return false;
    }

    final prefs =
        _preferences;

    if (prefs == null) {
      return false;
    }

    final success =
        await prefs.setString(
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

  Future<bool> updateName(
    String value,
  ) {
    return saveName(value);
  }

  // ============================================================
  // BIO
  // ============================================================

  Future<bool> saveBio(
    String value,
  ) async {
    await _ensureInitialized();

    final cleaned =
        value.trim();

    if (cleaned.length > 160) {
      return false;
    }

    final prefs =
        _preferences;

    if (prefs == null) {
      return false;
    }

    final success =
        await prefs.setString(
      profileBioKey,
      cleaned,
    );

    if (!success) {
      return false;
    }

    _bio = cleaned;

    _notifyChanged();

    return true;
  }

  // ============================================================
  // STATUS
  // ============================================================

  Future<bool> saveStatus(
    String value,
  ) async {
    await _ensureInitialized();

    final cleaned =
        value.trim();

    if (cleaned.length > 120) {
      return false;
    }

    final prefs =
        _preferences;

    if (prefs == null) {
      return false;
    }

    final success =
        await prefs.setString(
      profileStatusKey,
      cleaned,
    );

    if (!success) {
      return false;
    }

    _status = cleaned;

    _notifyChanged();

    return true;
  }

  // ============================================================
  // PHOTO
  // ============================================================

  Future<bool> savePhotoBase64(
    String base64Value,
  ) async {
    await _ensureInitialized();

    final cleaned =
        base64Value.trim();

    if (cleaned.isEmpty) {
      return false;
    }

    try {
      base64Decode(cleaned);
    } catch (_) {
      return false;
    }

    final prefs =
        _preferences;

    if (prefs == null) {
      return false;
    }

    final success =
        await prefs.setString(
      profilePhotoKey,
      cleaned,
    );

    if (!success) {
      return false;
    }

    _photoBase64 =
        cleaned;

    _notifyChanged();

    return true;
  }

  Future<bool> savePhotoBytes(
    Uint8List bytes,
  ) async {
    if (bytes.isEmpty) {
      return false;
    }

    return savePhotoBase64(
      base64Encode(bytes),
    );
  }

  Future<bool> clearPhoto() async {
    await _ensureInitialized();

    final prefs =
        _preferences;

    if (prefs == null) {
      return false;
    }

    final success =
        await prefs.remove(
      profilePhotoKey,
    );

    if (!success) {
      return false;
    }

    _photoBase64 = '';

    _notifyChanged();

    return true;
  }

  // ============================================================
  // REEL
  // ============================================================

  Future<bool> saveReelName(
    String value,
  ) async {
    await _ensureInitialized();

    final cleaned =
        value.trim();

    final prefs =
        _preferences;

    if (prefs == null) {
      return false;
    }

    if (cleaned.isEmpty) {
      final success =
          await prefs.remove(
        profileReelNameKey,
      );

      if (!success) {
        return false;
      }

      _reelName = '';

      _notifyChanged();

      return true;
    }

    final success =
        await prefs.setString(
      profileReelNameKey,
      cleaned,
    );

    if (!success) {
      return false;
    }

    _reelName =
        cleaned;

    _notifyChanged();

    return true;
  }

  Future<bool> clearReel() {
    return saveReelName('');
  }

  // ============================================================
  // PROFILE MAP
  // ============================================================

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name': displayName,
      'photoBase64': _photoBase64,
      'reelName': _reelName,
      'bio': _bio,
      'status': _status,
      'hasPhoto': hasPhoto,
      'hasReel': hasReel,
      'hasBio': hasBio,
      'hasStatus': hasStatus,
    };
  }

  // ============================================================
  // CONVENIENCE
  // ============================================================

  Uint8List? getUserPhoto() {
    return photoBytes;
  }

  String getChatDisplayName() {
    return displayName;
  }

  // ============================================================
  // CLEAR PROFILE
  // ============================================================

  Future<void> clearProfile() async {
    await _ensureInitialized();

    final prefs =
        _preferences;

    _name =
        defaultProfileName;

    _photoBase64 = '';

    _reelName = '';

    _bio =
        defaultProfileBio;

    _status =
        defaultProfileStatus;

    if (prefs != null) {
      await prefs.remove(
        profileNameKey,
      );

      await prefs.remove(
        profilePhotoKey,
      );

      await prefs.remove(
        profileReelNameKey,
      );

      await prefs.remove(
        profileBioKey,
      );

      await prefs.remove(
        profileStatusKey,
      );
    }

    _notifyChanged();
  }

  void dispose() {
    changes.dispose();
  }
}
