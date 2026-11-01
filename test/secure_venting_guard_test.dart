import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sa7bi_ai/config/service_keys.dart';
import 'package:sa7bi_ai/secure_venting_screen.dart';
import 'package:sa7bi_ai/services/chat_history_service.dart';
import 'package:sa7bi_ai/services/venting_security_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final security = VentingSecurityService.instance;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    security.lock();
  });

  tearDown(() {
    security.lock();
  });

  group('Private venting security guards', () {
    test('rejects PINs that are not exactly six digits', () async {
      for (final pin in <String>['', '12345', '1234567', '12a456']) {
        await expectLater(
          security.setupPin(pin),
          throwsA(isA<VentingSecurityException>()),
          reason: 'PIN "$pin" must be rejected before vault setup.',
        );
      }

      expect(security.isUnlocked, isFalse);
    });

    test('locked venting history is not reported as an empty conversation',
        () async {
      await expectLater(
        ChatHistoryService.instance.load(ServiceKeys.venting),
        throwsA(isA<VentingSecurityException>()),
      );

      expect(security.isUnlocked, isFalse);
    });

    test('saving private history is rejected while the vault is locked',
        () async {
      await expectLater(
        ChatHistoryService.instance.save(
          ServiceKeys.venting,
          <Map<String, dynamic>>[
            <String, dynamic>{'text': 'must not be saved while locked'},
          ],
        ),
        throwsA(isA<VentingSecurityException>()),
      );

      expect(security.isUnlocked, isFalse);
    });

    testWidgets('does not mount the private chat before the vault is opened',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SecureVentingScreen(
            child: Text('PRIVATE_VENTING_CHILD_SENTINEL'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('فضفضة سرية'), findsOneWidget);
      expect(find.text('أنشئ قفل الفضفضة'), findsOneWidget);
      expect(find.text('PRIVATE_VENTING_CHILD_SENTINEL'), findsNothing);
    });
  });
}
