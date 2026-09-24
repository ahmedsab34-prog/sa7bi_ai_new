import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../monetization_config.dart';

class AffiliateCarousel extends StatelessWidget {
  const AffiliateCarousel({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (!MonetizationConfig.affiliateEnabled ||
        !MonetizationConfig.affiliateCarouselEnabled) {
      return const SizedBox.shrink();
    }

    final stores = <_AffiliateStore>[
      _AffiliateStore(
        title: 'Amazon',
        subtitle: 'تسوق أونلاين',
        icon: Icons.shopping_cart_rounded,
        accent: const Color(0xFFFFA726),
        url: MonetizationConfig.amazonUrl,
      ),
      _AffiliateStore(
        title: 'Jumia',
        subtitle: 'عروض ومنتجات',
        icon: Icons.shopping_bag_rounded,
        accent: const Color(0xFF8E6BFF),
        url: MonetizationConfig.jumiaUrl,
      ),
      _AffiliateStore(
        title: 'Noon',
        subtitle: 'تسوق سريع',
        icon: Icons.storefront_rounded,
        accent: const Color(0xFFFFD76A),
        url: MonetizationConfig.noonUrl,
      ),
      _AffiliateStore(
        title: 'Facebook',
        subtitle: 'Marketplace',
        icon: Icons.facebook_rounded,
        accent: const Color(0xFF63B3FF),
        url: MonetizationConfig.facebookShopUrl,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // ========================================================
        // TITLE
        // ========================================================

        Row(
          textDirection: TextDirection.rtl,
          children: [
            const Icon(
              Icons.shopping_bag_rounded,
              color: Color(0xFFFFD76A),
              size: 21,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    MonetizationConfig.affiliateCarouselTitle,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    MonetizationConfig.affiliateCarouselSubtitle,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 11),

        // ========================================================
        // STORES
        // ========================================================

        SizedBox(
          height: 126,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            reverse: true,
            padding: const EdgeInsets.symmetric(
              horizontal: 2,
            ),
            physics: const BouncingScrollPhysics(),
            itemCount: stores.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: 10),
            itemBuilder: (
              context,
              index,
            ) {
              return _AffiliateStoreCard(
                store: stores[index],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ================================================================
// STORE MODEL
// ================================================================

class _AffiliateStore {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final String url;

  const _AffiliateStore({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.url,
  });
}

// ================================================================
// STORE CARD
// ================================================================

class _AffiliateStoreCard extends StatelessWidget {
  final _AffiliateStore store;

  const _AffiliateStoreCard({
    required this.store,
  });

  Future<void> _openStore(
    BuildContext context,
  ) async {
    final cleanUrl = store.url.trim();

    if (cleanUrl.isEmpty) {
      _showUnavailable(context);
      return;
    }

    final uri = Uri.tryParse(cleanUrl);

    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' &&
            uri.scheme != 'https')) {
      _showUnavailable(context);
      return;
    }

    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened) {
        _showUnavailable(context);
      }
    } catch (_) {
      _showUnavailable(context);
    }
  }

  void _showUnavailable(
    BuildContext context,
  ) {
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'رابط ${store.title} غير متاح حاليًا',
            textDirection: TextDirection.rtl,
          ),
          duration: const Duration(
            seconds: 2,
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 205,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _openStore(context);
          },
          borderRadius: BorderRadius.circular(21),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(21),
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  store.accent.withOpacity(0.25),
                  const Color(0xFF11151F),
                  const Color(0xFF0B0E15),
                ],
              ),
              border: Border.all(
                color: store.accent.withOpacity(0.35),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: store.accent.withOpacity(0.08),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.end,
                children: [
                  // ------------------------------------------------
                  // ICON + ARROW
                  // ------------------------------------------------

                  Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      Container(
                        width: 43,
                        height: 43,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                            colors: [
                              store.accent,
                              store.accent.withOpacity(0.35),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: store.accent.withOpacity(0.20),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Icon(
                          store.icon,
                          color: Colors.black,
                          size: 23,
                        ),
                      ),

                      const Spacer(),

                      const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white38,
                        size: 13,
                      ),
                    ],
                  ),

                  const Spacer(),

                  // ------------------------------------------------
                  // STORE NAME
                  // ------------------------------------------------

                  Text(
                    store.title,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),

                  const SizedBox(height: 2),

                  Text(
                    store.subtitle,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
