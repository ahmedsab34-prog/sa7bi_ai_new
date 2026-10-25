
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/ai_service_models.dart';

/// خدمات البحث الصوتي والبودكاست.
class AiMediaService {
  AiMediaService._();

  static const String audioSearchEndpoint =
      AppConfig.audioSearchEndpoint;
  static const String base = AppConfig.backendBaseUrl;
  static const String podcastsSearchEndpoint =
      '$base/v1/podcasts/search';
  static const String podcastsLookupEndpoint =
      '$base/v1/podcasts/lookup';
  static const String podcastsEpisodesEndpoint =
      '$base/v1/podcasts/episodes';

  static Future<List<AudioSearchItem>> searchAudio(
    String query, {
    String type = 'quran',
  }) async {
    final clean = query.trim();
    if (clean.isEmpty) return [];

    try {
      final uri = Uri.parse(audioSearchEndpoint).replace(
        queryParameters: {'q': clean, 'type': type},
      );

      final response = await http.get(
        uri,
        headers: const {
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
        },
      ).timeout(const Duration(seconds: 25));

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        return [];
      }

      final data = _decodeMap(response.body);
      if (data == null || data['items'] is! List) {
        return [];
      }

      final result = <AudioSearchItem>[];

      for (final raw in data['items'] as List) {
        if (raw is! Map) continue;

        final item = AudioSearchItem(
          id: raw['id']?.toString() ?? '',
          title: raw['title']?.toString() ?? '',
          artist: raw['artist']?.toString(),
          url: (
            raw['url'] ??
            raw['previewUrl'] ??
            raw['streamUrl'] ??
            ''
          ).toString(),
          type: raw['type']?.toString() ?? type,
          artwork: (
            raw['artwork'] ??
            raw['artworkUrl'] ??
            raw['image'] ??
            ''
          ).toString(),
          storeUrl: raw['storeUrl']?.toString() ?? '',
          text: raw['text']?.toString() ?? '',
          repeat: raw['repeat']?.toString() ?? '',
          collection: raw['collection']?.toString() ?? '',
          feedUrl: raw['feedUrl']?.toString() ?? '',
        );

        if (item.title.trim().isNotEmpty) {
          result.add(item);
        }
      }

      return result;
    } catch (_) {
      return [];
    }
  }

  static Future<List<PodcastItem>> searchPodcasts({
    String query = '',
    int limit = 20,
  }) async {
    final clean = query.trim();

    try {
      final uri = Uri.parse(
        podcastsSearchEndpoint,
      ).replace(
        queryParameters: {
          'q': clean.isEmpty ? 'Arabic podcast' : clean,
          'limit': limit.clamp(1, 50).toString(),
        },
      );

      final response = await http.get(uri).timeout(
        const Duration(seconds: 30),
      );

      final data = _decodeMap(response.body);

      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          data == null ||
          data['items'] is! List) {
        return [];
      }

      final result = <PodcastItem>[];

      for (final raw in data['items'] as List) {
        if (raw is! Map) continue;

        final id = (
          raw['id'] ??
          raw['collectionId'] ??
          ''
        ).toString().trim();

        final title = (
          raw['title'] ??
          raw['collectionName'] ??
          raw['name'] ??
          ''
        ).toString().trim();

        if (title.isEmpty) continue;

        result.add(
          PodcastItem(
            id: id,
            title: title,
            artist: (
              raw['artist'] ??
              raw['artistName'] ??
              raw['author'] ??
              ''
            ).toString(),
            author: (
              raw['author'] ??
              raw['artist'] ??
              raw['artistName'] ??
              ''
            ).toString(),
            artwork: (
              raw['artwork'] ??
              raw['artworkUrl'] ??
              raw['artworkUrl600'] ??
              raw['image'] ??
              ''
            ).toString(),
            feedUrl: (
              raw['feedUrl'] ??
              raw['feed_url'] ??
              ''
            ).toString(),
            storeUrl: (
              raw['storeUrl'] ??
              raw['collectionViewUrl'] ??
              raw['trackViewUrl'] ??
              ''
            ).toString(),
            genre: raw['genre']?.toString() ?? '',
            country: raw['country']?.toString() ?? '',
            releaseDate: raw['releaseDate']?.toString() ?? '',
            episodeCount: int.tryParse(
                  (
                    raw['episodeCount'] ??
                    raw['trackCount'] ??
                    raw['collectionCount'] ??
                    0
                  ).toString(),
                ) ??
                0,
            description: raw['description']?.toString() ?? '',
          ),
        );
      }

      return result;
    } catch (_) {
      return [];
    }
  }

  static Future<PodcastItem?> getPodcast(String id) async {
    final clean = id.trim();
    if (clean.isEmpty) return null;

    try {
      final uri = Uri.parse(
        podcastsLookupEndpoint,
      ).replace(
        queryParameters: {'id': clean},
      );

      final response = await http.get(uri).timeout(
        const Duration(seconds: 30),
      );

      final data = _decodeMap(response.body);

      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          data == null) {
        return null;
      }

      final raw = data['podcast'] ?? data['item'];
      if (raw is! Map) return null;

      final title = (
        raw['title'] ??
        raw['collectionName'] ??
        raw['name'] ??
        ''
      ).toString().trim();

      if (title.isEmpty) return null;

      return PodcastItem(
        id: (
          raw['id'] ??
          raw['collectionId'] ??
          clean
        ).toString(),
        title: title,
        artist: (
          raw['artist'] ??
          raw['artistName'] ??
          raw['author'] ??
          ''
        ).toString(),
        author: (
          raw['author'] ??
          raw['artist'] ??
          raw['artistName'] ??
          ''
        ).toString(),
        artwork: (
          raw['artwork'] ??
          raw['artworkUrl'] ??
          raw['artworkUrl600'] ??
          raw['image'] ??
          ''
        ).toString(),
        feedUrl: (
          raw['feedUrl'] ??
          raw['feed_url'] ??
          ''
        ).toString(),
        storeUrl: (
          raw['storeUrl'] ??
          raw['collectionViewUrl'] ??
          raw['trackViewUrl'] ??
          ''
        ).toString(),
        genre: raw['genre']?.toString() ?? '',
        country: raw['country']?.toString() ?? '',
        releaseDate: raw['releaseDate']?.toString() ?? '',
        episodeCount: int.tryParse(
              (
                raw['episodeCount'] ??
                raw['trackCount'] ??
                raw['collectionCount'] ??
                0
              ).toString(),
            ) ??
            0,
        description: raw['description']?.toString() ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  static Future<List<PodcastEpisode>> getPodcastEpisodes({
    required String feedUrl,
    int limit = 100,
  }) async {
    final clean = feedUrl.trim();
    if (clean.isEmpty || !_isHttpUrl(clean)) return [];

    try {
      final uri = Uri.parse(
        podcastsEpisodesEndpoint,
      ).replace(
        queryParameters: {
          'feedUrl': clean,
          'limit': limit.clamp(1, 100).toString(),
        },
      );

      final response = await http.get(uri).timeout(
        const Duration(seconds: 30),
      );

      final data = _decodeMap(response.body);

      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          data == null ||
          data['items'] is! List) {
        return [];
      }

      final result = <PodcastEpisode>[];

      for (final raw in data['items'] as List) {
        if (raw is! Map) continue;

        final title = (
          raw['title'] ??
          raw['name'] ??
          ''
        ).toString().trim();

        final audioUrl = (
          raw['audioUrl'] ??
          raw['audio_url'] ??
          raw['url'] ??
          ''
        ).toString().trim();

        if (title.isEmpty ||
            audioUrl.isEmpty ||
            !_isHttpUrl(audioUrl)) {
          continue;
        }

        result.add(
          PodcastEpisode(
            id: (
              raw['id'] ??
              raw['guid'] ??
              ''
            ).toString(),
            title: title,
            description: raw['description']?.toString() ?? '',
            audioUrl: audioUrl,
            image: (
              raw['image'] ??
              raw['artwork'] ??
              raw['artworkUrl'] ??
              ''
            ).toString(),
            publishedAt: (
              raw['publishedAt'] ??
              raw['pubDate'] ??
              ''
            ).toString(),
            duration: raw['duration']?.toString() ?? '',
            episode: int.tryParse(
                  raw['episode']?.toString() ?? '',
                ) ??
                0,
            season: int.tryParse(
                  raw['season']?.toString() ?? '',
                ) ??
                0,
            explicit: raw['explicit'] == true,
          ),
        );
      }

      return result;
    } catch (_) {
      return [];
    }
  }

  static Map<String, dynamic>? _decodeMap(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static bool _isHttpUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https');
  }
}
