import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class MonetizationService {
  MonetizationService._();

  static final MonetizationService instance =
      MonetizationService._();

  Future<MonetizationConfigResponse?>
      fetchConfiguration() async {
    try {
      final response = await http
          .get(
            Uri.parse(
              AppConfig.monetizationEndpoint,
            ),
            headers: const {
              'Accept': 'application/json',
            },
          )
          .timeout(
            const Duration(
              seconds: 15,
            ),
          );

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        return null;
      }

      final decoded =
          jsonDecode(response.body);

      if (decoded is! Map) {
        return null;
      }

      final data =
          Map<String, dynamic>.from(
        decoded,
      );

      if (data['ok'] != true) {
        return null;
      }

      final monetization =
          data['monetization'];

      if (monetization is! Map) {
        return null;
      }

      return MonetizationConfigResponse
          .fromJson(
        Map<String, dynamic>.from(
          monetization,
        ),
      );
    } catch (_) {
      return null;
    }
  }
}

/* =========================================================
   RESPONSE
   ========================================================= */

class MonetizationConfigResponse {
  final bool dynamicConfig;
  final bool serverControlled;
  final bool affiliateEnabled;
  final bool sponsoredAdsEnabled;
  final int monetizedStores;
  final List<MonetizationStore> stores;
  final List<SponsoredAd> sponsoredAds;

  const MonetizationConfigResponse({
    required this.dynamicConfig,
    required this.serverControlled,
    required this.affiliateEnabled,
    required this.sponsoredAdsEnabled,
    required this.monetizedStores,
    required this.stores,
    required this.sponsoredAds,
  });

  factory MonetizationConfigResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawStores =
        json['stores'];

    final rawSponsoredAds =
        json['sponsoredAds'];

    final stores =
        <MonetizationStore>[];

    if (rawStores is List) {
      for (final item in rawStores) {
        if (item is Map) {
          try {
            stores.add(
              MonetizationStore.fromJson(
                Map<String, dynamic>.from(
                  item,
                ),
              ),
            );
          } catch (_) {}
        }
      }
    }

    final sponsoredAds =
        <SponsoredAd>[];

    if (rawSponsoredAds is List) {
      for (final item in rawSponsoredAds) {
        if (item is Map) {
          try {
            sponsoredAds.add(
              SponsoredAd.fromJson(
                Map<String, dynamic>.from(
                  item,
                ),
              ),
            );
          } catch (_) {}
        }
      }
    }

    return MonetizationConfigResponse(
      dynamicConfig:
          json['dynamic'] == true,
      serverControlled:
          json['serverControlled'] == true,
      affiliateEnabled:
          json['affiliateEnabled'] == true,
      sponsoredAdsEnabled:
          json['sponsoredAdsEnabled'] == true,
      monetizedStores:
          _toInt(
        json['monetizedStores'],
      ),
      stores: stores,
      sponsoredAds: sponsoredAds,
    );
  }

  static int _toInt(
    dynamic value,
  ) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }
}

/* =========================================================
   STORE
   ========================================================= */

class MonetizationStore {
  final String id;
  final String title;
  final String subtitle;
  final String icon;
  final String accent;
  final String url;
  final bool monetized;
  final String linkType;

  const MonetizationStore({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.url,
    required this.monetized,
    required this.linkType,
  });

  factory MonetizationStore.fromJson(
    Map<String, dynamic> json,
  ) {
    return MonetizationStore(
      id: _clean(
        json['id'],
      ),
      title: _clean(
        json['title'],
      ),
      subtitle: _clean(
        json['subtitle'],
      ),
      icon: _clean(
        json['icon'],
      ),
      accent: _clean(
        json['accent'],
      ),
      url: _clean(
        json['url'],
      ),
      monetized:
          json['monetized'] == true,
      linkType:
          _clean(
        json['linkType'],
      ),
    );
  }

  static String _clean(
    dynamic value,
  ) {
    return value?.toString().trim() ?? '';
  }
}

/* =========================================================
   SPONSORED AD
   ========================================================= */

class SponsoredAd {
  final String id;
  final String title;
  final String subtitle;
  final String imageUrl;
  final String url;
  final bool active;

  const SponsoredAd({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.url,
    required this.active,
  });

  factory SponsoredAd.fromJson(
    Map<String, dynamic> json,
  ) {
    return SponsoredAd(
      id:
          json['id']?.toString().trim() ?? '',
      title:
          json['title']?.toString().trim() ?? '',
      subtitle:
          json['subtitle']?.toString().trim() ?? '',
      imageUrl:
          json['imageUrl']?.toString().trim() ?? '',
      url:
          json['url']?.toString().trim() ?? '',
      active:
          json['active'] != false,
    );
  }
}
