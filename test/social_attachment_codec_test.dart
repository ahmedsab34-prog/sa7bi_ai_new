import 'package:flutter_test/flutter_test.dart';
import 'package:sa7bi_ai/services/social_attachment_service.dart';

void main() {
  group('SocialAttachmentMessageCodec', () {
    const attachment = SocialAttachment(
      id: '11111111-1111-4111-8111-111111111111',
      fileName: 'voice_note.m4a',
      contentType: 'audio/mp4',
      sizeBytes: 24576,
      createdAt: 1760000000000,
    );

    test('encodes and restores an attachment with its caption', () {
      final encoded = SocialAttachmentMessageCodec.encode(
        attachment,
        caption: 'اسمع الرسالة دي',
      );

      final decoded = SocialAttachmentMessageCodec.decode(encoded);

      expect(decoded, isNotNull);
      expect(decoded!.attachment.id, attachment.id);
      expect(decoded.attachment.fileName, attachment.fileName);
      expect(decoded.attachment.contentType, 'audio/mp4');
      expect(decoded.attachment.sizeBytes, 24576);
      expect(decoded.caption, 'اسمع الرسالة دي');
    });

    test('does not treat an ordinary chat message as an attachment', () {
      expect(
        SocialAttachmentMessageCodec.decode('أهلًا يا صاحبي'),
        isNull,
      );
    });

    test('rejects a malformed or truncated envelope safely', () {
      expect(
        SocialAttachmentMessageCodec.decode(
          '${SocialAttachmentMessageCodec.prefix}not-base64-json',
        ),
        isNull,
      );
    });

    test('rejects an envelope without a valid attachment identity', () {
      final invalid = SocialAttachment(
        id: 'not-an-attachment-id',
        fileName: 'file.pdf',
        contentType: 'application/pdf',
        sizeBytes: 100,
        createdAt: 1,
      );

      final encoded = SocialAttachmentMessageCodec.encode(invalid);
      expect(SocialAttachmentMessageCodec.decode(encoded), isNull);
    });

    test('bounds caption text to 500 characters', () {
      final encoded = SocialAttachmentMessageCodec.encode(
        attachment,
        caption: 'أ' * 700,
      );

      final decoded = SocialAttachmentMessageCodec.decode(encoded);
      expect(decoded, isNotNull);
      expect(decoded!.caption.length, 500);
    });
  });
}
