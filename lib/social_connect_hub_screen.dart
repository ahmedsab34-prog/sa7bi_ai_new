import 'package:flutter/material.dart';

import 'sa7bi_hero_3d_screen.dart';
import 'social_connections_screen.dart';
import 'social_groups_workspace_screen.dart';
import 'theme/sa7bi_theme.dart';
import 'widgets/sa7bi_subpage_app_bar.dart';

/// The Sa7bi Connect landing page.
/// HERO is the only 3D Sa7bi character shown in the app.
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

  void _openHero(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const Sa7biHero3DScreen(),
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
          subtitle: 'تواصل مع أصحابك ومع شخصية HERO الوحيدة لصاحبي',
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
              const SizedBox(height: 14),
              _HeroPreviewCard(onPressed: () => _openHero(context)),
              const SizedBox(height: 14),
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
                title: 'المجموعات العامة',
                subtitle: 'مجتمعات عامة ومجموعات خاصة بالدعوة',
                description:
                    'استكشف المجموعات العامة، أنشئ مجموعة خاصة، انضم برمز دعوة، '
                    'وأدر أعضاء مجموعاتك وصلاحيات المشرفين.',
                icon: Icons.groups_rounded,
                color: Sa7biTheme.success,
                buttonText: 'استكشف المجموعات',
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
                        'المجموعات هنا عامة للاكتشاف والانضمام، أما مجموعاتك الخاصة '
                        'فتظل بالدعوة فقط. الرسائل محمية بصلاحيات الحساب والعضوية، '
                        'لكنها ليست مشفرة من طرف إلى طرف في هذه النسخة، ولا تشمل '
                        'مكالمات صوت أو فيديو أو إرسال ملفات اجتماعية حتى الآن.',
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

class _HeroPreviewCard extends StatelessWidget {
  const _HeroPreviewCard({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _CharacterPreviewCard(
      title: 'صاحبي HERO',
      subtitle: 'البطل الخارق الوحيد بشعار التطبيق الأصلي المضيء على الصدر',
      icon: Icons.shield_rounded,
      color: const Color(0xFFFFB84D),
      onPressed: onPressed,
    );
  }
}

class _CharacterPreviewCard extends StatelessWidget {
  const _CharacterPreviewCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Sa7biTheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.38)),
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                color.withValues(alpha: 0.14),
                const Color(0xFF101827),
              ],
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(15),
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
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Sa7biTheme.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_back_ios_new_rounded,
                color: color,
                size: 17,
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
