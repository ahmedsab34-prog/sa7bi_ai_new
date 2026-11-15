import 'package:flutter/material.dart';

class ShortVideoEntryCarousel extends StatelessWidget {
  const ShortVideoEntryCarousel({
    super.key,
    required this.onReelsTap,
    required this.onShortsTap,
  });

  final VoidCallback onReelsTap;
  final VoidCallback onShortsTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 112,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 2),
        children: [
          _ShortVideoEntryCard(
            title: 'ريلز المجتمع',
            subtitle: 'فيديوهات أصحابك ومقاطع المستخدمين',
            tag: 'SA7BI REELS',
            icon: Icons.video_library_rounded,
            accent: const Color(0xFF62D9FF),
            onTap: onReelsTap,
          ),
          const SizedBox(width: 10),
          _ShortVideoEntryCard(
            title: 'مقاطع قصيرة',
            subtitle: 'تمرير رأسي سريع • محتوى MP3Quran',
            tag: 'TIKTOK STYLE',
            icon: Icons.play_circle_fill_rounded,
            accent: const Color(0xFFFF6B9D),
            onTap: onShortsTap,
          ),
        ],
      ),
    );
  }
}

class _ShortVideoEntryCard extends StatelessWidget {
  const _ShortVideoEntryCard({
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String tag;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 232,
      child: Material(
        color: const Color(0xFF151D2C),
        borderRadius: BorderRadius.circular(17),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              border: Border.all(
                color: accent.withValues(alpha: 0.28),
              ),
              borderRadius: BorderRadius.circular(17),
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  accent.withValues(alpha: 0.13),
                  const Color(0xFF151D2C),
                  const Color(0xFF101725),
                ],
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: accent,
                    size: 27,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tag,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: accent,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 9,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 5),
                Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: accent,
                  size: 13,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
