import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores the shared social/games account token in Android Keystore-backed
/// secure storage. On first read it migrates the legacy SharedPreferences
/// value, verifies the secure write, and only then removes the old value.
class SocialSessionStorage {
  SocialSessionStorage._();

  static final SocialSessionStorage instance = SocialSessionStorage._();

  /// Legacy key used by previous Sa7bi AI builds.
  static const String legacyPreferencesKey =
      'sa7bi_social_games_session_token';

  /// New secure-storage key. This key name is not a secret.
  static const String secureStorageKey = 'sa7bi_social_session_token_v1';

  final FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: false),
  );

  Future<void> _operationTail = Future<void>.value();

  Future<T> _exclusive<T>(Future<T> Function() operation) {
    final previous = _operationTail;
    final gate = Completer<void>();
    _operationTail = gate.future;

    return _runExclusive(previous, gate, operation);
  }

  Future<T> _runExclusive<T>(
    Future<void> previous,
    Completer<void> gate,
    Future<T> Function() operation,
  ) async {
    try {
      await previous;
      return await operation();
    } finally {
      gate.complete();
    }
  }

  /// Reads the secure token, migrating the previous plaintext preference
  /// when needed. A failed secure write never deletes the legacy token.
  Future<String?> readToken() {
    return _exclusive(() async {
      final preferences = await SharedPreferences.getInstance();
      final secureToken =
          await _secureStorage.read(key: secureStorageKey);

      if (secureToken != null && secureToken.isNotEmpty) {
        if (preferences.containsKey(legacyPreferencesKey)) {
          await preferences.remove(legacyPreferencesKey);
        }
        return secureToken;
      }

      final legacyToken =
          preferences.getString(legacyPreferencesKey);

      if (legacyToken == null || legacyToken.isEmpty) {
        return null;
      }

      await _secureStorage.write(
        key: secureStorageKey,
        value: legacyToken,
      );

      final verifiedToken =
          await _secureStorage.read(key: secureStorageKey);

      if (verifiedToken != legacyToken) {
        throw StateError(
          'Social session migration could not be verified.',
        );
      }

      await preferences.remove(legacyPreferencesKey);
      return verifiedToken;
    });
  }

  /// Persists a newly authenticated token securely and verifies the write
  /// before removing any legacy copy.
  Future<void> writeToken(String token) {
    return _exclusive(() async {
      if (token.isEmpty) {
        throw ArgumentError.value(
          token,
          'token',
          'A social session token cannot be empty.',
        );
      }

      await _secureStorage.write(
        key: secureStorageKey,
        value: token,
      );

      final verifiedToken =
          await _secureStorage.read(key: secureStorageKey);

      if (verifiedToken != token) {
        throw StateError(
          'Social session secure-storage write could not be verified.',
        );
      }

      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(legacyPreferencesKey);
    });
  }

  /// Deletes the secure token and any leftover legacy copy.
  Future<void> deleteToken() {
    return _exclusive(() async {
      await _secureStorage.delete(key: secureStorageKey);
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(legacyPreferencesKey);
    });
  }
}
