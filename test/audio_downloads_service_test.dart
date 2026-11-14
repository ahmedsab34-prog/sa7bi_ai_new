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

    test('rejects URLs containing embedded credentials', () {
      expect(
        AudioDownloadsService.isSupportedSourceUrl(
          'https://user:password@example.com/audio.mp3',
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
        'https://radio.example.com/channel.asx',
        'https://radio.example.com/channel.ism',
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
  });

  group('DownloadedAudio serialization', () {
    test('preserves all metadata after JSON round trip', () {
      final original = DownloadedAudio(
        id: 'audio-123',
        title: 'سورة البقرة',
        filePath: '/app/audio/audio-123.mp3',
        sourceUrl: 'https://cdn.example.com/audio/audio-123.mp3',
        sizeBytes: 1024,
        downloadedAt: DateTime.fromMillisecondsSinceEpoch(
          1700000000000,
        ),
        artist: 'قارئ القرآن',
        album: 'القرآن الكريم',
        durationMs: 60000,
        artUri: 'https://cdn.example.com/cover.jpg',
      );

      final restored = DownloadedAudio.fromJson(
        original.toJson(),
      );

      expect(restored, isNotNull);
      expect(restored!.id, original.id);
      expect(restored.title, original.title);
      expect(restored.filePath, original.filePath);
      expect(restored.sourceUrl, original.sourceUrl);
      expect(restored.sizeBytes, original.sizeBytes);
      expect(restored.downloadedAt, original.downloadedAt);
      expect(restored.artist, original.artist);
      expect(restored.album, original.album);
      expect(restored.durationMs, original.durationMs);
      expect(restored.artUri, original.artUri);
    });

    test('accepts optional metadata as null', () {
      final item = DownloadedAudio.fromJson({
        'id': 'audio-456',
        'title': 'ملف صوتي',
        'filePath': '/app/audio/audio-456.mp3',
        'sourceUrl': 'https://cdn.example.com/audio/file.mp3',
        'sizeBytes': 500,
        'downloadedAt': 1700000000000,
      });

      expect(item, isNotNull);
      expect(item!.artist, isNull);
      expect(item.album, isNull);
      expect(item.durationMs, isNull);
      expect(item.artUri, isNull);
    });

    test('rejects malformed stored metadata', () {
      expect(
        DownloadedAudio.fromJson({
          'id': 123,
          'title': 'ملف',
        }),
        isNull,
      );
    });

    test('rejects a non-map value', () {
      expect(
        DownloadedAudio.fromJson('invalid'),
        isNull,
      );

      expect(
        DownloadedAudio.fromJson(null),
        isNull,
      );
    });
  });
}
