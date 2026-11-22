import 'package:flutter/material.dart';

import '../ai_service.dart';
import '../theme/sa7bi_theme.dart';
import 'sa7bi_glass_surface.dart';

/// بطاقة خبر موحدة للرئيسية.
///
/// لا تتولى البطاقة جلب الأخبار أو فتح الروابط؛
/// الشاشة الأم مسؤولة عن ذلك.
class HomeNewsCard extends StatelessWidget {
  const HomeNewsCard({
    super.key,
    required this.item,
    required this.index,
    required this.publishedLabel,
    required this.onTap,
  });

  final NewsItem item;
  final int index;
  final String publishedLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = item.title.trim().isEmpty
        ? 'خبر ${index + 1}'
        : item.title.trim();

    final source = item.source.trim().isEmpty
        ? 'مصدر إخباري'
        : item.source.trim();

    final description = item.description.trim().isEmpty
        ? 'اضغط لقراءة تفاصيل الخبر.'
        : item.description.trim();

    final imageUrl = item.imageUrl.trim();

    return Semantics(
      button: true,
      label: 'خبر: $title',
      child: Sa7biGlassSurface(
        padding: EdgeInsets.zero,
        radius: 19,
        showGlow: false,
        borderColor: Sa7biTheme.border,
        onTap: onTap,
        child: SizedBox(
          height: 154,
          child: Row(
            textDirection: TextDirection.rtl,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 116,
                child: ClipRRect(
                  borderRadius: const BorderRadiusDirectional.only(
                    topStart: Radius.circular(18),
                    bottomStart: Radius.circular(18),
                  ),
                  child: imageUrl.isEmpty
                      ? const _NewsImagePlaceholder()
                      : Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (
                            context,
                            error,
                            stackTrace,
                          ) {
                            return const _NewsImagePlaceholder();
                          },
                          loadingBuilder: (
                            context,
                            child,
                            progress,
                          ) {
                            if (progress == null) return child;

                            return const _NewsImagePlaceholder(
                              loading: true,
                            );
                          },
                        ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    11,
                    10,
                    11,
                    9,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.public_rounded,
                            color: Sa7biTheme.cyan,
                            size: 13,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              source,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Sa7biTheme.cyan,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          textDirection: TextDirection.rtl,
                          style: const TextStyle(
                            color: Sa7biTheme.textPrimary,
                            fontSize: 12,
                            height: 1.45,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Text(
                        description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Sa7biTheme.textSecondary,
                          fontSize: 9.5,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule_rounded,
                            color: Sa7biTheme.textMuted,
                            size: 11,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              publishedLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Sa7biTheme.textMuted,
                                fontSize: 9,
                              ),
                            ),
                          ),
                          const Text(
                            'اقرأ الخبر',
                            style: TextStyle(
                              color: Sa7biTheme.goldBright,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Icon(
                            Icons.arrow_back_rounded,
                            color: Sa7biTheme.goldBright,
                            size: 13,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeNewsSectionHeader extends StatelessWidget {
  const HomeNewsSectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.refreshing,
    required this.onRefresh,
  });

  final String title;
  final String subtitle;
  final bool refreshing;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 39,
          height: 39,
          decoration: BoxDecoration(
            gradient: Sa7biTheme.violetGradient,
            borderRadius: BorderRadius.circular(13),
            boxShadow: [
              BoxShadow(
                color: Sa7biTheme.violet.withValues(alpha: 0.18),
                blurRadius: 12,
              ),
            ],
          ),
          child: const Icon(
            Icons.newspaper_rounded,
            color: Colors.white,
            size: 21,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Sa7biTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Sa7biTheme.textMuted,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        IconButton(
          tooltip: 'تحديث الأخبار',
          onPressed: refreshing ? null : onRefresh,
          icon: refreshing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Sa7biTheme.goldBright,
                  ),
                )
              : const Icon(
                  Icons.refresh_rounded,
                  color: Sa7biTheme.goldBright,
                  size: 22,
                ),
        ),
      ],
    );
  }
}

class _NewsImagePlaceholder extends StatelessWidget {
  const _NewsImagePlaceholder({
    this.loading = false,
  });

  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color(0xFF28365A),
            Color(0xFF171B35),
            Color(0xFF10182A),
          ],
        ),
      ),
      child: loading
          ? const SizedBox(
              width: 21,
              height: 21,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Sa7biTheme.cyan,
              ),
            )
          : const Icon(
              Icons.newspaper_rounded,
              color: Sa7biTheme.blueBright,
              size: 31,
            ),
    );
  }
}
