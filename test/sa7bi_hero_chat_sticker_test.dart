import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sa7bi_ai/models/sa7bi_hero_chat_sticker.dart';
import 'package:sa7bi_ai/models/social_sticker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Sa7bi AI chat sticker tokens', () {
    test('all GIF and 3D stickers round-trip with unique IDs', () {
      final seen = <String>{};
      for (final sticker in Sa7biHeroChatStickerCatalog.all) {
        expect(seen.add(sticker.id), isTrue);
        final restored = Sa7biHeroChatSticker.tryParse(
          sticker.toMessageText(),
        );
        expect(restored, isNotNull);
        expect(restored!.id, sticker.id);
        expect(restored.type, sticker.type);
        expect(restored.animationName, sticker.animationName);
      }
      expect(Sa7biHeroChatStickerCatalog.animatedGifs, hasLength(9));
      expect(Sa7biHeroChatStickerCatalog.threeDimensional, hasLength(9));
    });

    test('ordinary text, malformed data, and unknown IDs are rejected', () {
      expect(Sa7biHeroChatSticker.tryParse('عامل إيه يا صاحبي؟'), isNull);
      expect(
        Sa7biHeroChatSticker.tryParse(
          '${Sa7biHeroChatSticker.messagePrefix}not-base64',
        ),
        isNull,
      );
      expect(
        Sa7biHeroChatSticker.tryParse(
          '${Sa7biHeroChatSticker.messagePrefix}eyJ2ZXJzaW9uIjoxLCJzdGlja2VySWQiOiJ1bmtub3duIn0',
        ),
        isNull,
      );
    });

    test('all nine animated sticker files are bundled valid GIFs', () async {
      for (final sticker in Sa7biHeroChatStickerCatalog.animatedGifs) {
        final data = await rootBundle.load(sticker.assetPath);
        expect(data.lengthInBytes, greaterThan(1000));
        expect(data.getUint8List(0, 3), <int>[0x47, 0x49, 0x46]);
      }
    });

    test('3D stickers refer only to supported model animation clips', () {
      const bodyClips = <String>{
        'Hero_Idle',
        'Hero_Welcome',
        'Hero_Power',
      };
      const faceClips = <String>{
        'HERO_FACE_SMILE',
        'HERO_FACE_SAD',
        'HERO_FACE_SURPRISE',
        'HERO_FACE_ANGRY',
        'HERO_FACE_WINK',
        'HERO_FACE_BLINK',
      };
      final allowed = <String>{...bodyClips, ...faceClips};
      for (final sticker in Sa7biHeroChatStickerCatalog.threeDimensional) {
        expect(allowed, contains(sticker.animationName));
      }
    });

    test('legacy static stickers remain available', () {
      expect(Sa7biStickerCatalog.all, hasLength(100));
      final legacy = Sa7biStickerCatalog.all.first;
      expect(Sa7biSticker.tryParse(legacy.toMessageText())?.id, legacy.id);
    });
  });
}
