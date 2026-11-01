import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography_flutter/cryptography_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/service_keys.dart';
import 'storage_service.dart';

/// Local security boundary for the private venting conversation.
///
/// The history file is encrypted with AES-256-GCM. The data key is wrapped by
/// an Argon2id key derived from the user's PIN and stored in platform secure
/// storage. An optional second secure-storage namespace protects a copy of the
/// data key with Android biometric authentication.
///
/// This protects conversation history at rest on this device. It is not
/// end-to-end encryption for network requests sent to the AI backend.
class VentingSecurityService {
  VentingSecurityService._() {
    // Uses native AES-GCM where the platform plugin provides it. Argon2id
    // remains available through cryptography's supported implementation.
    FlutterCryptography.enable();
  }

  static final VentingSecurityService instance = VentingSecurityService._();

  static const String _keyBundleStorageKey = 'venting_key_bundle_v1';
  static const String _biometricDataKey = 'venting_biometric_data_key_v1';
  static const String _biometricEnabledKey = 'venting_biometric_enabled_v1';
  static const int _formatVersion = 1;
  static const int _dataKeyLength = 32;
  static const int _saltLength = 16;
  static const String _historyAad = 'sa7bi-venting-history-v1';
  static const String _keyWrapAad = 'sa7bi-venting-key-wrap-v1';

  static final AesGcm _cipher = AesGcm.with256bits();

  // Do not let a KeyStore error silently reset the only wrapped data key.
  final FlutterSecureStorage _pinStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      resetOnError: false,
      storageNamespace: 'sa7bi_venting_pin_v1',
    ),
  );

  // A separate namespace prevents the PIN store and biometric store from
  // sharing KeyStore aliases or encrypted preference files.
  final FlutterSecureStorage _biometricStorage = FlutterSecureStorage(
    aOptions: AndroidOptions.biometric(
      resetOnError: false,
      enforceBiometrics: true,
      storageNamespace: 'sa7bi_venting_biometric_v1',
      biometricPromptTitle: 'افتح الفضفضة السرية',
      biometricPromptSubtitle: 'استخدم بصمة الإصبع لفتح محادثتك الخاصة',
      biometricPromptNegativeButton: 'استخدام الرقم السري',
    ),
  );

  Uint8List? _dataKeyBytes;
  SecretKeyData? _activeSecretKey;
  Future<void>? _migrationFuture;

  bool get isUnlocked => _dataKeyBytes != null;

  /// Checks whether a PIN-protected key bundle has already been configured.
  Future<bool> hasPin() async {
    final value = await _pinStorage.read(key: _keyBundleStorageKey);
    return value != null && value.trim().isNotEmpty;
  }

  /// Returns the saved preference flag; it does not invoke biometric UI.
  Future<bool> isBiometricEnabled() async {
    return await _pinStorage.read(key: _biometricEnabledKey) == 'true';
  }

  /// Creates the first PIN and wrapped random data key.
  /// Existing legacy history is migrated before this method succeeds.
  Future<void> setupPin(String pin) async {
    _validatePin(pin);

    if (await hasPin()) {
      throw const VentingSecurityException(
        'تم إعداد قفل الفضفضة بالفعل. افتحها بالرقم السري الحالي.',
      );
    }

    final dataKey = _randomBytes(_dataKeyLength);
    final salt = _randomBytes(_saltLength);
    final wrappingKey = await _derivePinKey(pin, salt);
    final wrapped = await _cipher.encrypt(
      dataKey,
      secretKey: wrappingKey,
      aad: utf8.encode(_keyWrapAad),
    );

    final bundle = <String, dynamic>{
      'version': _formatVersion,
      'salt': base64Encode(salt),
      'nonce': base64Encode(wrapped.nonce),
      'cipherText': base64Encode(wrapped.cipherText),
      'mac': base64Encode(wrapped.mac.bytes),
    };

    await _pinStorage.write(
      key: _keyBundleStorageKey,
      value: jsonEncode(bundle),
    );

    _dataKeyBytes = Uint8List.fromList(dataKey);

    try {
      await _ensureLegacyHistoryMigrated();
    } catch (_) {
      lock();
      rethrow;
    }
  }

  /// Unlocks by deriving the wrapping key from the entered PIN.
  Future<void> unlockWithPin(String pin) async {
    _validatePin(pin);

    final rawBundle = await _pinStorage.read(key: _keyBundleStorageKey);
    if (rawBundle == null || rawBundle.trim().isEmpty) {
      throw const VentingSecurityException(
        'لم يتم إعداد الرقم السري للفضفضة بعد.',
      );
    }

    Uint8List unwrappedKey;
    try {
      final decoded = jsonDecode(rawBundle);
      if (decoded is! Map) {
        throw const FormatException('Invalid secure key bundle.');
      }

      final bundle = Map<String, dynamic>.from(decoded);
      if (bundle['version'] != _formatVersion) {
        throw const FormatException('Unsupported secure key bundle.');
      }

      final salt = _decodeRequired(bundle['salt']);
      final nonce = _decodeRequired(bundle['nonce']);
      final cipherText = _decodeRequired(bundle['cipherText']);
      final macBytes = _decodeRequired(bundle['mac']);
      if (salt.length != _saltLength || cipherText.length != _dataKeyLength) {
        throw const FormatException('Invalid wrapped key length.');
      }

      final wrappingKey = await _derivePinKey(pin, salt);
      final unwrapped = await _cipher.decrypt(
        SecretBox(
          cipherText,
          nonce: nonce,
          mac: Mac(macBytes),
        ),
        secretKey: wrappingKey,
        aad: utf8.encode(_keyWrapAad),
      );

      if (unwrapped.length != _dataKeyLength) {
        throw const FormatException('Invalid data key length.');
      }
      unwrappedKey = Uint8List.fromList(unwrapped);
    } catch (_) {
      lock();
      throw const VentingSecurityException(
        'الرقم السري غير صحيح أو بيانات مفتاح الفضفضة غير سليمة.',
      );
    }

    _dataKeyBytes = unwrappedKey;
    try {
      await _ensureLegacyHistoryMigrated();
    } catch (_) {
      lock();
      rethrow;
    }
  }

  /// Unlocks by asking the operating system to authenticate biometrically.
  /// PIN unlock remains available if the biometric sensor is unavailable.
  Future<void> unlockWithBiometrics() async {
    if (!await isBiometricEnabled()) {
      throw const VentingSecurityException(
        'البصمة غير مفعّلة. استخدم الرقم السري لفتح الفضفضة.',
      );
    }

    Uint8List key;
    try {
      final encodedKey = await _biometricStorage.read(
        key: _biometricDataKey,
      );
      if (encodedKey == null || encodedKey.isEmpty) {
        throw const FormatException('Missing biometric key.');
      }

      final decodedKey = base64Decode(encodedKey);
      if (decodedKey.length != _dataKeyLength) {
        throw const FormatException('Invalid biometric key length.');
      }
      key = Uint8List.fromList(decodedKey);
    } catch (_) {
      lock();
      throw const VentingSecurityException(
        'تعذر التحقق بالبصمة. استخدم الرقم السري، ثم جرّب تفعيل البصمة مرة أخرى.',
      );
    }

    _dataKeyBytes = key;
    try {
      await _ensureLegacyHistoryMigrated();
    } catch (_) {
      lock();
      rethrow;
    }
  }

  /// Must be called while the vault is unlocked with the PIN or biometric.
  Future<void> enableBiometrics() async {
    final key = _requireDataKey();

    try {
      await _biometricStorage.write(
        key: _biometricDataKey,
        value: base64Encode(key),
      );
      await _pinStorage.write(
        key: _biometricEnabledKey,
        value: 'true',
      );
    } catch (_) {
      // Do not set the enabled flag unless the protected write succeeded.
      await _pinStorage.write(
        key: _biometricEnabledKey,
        value: 'false',
      );
      throw const VentingSecurityException(
        'لم نستطع تفعيل البصمة على هذا الهاتف. يظل الرقم السري متاحًا.',
      );
    }
  }

  Future<void> disableBiometrics() async {
    await _biometricStorage.delete(key: _biometricDataKey);
    await _pinStorage.write(
      key: _biometricEnabledKey,
      value: 'false',
    );
  }

  /// Clears the in-memory key. Encrypted history remains on disk.
  void lock() {
    _activeSecretKey?.destroy();
    _activeSecretKey = null;
    final key = _dataKeyBytes;
    if (key != null) {
      key.fillRange(0, key.length, 0);
    }
    _dataKeyBytes = null;
  }

  Future<List<Map<String, dynamic>>> loadHistory() async {
    await _ensureLegacyHistoryMigrated();
    final key = _requireDataKey();
    return _readEncryptedHistory(key);
  }

  Future<bool> saveHistory(List<Map<String, dynamic>> messages) async {
    final key = _requireDataKey();
    await _ensureLegacyHistoryMigrated();
    await _writeEncryptedHistory(messages, key);
    return true;
  }

  Future<bool> clearHistory() async {
    final key = _requireDataKey();
    await _ensureLegacyHistoryMigrated();
    await _writeEncryptedHistory(const <Map<String, dynamic>>[], key);
    return true;
  }

  Uint8List _requireDataKey() {
    final key = _dataKeyBytes;
    if (key == null || key.length != _dataKeyLength) {
      throw const VentingSecurityException(
        'الفضفضة مقفولة. افتحها بالرقم السري أو البصمة أولًا.',
      );
    }
    return key;
  }

  SecretKeyData _requireSecretKey() {
    _requireDataKey();
    return _activeSecretKey ??= SecretKeyData(
      _dataKeyBytes!,
      overwriteWhenDestroyed: true,
      debugLabel: 'Sa7bi private venting history key',
    );
  }

  Future<SecretKey> _derivePinKey(String pin, List<int> salt) async {
    final argon2 = Argon2id(
      memory: 32 * 1000,
      parallelism: 1,
      iterations: 3,
      hashLength: _dataKeyLength,
    );
    return argon2.deriveKeyFromPassword(
      password: pin,
      nonce: salt,
    );
  }

  Future<void> _ensureLegacyHistoryMigrated() {
    _requireDataKey();

    final pending = _migrationFuture;
    if (pending != null) return pending;

    final future = _migrateLegacyHistory();
    _migrationFuture = future;

    return future.whenComplete(() {
      if (identical(_migrationFuture, future)) {
        _migrationFuture = null;
      }
    });
  }

  Future<void> _migrateLegacyHistory() async {
    final key = _requireDataKey();
    final file = await _historyFile();
    final preferences = await SharedPreferences.getInstance();
    final legacyKey = StorageService.instance.chatHistoryKey(
      ServiceKeys.venting,
    );

    final backup = File('${file.path}.bak');

    // Recover the last verified encrypted file if the app was interrupted
    // after moving the target aside but before the replacement was renamed.
    if (!await file.exists() && await backup.exists()) {
      await _readEncryptedHistory(key, fileOverride: backup);
      await backup.rename(file.path);
    }

    // If an encrypted file already exists, it must authenticate successfully.
    // Never fall back to plaintext when an encrypted file is present but corrupt.
    if (await file.exists()) {
      try {
        await _readEncryptedHistory(key, fileOverride: file);
      } catch (_) {
        // If a previous verified generation is available, restore that
        // encrypted copy. Never switch to plaintext on an authentication error.
        if (!await backup.exists()) rethrow;
        await _readEncryptedHistory(key, fileOverride: backup);
        await file.delete();
        await backup.rename(file.path);
        await _readEncryptedHistory(key, fileOverride: file);
      }
      if (await backup.exists()) {
        await backup.delete();
      }
      if (preferences.containsKey(legacyKey)) {
        final removed = await preferences.remove(legacyKey);
        if (!removed) {
          throw const VentingSecurityException(
            'تم التحقق من النسخة المشفرة، لكن تعذر حذف النسخة القديمة غير المشفرة. أعد المحاولة.',
          );
        }
      }
      return;
    }

    final rawLegacy = preferences.getString(legacyKey);
    final legacyMessages = <Map<String, dynamic>>[];

    if (rawLegacy != null && rawLegacy.trim().isNotEmpty) {
      dynamic decoded;
      try {
        decoded = jsonDecode(rawLegacy);
      } catch (_) {
        throw const VentingSecurityException(
          'تعذر قراءة سجل الفضفضة القديم. لم نحذفه حفاظًا على رسائلك.',
        );
      }
      if (decoded is! List) {
        throw const VentingSecurityException(
          'سجل الفضفضة القديم ليس بالتنسيق المتوقع. لم نحذفه حفاظًا على رسائلك.',
        );
      }

      for (final item in decoded) {
        if (item is! Map) {
          throw const VentingSecurityException(
            'وجدنا رسالة قديمة غير مكتملة. لم نحذف السجل القديم.',
          );
        }
        legacyMessages.add(Map<String, dynamic>.from(item));
      }
    }

    // Write encrypted data first, then decrypt and compare it, and only then
    // remove the old plaintext SharedPreferences key.
    await _writeEncryptedHistory(legacyMessages, key);
    final verified = await _readEncryptedHistory(key, fileOverride: file);
    if (jsonEncode(verified) != jsonEncode(legacyMessages)) {
      throw const VentingSecurityException(
        'لم نتمكن من مطابقة سجل الفضفضة بعد تشفيره. احتفظنا بالنسخة القديمة.',
      );
    }

    if (rawLegacy != null) {
      final removed = await preferences.remove(legacyKey);
      if (!removed) {
        throw const VentingSecurityException(
          'تم تشفير سجل الفضفضة والتحقق منه، لكن تعذر حذف النسخة القديمة. أعد المحاولة.',
        );
      }
    }
  }

  Future<List<Map<String, dynamic>>> _readEncryptedHistory(
    Uint8List key, {
    File? fileOverride,
  }) async {
    final file = fileOverride ?? await _historyFile();
    if (!await file.exists()) {
      throw const VentingSecurityException(
        'ملف سجل الفضفضة المشفر غير موجود. لم نفتح سجلًا قديمًا تلقائيًا.',
      );
    }

    try {
      final envelopeValue = jsonDecode(await file.readAsString());
      if (envelopeValue is! Map) {
        throw const FormatException('Invalid encrypted history envelope.');
      }
      final envelope = Map<String, dynamic>.from(envelopeValue);
      if (envelope['version'] != _formatVersion) {
        throw const FormatException('Unsupported encrypted history version.');
      }

      final nonce = _decodeRequired(envelope['nonce']);
      final cipherText = _decodeRequired(envelope['cipherText']);
      final macBytes = _decodeRequired(envelope['mac']);
      final clearBytes = await _cipher.decrypt(
        SecretBox(
          cipherText,
          nonce: nonce,
          mac: Mac(macBytes),
        ),
        secretKey: _requireSecretKey(),
        aad: utf8.encode(_historyAad),
      );

      final decoded = jsonDecode(utf8.decode(clearBytes));
      if (decoded is! List) {
        throw const FormatException('Encrypted history is not a list.');
      }

      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: true);
    } on VentingSecurityException {
      rethrow;
    } catch (_) {
      throw const VentingSecurityException(
        'تعذر فك تشفير سجل الفضفضة أو التحقق من سلامته. لم نستخدم النسخة القديمة تلقائيًا.',
      );
    }
  }

  Future<void> _writeEncryptedHistory(
    List<Map<String, dynamic>> messages,
    Uint8List key,
  ) async {
    final file = await _historyFile();
    final temp = File('${file.path}.tmp');
    final backup = File('${file.path}.bak');

    final clearBytes = utf8.encode(jsonEncode(messages));
    final encrypted = await _cipher.encrypt(
      clearBytes,
      secretKey: _requireSecretKey(),
      aad: utf8.encode(_historyAad),
    );

    final envelope = <String, dynamic>{
      'version': _formatVersion,
      'nonce': base64Encode(encrypted.nonce),
      'cipherText': base64Encode(encrypted.cipherText),
      'mac': base64Encode(encrypted.mac.bytes),
    };

    await temp.writeAsString(jsonEncode(envelope), flush: true);

    var movedOldFile = false;
    try {
      if (await backup.exists()) {
        await backup.delete();
      }
      if (await file.exists()) {
        await file.rename(backup.path);
        movedOldFile = true;
      }

      await temp.rename(file.path);
      await _readEncryptedHistory(key, fileOverride: file);

      if (movedOldFile && await backup.exists()) {
        await backup.delete();
      }
    } catch (_) {
      if (await file.exists()) {
        await file.delete();
      }
      if (movedOldFile && await backup.exists()) {
        await backup.rename(file.path);
      }
      if (await temp.exists()) {
        await temp.delete();
      }
      rethrow;
    }
  }

  Future<File> _historyFile() async {
    final supportDirectory = await getApplicationSupportDirectory();
    final directory = Directory(
      '${supportDirectory.path}${Platform.pathSeparator}secure_venting',
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return File(
      '${directory.path}${Platform.pathSeparator}history.v1.enc',
    );
  }

  static Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  static List<int> _decodeRequired(dynamic value) {
    if (value is! String || value.isEmpty) {
      throw const FormatException('Missing encrypted field.');
    }
    return base64Decode(value);
  }

  static void _validatePin(String pin) {
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      throw const VentingSecurityException(
        'الرقم السري لازم يكون 6 أرقام بالضبط.',
      );
    }
  }
}

class VentingSecurityException implements Exception {
  const VentingSecurityException(this.message);

  final String message;

  @override
  String toString() => message;
}
