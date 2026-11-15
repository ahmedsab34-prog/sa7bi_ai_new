import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sa7bi_ai/models/social_sticker.dart';

void main() {
  group('Sa7biSticker message codec', () {
    test('encodes and restores a known sticker', () {
      final sticker = Sa7biStickerCatalog.all.first;
      final restored = Sa7biSticker.tryParse(
        sticker.toMessageText(),
      );

      expect(restored, isNotNull);
      expect(restored!.id, sticker.id);
      expect(restored.caption, sticker.caption);
    });

    test('does not parse ordinary chat text', () {
      expect(
        Sa7biSticker.tryParse('عامل إيه يا صاحبي؟'),
        isNull,
      );
    });

    test('rejects malformed sticker payloads', () {
      expect(
        Sa7biSticker.tryParse(
          '${Sa7biSticker.messagePrefix}not-base64',
        ),
        isNull,
      );
    });

    test('rejects unknown sticker IDs', () {
      final encoded = base64Url.encode(
        utf8.encode(
          '{"version":1,"stickerId":"unknown-sticker"}',
        ),
      );

      expect(
        Sa7biSticker.tryParse(
          '${Sa7biSticker.messagePrefix}$encoded',
        ),
        isNull,
      );
    });
  });
}
