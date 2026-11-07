import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'social_games_service.dart';

/// Creates and restores an automatic guest account for social features.
///
/// Guest credentials are stored in Android secure storage. The normal
/// social session token continues to be managed by SocialGamesService.
class SocialGuestSessionService {
  SocialGuestSessionService._();

  static final SocialGuestSessionService instance =
      SocialGuestSessionService._();

  static const String _usernameKey = 'sa7bi_guest_username_v1';
  static const String _passwordKey = 'sa7bi_guest_password_v1';

  final FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: false),
  );

  final SocialGamesService _games = SocialGamesService.instance;

  Future<void>? _pendingEnsure;

  /// Ensures that a valid social session exists.
  ///
  /// A valid existing account is preserved. If the saved token expired,
  /// saved guest credentials are restored. A new guest is created only
  /// when no usable account or guest credentials exist.
  Future<void> ensureSession() {
    final pending = _pendingEnsure;
    if (pending != null) return pending;

    final task = _ensureSession();
    _pendingEnsure = task;

    return task.whenComplete(() {
      if (identical(_pendingEnsure, task)) {
        _pendingEnsure = null;
      }
    });
  }

  Future<void> _ensureSession() async {
    await _games.initialize();

    if (_games.isSignedIn) {
      try {
        await _games.getCurrentUser();
        return;
      } on SocialGamesException catch (error) {
        if (error.code != 'SESSION_EXPIRED' &&
            error.code != 'AUTH_REQUIRED') {
          rethrow;
        }

        await _games.logout();
      }
    }

    final savedUsername = await _storage.read(key: _usernameKey);
    final savedPassword = await _storage.read(key: _passwordKey);

    if (savedUsername != null &&
        savedUsername.isNotEmpty &&
        savedPassword != null &&
        savedPassword.isNotEmpty) {
      try {
        await _games.login(
          username: savedUsername,
          password: savedPassword,
        );
        return;
      } on SocialGamesException catch (error) {
        if (error.code != 'INVALID_CREDENTIALS') {
          rethrow;
        }

        await _clearGuestCredentials();
      }
    }

    await _createGuestAccount();
  }

  Future<void> _createGuestAccount() async {
    for (var attempt = 0; attempt < 3; attempt++) {
      final username = 'guest_${_secureHex(8)}';
      final password = _secureHex(32);

      try {
        await _games.register(
          username: username,
          password: password,
        );

        await _storage.write(
          key: _usernameKey,
          value: username,
        );
        await _storage.write(
          key: _passwordKey,
          value: password,
        );

        final verifiedUsername =
            await _storage.read(key: _usernameKey);
        final verifiedPassword =
            await _storage.read(key: _passwordKey);

        if (verifiedUsername != username ||
            verifiedPassword != password) {
          throw StateError(
            'Guest credentials could not be verified in secure storage.',
          );
        }

        return;
      } on SocialGamesException catch (error) {
        if (error.code != 'USERNAME_TAKEN' || attempt == 2) {
          rethrow;
        }
      }
    }

    throw const SocialGamesException(
      'GUEST_ACCOUNT_FAILED',
      'تعذر إنشاء حساب الضيف تلقائيًا. حاول مرة أخرى.',
    );
  }

  Future<void> _clearGuestCredentials() async {
    await _storage.delete(key: _usernameKey);
    await _storage.delete(key: _passwordKey);
  }

  String _secureHex(int byteLength) {
    final random = Random.secure();

    return List<String>.generate(
      byteLength,
      (_) => random
          .nextInt(256)
          .toRadixString(16)
          .padLeft(2, '0'),
      growable: false,
    ).join();
  }
}
