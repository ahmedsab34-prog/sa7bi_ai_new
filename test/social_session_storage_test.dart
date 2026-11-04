import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sa7bi_ai/services/social_session_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const legacyKey = SocialSessionStorage.legacyPreferencesKey;
  const secureKey = SocialSessionStorage.secureStorageKey;

  final storage = SocialSessionStorage.instance;
  final secureStorage = FlutterSecureStorage();

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('Social session secure storage', () {
    test(
      'migrates the legacy token and removes plaintext only after verification',
      () async {
        SharedPreferences.setMockInitialValues(
          <String, Object>{legacyKey: 'legacy-session-token'},
        );

        final token = await storage.readToken();

        expect(token, 'legacy-session-token');
        expect(
          await secureStorage.read(key: secureKey),
          'legacy-session-token',
        );

        final preferences = await SharedPreferences.getInstance();
        expect(preferences.containsKey(legacyKey), isFalse);
      },
    );

    test('writes and reads a new token securely', () async {
      await storage.writeToken('new-session-token');

      expect(await storage.readToken(), 'new-session-token');
      expect(
        await secureStorage.read(key: secureKey),
        'new-session-token',
      );

      final preferences = await SharedPreferences.getInstance();
      expect(preferences.containsKey(legacyKey), isFalse);
    });

    test('deletes both secure and legacy session values', () async {
      SharedPreferences.setMockInitialValues(
        <String, Object>{legacyKey: 'old-token'},
      );

      await storage.readToken();
      await storage.deleteToken();

      expect(
        await secureStorage.read(key: secureKey),
        isNull,
      );
      expect(await storage.readToken(), isNull);

      final preferences = await SharedPreferences.getInstance();
      expect(preferences.containsKey(legacyKey), isFalse);
    });
  });
}
