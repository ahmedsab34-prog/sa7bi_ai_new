import 'package:flutter/material.dart';

import 'social_connections_screen.dart';
import 'social_groups_workspace_screen.dart';
import 'theme/sa7bi_theme.dart';
import 'widgets/sa7bi_subpage_app_bar.dart';

/// الصفحة الرئيسية لصاحبي Connect.
/// تجمع الشات الخاص والمجموعات العامة والخاصة في مدخل واحد.
class SocialConnectHubScreen extends StatelessWidget {
  const SocialConnectHubScreen({super.key});

  void _openPrivateChats(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const SocialConnectionsScreen(),
      ),
    );
  }

  void _openGroups(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const SocialGroupsWorkspaceScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Sa7biTheme.background,
        appBar: const Sa7biSubpageAppBar(
          title: 'صاحبي Connect',
          subtitle: 'تواصل مع أصحابك وشاركهم المجموعات',
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(13, 16, 13, 28),
            children: [
              const Text(
                'كل تواصلك في مكان واحد',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Sa7biTheme.textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'اختار محادثة خاصة أو استكشف المجتمعات العامة ومجموعاتك الخاصة.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Sa7biTheme.textSecondary,
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              _ConnectDestinationCard(
                title: 'المحادثات والأصدقاء',
                subtitle: 'تواصل مباشر مع الأشخاص',
                description:
                    'ابحث عن أصحابك، افتح محادثة خاصة، تابع الرسائل الجديدة، '
                    'شارك الاستيكرات وأرسل دعوات الألعاب.',
                icon: Icons.forum_rounded,
                color: Sa7biTheme.cyan,
                buttonText: 'افتح المحادثات',
                onPressed: () => _openPrivateChats(context),
              ),
              const SizedBox(height: 14),
              _ConnectDestinationCard(
                title: 'المجموعات والمجتمعات',
                subtitle: 'عامة وخاصة بالدعوة',
                description:
                    'اكتشف المجموعات العامة، أنشئ مجموعة خاصة، انضم برمز دعوة، '
                    'وأدر أعضاء مجموعاتك وصلاحيات المشرفين.',
                icon: Icons.groups_rounded,
                color: Sa7biTheme.success,
                buttonText: 'افتح المجموعات',
                onPressed: () => _openGroups(context),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Sa7biTheme.surfaceRaised,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Sa7biTheme.border),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: Sa7biTheme.textSecondary,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'المحادثات والمجموعات محمية بصلاحيات الحساب والعضوية. '
                        'الرسائل في النسخة الحالية ليست مشفرة من طرف إلى طرف، '
                        'ولا تشمل مكالمات صوت أو فيديو أو إرسال ملفات اجتماعية.',
                        style: TextStyle(
                          color: Sa7biTheme.textSecondary,
                          fontSize: 10,
                          height: 1.65,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConnectDestinationCard extends StatelessWidget {
  const _ConnectDestinationCard({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.color,
    required this.buttonText,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color color;
  final String buttonText;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Sa7biTheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withValues(alpha: 0.38),
            width: 1.2,
          ),
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              color.withValues(alpha: 0.13),
              Sa7biTheme.surface,
              Sa7biTheme.surface,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 51,
                  height: 51,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: color.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Icon(icon, color: color, size: 27),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Sa7biTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            Text(
              description,
              style: const TextStyle(
                color: Sa7biTheme.textSecondary,
                height: 1.6,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.arrow_back_rounded, size: 17),
              label: Text(
                buttonText,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
