
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sa7bi_ai/models/social_sticker.dart';

void main() {
  group('Sa7biSticker message codec', () {
    test('every catalog sticker encodes and restores correctly', () {
      for (final sticker in Sa7biStickerCatalog.all) {
        final restored = Sa7biSticker.tryParse(
          sticker.toMessageText(),
        );

        expect(
          restored,
          isNotNull,
          reason: 'Sticker ${sticker.id} did not restore.',
        );

        expect(restored!.id, sticker.id);
        expect(restored.packId, sticker.packId);
        expect(restored.packTitle, sticker.packTitle);
        expect(restored.emoji, sticker.emoji);
        expect(restored.title, sticker.title);
        expect(restored.caption, sticker.caption);
      }
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

    test('rejects unsupported sticker message versions', () {
      final encoded = base64Url.encode(
        utf8.encode(
          '{"version":2,"stickerId":"laugh"}',
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

  group('Sa7biStickerCatalog', () {
    test('contains exactly 100 stickers', () {
      expect(Sa7biStickerCatalog.all, hasLength(100));
    });

    test('all sticker IDs are unique', () {
      final ids = Sa7biStickerCatalog.all
          .map((sticker) => sticker.id)
          .toSet();

      expect(ids, hasLength(100));
    });

    test('contains all five expected sticker packs', () {
      expect(
        Sa7biStickerCatalog.packTitles,
        containsAll(<String>[
          'ضحك وهزار',
          'مشاعر',
          'ردود سريعة',
          'تشجيع ودعم',
          'تحيات',
        ]),
      );

      expect(Sa7biStickerCatalog.packTitles, hasLength(5));
    });

    test('each sticker pack contains 20 stickers', () {
      for (final pack in Sa7biStickerCatalog.packTitles) {
        expect(
          Sa7biStickerCatalog.forPack(pack),
          hasLength(20),
          reason: 'Pack "$pack" should contain 20 stickers.',
        );
      }
    });

    test('keeps the original sticker IDs compatible', () {
      const originalIds = <String>{
        'laugh',
        'lol',
        'silly',
        'oops',
        'prank',
        'facepalm',
        'love',
        'heart',
        'miss',
        'sad',
        'hug',
        'ok',
        'yes',
        'no',
        'wow',
        'thinking',
        'champ',
        'strong',
        'star',
        'rocket',
        'hello',
        'morning',
        'night',
        'thanks',
      };

      expect(
        Sa7biStickerCatalog.byId.keys,
        containsAll(originalIds),
      );
    });

    test('returns all stickers for the all filter', () {
      expect(
        Sa7biStickerCatalog.forPack('الكل').length,
        Sa7biStickerCatalog.all.length,
      );
    });

    test('returns only stickers from the selected pack', () {
      final stickers =
          Sa7biStickerCatalog.forPack('ضحك وهزار');

      expect(stickers, hasLength(20));
      expect(
        stickers.every(
          (sticker) => sticker.packTitle == 'ضحك وهزار',
        ),
        isTrue,
      );
    });

    test('returns an empty list for an unknown pack', () {
      expect(
        Sa7biStickerCatalog.forPack('حزمة غير موجودة'),
        isEmpty,
      );
    });
  });
}
