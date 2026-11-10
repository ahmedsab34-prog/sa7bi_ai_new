import 'package:flutter/material.dart';

import 'services/achievements_service.dart';
import 'theme/sa7bi_theme.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  late Future<List<AchievementProgress>> _progress;

  @override
  void initState() {
    super.initState();
    _progress = AchievementsService.instance.loadProgress();
  }

  Future<void> _refresh() async {
    setState(() {
      _progress = AchievementsService.instance.loadProgress();
    });
    await _progress;
  }

  IconData _iconFor(String name) {
    switch (name) {
      case 'sports_esports':
        return Icons.sports_esports_rounded;
      case 'emoji_events':
        return Icons.emoji_events_rounded;
      case 'quiz':
        return Icons.quiz_rounded;
      case 'school':
        return Icons.school_rounded;
      case 'psychology':
        return Icons.psychology_rounded;
      case 'grid_4x4':
        return Icons.apps_rounded;
      default:
        return Icons.military_tech_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Sa7biTheme.background,
        appBar: AppBar(
          title: const Text('إنجازاتي'),
          backgroundColor: Sa7biTheme.background,
          actions: [
            IconButton(
              tooltip: 'تحديث الإنجازات',
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: FutureBuilder<List<AchievementProgress>>(
          future: _progress,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('تعذر تحميل الإنجازات.'),
                    const SizedBox(height: 10),
                    FilledButton(
                      onPressed: _refresh,
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              );
            }

            final items = snapshot.data!;
            final unlocked = items.where((item) => item.unlocked).length;

            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
                children: [
                  Container(
                    padding: const EdgeInsets.all(17),
                    decoration: BoxDecoration(
                      gradient: Sa7biTheme.premiumGradient,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Sa7biTheme.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.emoji_events_rounded,
                          color: Sa7biTheme.cyan,
                          size: 34,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'رحلتك مع صاحبي',
                                style: TextStyle(
                                  color: Sa7biTheme.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$unlocked من ${items.length} إنجازات تم فتحها',
                                style: const TextStyle(
                                  color: Sa7biTheme.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  for (final item in items) ...[
                    _AchievementTile(
                      item: item,
                      icon: _iconFor(item.iconName),
                    ),
                    const SizedBox(height: 9),
                  ],
                  const SizedBox(height: 5),
                  const Text(
                    'تُحفظ أرقام الإنجازات على جهازك. لا يتم حفظ محتوى المحادثات ضمن هذا النظام.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Sa7biTheme.textSecondary,
                      fontSize: 10,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.item, required this.icon});

  final AchievementProgress item;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final unlocked = item.unlocked;
    final shownCurrent = item.current > item.target ? item.target : item.current;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Sa7biTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: unlocked ? Sa7biTheme.cyan.withValues(alpha: 0.38) : Sa7biTheme.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: Sa7biTheme.cyan.withValues(alpha: unlocked ? 0.16 : 0.07),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              unlocked ? icon : Icons.lock_outline_rounded,
              color: unlocked ? Sa7biTheme.cyan : Sa7biTheme.textSecondary,
              size: 22,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: Sa7biTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.description,
                  style: const TextStyle(
                    color: Sa7biTheme.textSecondary,
                    fontSize: 10,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: item.fraction,
                    minHeight: 5,
                    backgroundColor: Sa7biTheme.surfaceSoft,
                    color: unlocked ? Sa7biTheme.success : Sa7biTheme.cyan,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 9),
          Text(
            unlocked ? 'تم' : '$shownCurrent/${item.target}',
            style: TextStyle(
              color: unlocked ? Sa7biTheme.success : Sa7biTheme.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
