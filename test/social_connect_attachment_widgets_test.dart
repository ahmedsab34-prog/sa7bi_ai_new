
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sa7bi_ai/widgets/social_connect_attachment_controls.dart';
import 'package:sa7bi_ai/widgets/social_connect_attachment_message.dart';

void main() {
  group('SocialConnectAttachmentControls content types', () {
    test('maps supported image extensions', () {
      expect(
        SocialConnectAttachmentControls
            .contentTypeForFileName('photo.JPG'),
        'image/jpeg',
      );

      expect(
        SocialConnectAttachmentControls
            .contentTypeForFileName('avatar.png'),
        'image/png',
      );

      expect(
        SocialConnectAttachmentControls
            .contentTypeForFileName('animation.gif'),
        'image/gif',
      );

      expect(
        SocialConnectAttachmentControls
            .contentTypeForFileName('image.webp'),
        'image/webp',
      );
    });

    test('maps supported audio, document and text extensions', () {
      expect(
        SocialConnectAttachmentControls
            .contentTypeForFileName('voice.m4a'),
        'audio/mp4',
      );

      expect(
        SocialConnectAttachmentControls
            .contentTypeForFileName('voice.aac'),
        'audio/aac',
      );

      expect(
        SocialConnectAttachmentControls
            .contentTypeForFileName('voice.mp3'),
        'audio/mpeg',
      );

      expect(
        SocialConnectAttachmentControls
            .contentTypeForFileName('voice.ogg'),
        'audio/ogg',
      );

      expect(
        SocialConnectAttachmentControls
            .contentTypeForFileName('document.pdf'),
        'application/pdf',
      );

      expect(
        SocialConnectAttachmentControls
            .contentTypeForFileName('notes.txt'),
        'text/plain',
      );
    });

    test('rejects unsupported or missing extensions', () {
      expect(
        SocialConnectAttachmentControls
            .contentTypeForFileName('program.exe'),
        isNull,
      );

      expect(
        SocialConnectAttachmentControls
            .contentTypeForFileName('README'),
        isNull,
      );

      expect(
        SocialConnectAttachmentControls
            .contentTypeForFileName('photo.'),
        isNull,
      );
    });
  });

  testWidgets(
    'attachment message view keeps ordinary text readable',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SocialConnectAttachmentMessageView(
              messageText: 'أهلًا يا صاحبي',
            ),
          ),
        ),
      );

      expect(
        find.text('أهلًا يا صاحبي'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'malformed attachment envelopes fall back to normal text',
    (tester) async {
      const malformed =
          'SA7BI_ATTACHMENT_V1:not-valid-data';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SocialConnectAttachmentMessageView(
              messageText: malformed,
            ),
          ),
        ),
      );

      expect(
        find.text(malformed),
        findsOneWidget,
      );
    },
  );
}
