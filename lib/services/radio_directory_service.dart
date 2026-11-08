import 'dart:convert';

import '../ai_service.dart';
import '../config/app_config.dart';
import 'sa7bi_network_client.dart';
import 'storage_service.dart';

/// نتيجة تحميل المحطات.
/// fromCache=true تعني أن القائمة محفوظة محليًا
/// وليست نتيجة اتصال مباشر بالمصدر في هذه اللحظة.
class RadioStationsResult {
  final List<RadioStation> stations;
  final bool fromCache;

  const RadioStationsResult({
    required this.stations,
    required this.fromCache,
  });
}

/// نتيجة حل رابط المحطة قبل التشغيل.
class RadioResolvedStream {
  final String url;
  final bool registeredClick;

  const RadioResolvedStream({
    required this.url,
    required this.registeredClick,
  });
}

/// خدمة موحدة لمحطات الراديو في صاحبي AI.
class RadioDirectoryService {
  RadioDirectoryService._();

  static const int maximumStations = 100;

  static const String _favoritesKey =
      'sa7bi_radio_favorites_v1';

  static const String _cachePrefix =
      'sa7bi_radio_stations_v1_';

  static const Duration _requestTimeout =
      Duration(seconds: 25);

  static final StorageService _storage =
      StorageService.instance;

  // ============================================================
  // COUNTRIES
  // ============================================================

  static Future<List<RadioCountry>> getCountries() async {
    return AiService.getRadioCountries();
  }

  // ============================================================
  // STATIONS
  // ============================================================

  static Future<RadioStationsResult> loadStations(
    String country, {
    String query = '',
    int limit = maximumStations,
  }) async {
    final cleanCountry = country.trim();

    if (cleanCountry.isEmpty) {
      throw ArgumentError('Radio country is empty.');
    }

    final safeLimit =
        limit.clamp(1, maximumStations).toInt();

    final cleanQuery = query.trim();

    try {
      final stations = await _fetchStations(
        cleanCountry,
        query: cleanQuery,
        limit: safeLimit,
      );

      // لا نستبدل كاش الدولة بنتيجة بحث جزئية.
      if (cleanQuery.isEmpty) {
        await _saveCountryCache(
          cleanCountry,
          stations,
        );
      }

      return RadioStationsResult(
        stations: stations,
        fromCache: false,
      );
    } catch (_) {
      // البحث الجزئي لا يستخدم كاش القائمة الكاملة.
      if (cleanQuery.isNotEmpty) {
        rethrow;
      }

      final cached =
          await _readCountryCache(cleanCountry);

      if (cached == null) {
        rethrow;
      }

      return RadioStationsResult(
        stations: cached,
        fromCache: true,
      );
    }
  }

  static Future<List<RadioStation>> _fetchStations(
    String country, {
    required String query,
    required int limit,
  }) async {
    final parameters = <String, String>{
      'country': country,
      'limit': limit.toString(),
    };

    if (query.isNotEmpty) {
      parameters['q'] = query;
    }

    final uri = Uri.parse(
      AppConfig.radioStationsEndpoint,
    ).replace(
      queryParameters: parameters,
    );

    final response = await Sa7biNetworkClient.client
        .get(
          uri,
          headers: const {
            'Accept': 'application/json',
          },
        )
        .timeout(_requestTimeout);

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw Exception(
        'Radio stations request failed: HTTP ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map) {
      throw const FormatException(
        'Invalid radio response.',
      );
    }

    if (decoded['ok'] == false) {
      throw Exception(
        decoded['message']?.toString() ??
            decoded['error']?.toString() ??
            'Radio provider unavailable.',
      );
    }

    final rawStations = decoded['stations'];

    if (rawStations is! List) {
      throw const FormatException(
        'Radio response has no stations list.',
      );
    }

    final result = <RadioStation>[];
    final seen = <String>{};

    for (final raw in rawStations) {
      if (raw is! Map) {
        continue;
      }

      final name = (
        raw['name'] ??
        raw['title'] ??
        ''
      ).toString().trim();

      final streamUrl = (
        raw['streamUrl'] ??
        raw['url'] ??
        ''
      ).toString().trim();

      if (name.isEmpty || !_isHttpsUrl(streamUrl)) {
        continue;
      }

      final id = (
        raw['stationUuid'] ??
        raw['stationuuid'] ??
        raw['id'] ??
        ''
      ).toString().trim();

      final uniqueKey = id.isNotEmpty
          ? id
          : streamUrl.toLowerCase();

      if (!seen.add(uniqueKey)) {
        continue;
      }

      result.add(
        RadioStation(
          id: id,
          name: name,
          url: streamUrl,
          homepage: _safeOptionalUrl(
            raw['homepage']?.toString(),
          ),
          favicon: _safeOptionalUrl(
            (
              raw['favicon'] ??
              raw['logo'] ??
              ''
            ).toString(),
          ),
          tags: raw['tags']?.toString() ?? '',
          codec: raw['codec']?.toString() ?? '',
          bitrate: _asInt(raw['bitrate']),
        ),
      );

      if (result.length >= limit) {
        break;
      }
    }

    // نحافظ على ترتيب الشعبية القادم من المصدر.
    return result;
  }

  // ============================================================
  // FAVORITES
  // ============================================================

  static Future<List<RadioStation>> getFavorites() async {
    final saved =
        await _storage.getJsonList(_favoritesKey);

    if (saved == null) {
      return [];
    }

    final result = <RadioStation>[];

    for (final item in saved) {
      if (item is! Map) {
        continue;
      }

      try {
        final station = _stationFromMap(
          Map<String, dynamic>.from(item),
        );

        if (station != null) {
          result.add(station);
        }
      } catch (_) {
        // تجاهل العنصر التالف.
      }
    }

    return result;
  }

  static Future<bool> isFavorite(
    RadioStation station,
  ) async {
    final favorites = await getFavorites();

    return favorites.any(
      (item) => _sameStation(item, station),
    );
  }

  static Future<bool> toggleFavorite(
    RadioStation station,
  ) async {
    if (!_isHttpsUrl(station.url)) {
      return false;
    }

    final favorites = await getFavorites();

    final existingIndex = favorites.indexWhere(
      (item) => _sameStation(item, station),
    );

    if (existingIndex >= 0) {
      favorites.removeAt(existingIndex);
    } else {
      favorites.add(station);
    }

    return _storage.setJsonList(
      _favoritesKey,
      favorites.map(_stationToMap).toList(),
    );
  }

  static Future<bool> removeFavorite(
    RadioStation station,
  ) async {
    final favorites = await getFavorites();

    favorites.removeWhere(
      (item) => _sameStation(item, station),
    );

    return _storage.setJsonList(
      _favoritesKey,
      favorites.map(_stationToMap).toList(),
    );
  }

  // ============================================================
  // COUNTRY CACHE
  // ============================================================

  static Future<void> _saveCountryCache(
    String country,
    List<RadioStation> stations,
  ) async {
    await _storage.setJsonList(
      _cacheKey(country),
      stations.map(_stationToMap).toList(),
    );
  }

  static Future<List<RadioStation>?> _readCountryCache(
    String country,
  ) async {
    final saved = await _storage.getJsonList(
      _cacheKey(country),
    );

    if (saved == null) {
      return null;
    }

    final result = <RadioStation>[];

    for (final item in saved) {
      if (item is! Map) {
        continue;
      }

      try {
        final station = _stationFromMap(
          Map<String, dynamic>.from(item),
        );

        if (station != null) {
          result.add(station);
        }
      } catch (_) {
        // تجاهل المحطة التالفة.
      }
    }

    return result;
  }

  static String _cacheKey(String country) {
    final normalized = country
        .trim()
        .toLowerCase()
        .replaceAll(
          RegExp(r'[^a-z0-9_-]'),
          '_',
        );

    return '$_cachePrefix$normalized';
  }

  // ============================================================
  // STREAM RESOLUTION
  // ============================================================

  static Future<RadioResolvedStream> resolveStream(
    RadioStation station,
  ) async {
    final fallbackUrl = station.url.trim();

    if (!_isHttpsUrl(fallbackUrl)) {
      throw const FormatException(
        'Unsafe radio stream URL.',
      );
    }

    final stationId = station.id.trim();

    if (stationId.isEmpty) {
      return RadioResolvedStream(
        url: fallbackUrl,
        registeredClick: false,
      );
    }

    try {
      final uri = Uri.parse(
        '${AppConfig.backendBaseUrl}/v1/radio/station',
      ).replace(
        queryParameters: {
          'stationUuid': stationId,
        },
      );

      final response = await Sa7biNetworkClient.client
          .get(
            uri,
            headers: const {
              'Accept': 'application/json',
            },
          )
          .timeout(
            const Duration(seconds: 12),
          );

      if (response.statusCode >= 200 &&
          response.statusCode < 300) {
        final decoded = jsonDecode(response.body);

        if (decoded is Map &&
            decoded['ok'] == true) {
          final resolved = (
            decoded['streamUrl'] ??
            decoded['url'] ??
            ''
          ).toString().trim();

          if (_isHttpsUrl(resolved)) {
            return RadioResolvedStream(
              url: resolved,
              registeredClick: true,
            );
          }
        }
      }
    } catch (_) {
      // الرابط الأصلي يظل حلًا احتياطيًا.
    }

    return RadioResolvedStream(
      url: fallbackUrl,
      registeredClick: false,
    );
  }

  // ============================================================
  // SERIALIZATION
  // ============================================================

  static Map<String, dynamic> _stationToMap(
    RadioStation station,
  ) {
    return {
      'id': station.id,
      'name': station.name,
      'url': station.url,
      'homepage': station.homepage,
      'favicon': station.favicon,
      'tags': station.tags,
      'codec': station.codec,
      'bitrate': station.bitrate,
    };
  }

  static RadioStation? _stationFromMap(
    Map<String, dynamic> map,
  ) {
    final name =
        map['name']?.toString().trim() ?? '';

    final url =
        map['url']?.toString().trim() ?? '';

    if (name.isEmpty || !_isHttpsUrl(url)) {
      return null;
    }

    return RadioStation(
      id: map['id']?.toString() ?? '',
      name: name,
      url: url,
      homepage: map['homepage']?.toString() ?? '',
      favicon: map['favicon']?.toString() ?? '',
      tags: map['tags']?.toString() ?? '',
      codec: map['codec']?.toString() ?? '',
      bitrate: _asInt(map['bitrate']),
    );
  }

  // ============================================================
  // VALIDATION
  // ============================================================

  static bool _isHttpsUrl(String value) {
    final uri = Uri.tryParse(value.trim());

    return uri != null &&
        uri.scheme.toLowerCase() == 'https' &&
        uri.hasAuthority &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty;
  }

  static String _safeOptionalUrl(String? value) {
    final clean = value?.trim() ?? '';

    if (clean.isEmpty) {
      return '';
    }

    final uri = Uri.tryParse(clean);

    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'https' &&
            uri.scheme != 'http')) {
      return '';
    }

    return clean;
  }

  static int _asInt(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  static bool _sameStation(
    RadioStation first,
    RadioStation second,
  ) {
    if (first.id.isNotEmpty &&
        second.id.isNotEmpty) {
      return first.id == second.id;
    }

    return first.url.trim().toLowerCase() ==
        second.url.trim().toLowerCase();
  }
}
