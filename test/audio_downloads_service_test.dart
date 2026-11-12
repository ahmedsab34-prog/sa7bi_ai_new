import 'package:flutter_test/flutter_test.dart';
import 'package:sa7bi_ai/services/audio_downloads_service.dart';

void main() {
  group('AudioDownloadsService URL validation', () {
    test('accepts a direct HTTPS audio URL', () {
      expect(
        AudioDownloadsService.isSupportedSourceUrl(
          'https://cdn.example.com/audio/episode.mp3',
        ),
        isTrue,
      );
    });

    test('accepts HTTPS URLs with query parameters', () {
      expect(
        AudioDownloadsService.isSupportedSourceUrl(
          'https://cdn.example.com/audio/episode.mp3?token=abc123',
        ),
        isTrue,
      );
    });

    test('rejects insecure HTTP URLs', () {
      expect(
        AudioDownloadsService.isSupportedSourceUrl(
          'http://cdn.example.com/audio/episode.mp3',
        ),
        isFalse,
      );
    });

    test('rejects live and playlist formats', () {
      const urls = [
        'https://radio.example.com/live.m3u8',
        'https://radio.example.com/list.m3u',
        'https://radio.example.com/channel.pls',
        'https://radio.example.com/stream.mpd',
      ];

      for (final url in urls) {
        expect(
          AudioDownloadsService.isSupportedSourceUrl(url),
          isFalse,
          reason: 'يجب رفض رابط قائمة التشغيل: $url',
        );
      }
    });

    test('rejects malformed and local file URLs', () {
      const urls = [
        '',
        'not-a-url',
        '/storage/emulated/0/Music/song.mp3',
        'file:///storage/emulated/0/Music/song.mp3',
        'https:///missing-host.mp3',
      ];

      for (final url in urls) {
        expect(
          AudioDownloadsService.isSupportedSourceUrl(url),
          isFalse,
          reason: 'يجب رفض الرابط غير الصالح: $url',
        );
      }
    });

    test('rejects URLs containing embedded credentials', () {
      expect(
        AudioDownloadsService.isSupportedSourceUrl(
          'https://user:password@example.com/audio.mp3',
        ),
        isFalse,
      );
    });
  });
}
