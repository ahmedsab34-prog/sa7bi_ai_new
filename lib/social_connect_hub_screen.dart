
import 'package:flutter/material.dart';

import 'interactive_experiences_screen.dart';
import 'sa7bi_hero_3d_screen.dart';
import 'social_connections_screen.dart';
import 'social_groups_workspace_screen.dart';
import 'social_public_chat_screen.dart';
import 'theme/sa7bi_theme.dart';
import 'widgets/sa7bi_glass_surface.dart';
import 'widgets/sa7bi_subpage_app_bar.dart';

/// صفحة صاحبي Connect الرئيسية.
class SocialConnectHubScreen extends StatelessWidget {
  const SocialConnectHubScreen({super.key});

  void _openPublicChat(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const SocialPublicChatScreen(),
      ),
    );
  }

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

  void _openGames(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        settings: const RouteSettings(
          name: '/interactive-experiences',
        ),
        builder: (_) => const InteractiveExperiencesScreen(),
      ),
    );
  }

  void _openHero(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        settings: const RouteSettings(
          name: '/sa7bi-hero-3d',
        ),
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
          subtitle: 'تواصل مع أصحابك في مكان واحد',
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(15, 17, 15, 30),
            children: [
              _buildIntro(),
              const SizedBox(height: 19),

              _ConnectDestinationCard(
                title: 'الغرفة العامة',
                subtitle: 'كل أصحاب صاحبي في مكان واحد',
                description:
                    'ادخل الغرفة العامة المشتركة، وتابع الرسائل '
                    'وشارك أصحاب التطبيق الحديث.',
                icon: Icons.public_rounded,
                color: Sa7biTheme.cyan,
                tag: 'مجتمع صاحبي',
                buttonText: 'افتح الشات العام',
                onPressed: () => _openPublicChat(context),
              ),
              const SizedBox(height: 13),

              _ConnectDestinationCard(
                title: 'محادثاتي الخاصة',
                subtitle: 'تواصل مباشر مع أصدقائك',
                description:
                    'ابحث عن أصحابك، وافتح محادثاتك الخاصة، '
                    'وتابع الرسائل وحالة الاتصال.',
                icon: Icons.forum_rounded,
                color: Sa7biTheme.blueBright,
                tag: 'محادثات شخصية',
                buttonText: 'افتح المحادثات',
                onPressed: () => _openPrivateChats(context),
              ),
              const SizedBox(height: 13),

              _ConnectDestinationCard(
                title: 'المجموعات',
                subtitle: 'مجتمعات عامة ومجموعات خاصة',
                description:
                    'استكشف المجتمعات العامة، وأنشئ مجموعاتك '
                    'الخاصة، وادعُ أصحابك للانضمام.',
                icon: Icons.groups_rounded,
                color: Sa7biTheme.success,
                tag: 'مجتمعات وأصدقاء',
                buttonText: 'استكشف المجموعات',
                onPressed: () => _openGroups(context),
              ),
              const SizedBox(height: 13),

              _ConnectDestinationCard(
                title: 'مركز الألعاب',
                subtitle: 'ألعاب فردية وجماعية وتحديات ذكاء اصطناعي',
                description:
                    'العب الذاكرة و2048 وخمن الرقم واختبر معلوماتك، '
                    'أو ادخل مباريات الشطرنج وإكس أو وحجر ورقة مقص '
                    'وتحديات أصحابك.',
                icon: Icons.sports_esports_rounded,
                color: Sa7biTheme.violet,
                tag: 'ألعاب وتحديات',
                buttonText: 'افتح الألعاب',
                onPressed: () => _openGames(context),
              ),
              const SizedBox(height: 17),

              _HeroPreviewCard(
                onPressed: () => _openHero(context),
              ),
              const SizedBox(height: 17),

              const _ConnectSafetyNotice(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntro() {
    return Sa7biGlassSurface(
      padding: const EdgeInsets.fromLTRB(17, 20, 17, 19),
      radius: 23,
      showGlow: true,
      gradient: Sa7biTheme.premiumGradient,
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: Sa7biTheme.brandGradient,
              boxShadow: [
                BoxShadow(
                  color: Sa7biTheme.violet.withValues(alpha: 0.25),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.forum_rounded,
              color: Colors.white,
              size: 29,
            ),
          ),
          const SizedBox(height: 13),
          const Text(
            'كل أصحابك أقرب',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Sa7biTheme.textPrimary,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'مكان واحد للمحادثات والأصدقاء والمجموعات والألعاب '
            'والتواصل مع مجتمع صاحبي.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Sa7biTheme.textSecondary,
              fontSize: 12,
              height: 1.7,
            ),
          ),
        ],
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
    required this.tag,
    required this.buttonText,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color color;
  final String tag;
  final String buttonText;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Sa7biGlassSurface(
      padding: const EdgeInsets.all(15),
      radius: 21,
      borderColor: color.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: color.withValues(alpha: 0.28),
                  ),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 27,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Sa7biTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
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
              Icon(
                Icons.arrow_back_ios_new_rounded,
                color: color,
                size: 16,
              ),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            description,
            style: const TextStyle(
              color: Sa7biTheme.textSecondary,
              fontSize: 11,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: onPressed,
                style: FilledButton.styleFrom(
                  backgroundColor: color.withValues(alpha: 0.18),
                  foregroundColor: color,
                  elevation: 0,
                  minimumSize: const Size(0, 39),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                  ),
                  side: BorderSide(
                    color: color.withValues(alpha: 0.35),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      buttonText,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Icon(
                      Icons.arrow_back_rounded,
                      size: 15,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroPreviewCard extends StatelessWidget {
  const _HeroPreviewCard({
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Sa7biGlassSurface(
      padding: const EdgeInsets.all(14),
      radius: 21,
      borderColor: Sa7biTheme.borderGold,
      gradient: Sa7biTheme.wineGradient,
      onTap: onPressed,
      child: Row(
        children: [
          Container(
            width: 51,
            height: 51,
            decoration: BoxDecoration(
              color: Sa7biTheme.gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Sa7biTheme.gold.withValues(alpha: 0.35),
              ),
            ),
            child: const Icon(
              Icons.shield_rounded,
              color: Sa7biTheme.goldBright,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'صاحبي HERO',
                  style: TextStyle(
                    color: Sa7biTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'شخصية صاحبي الرئيسية',
                  style: TextStyle(
                    color: Sa7biTheme.goldBright,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Sa7biTheme.goldBright,
            size: 16,
          ),
        ],
      ),
    );
  }
}

class _ConnectSafetyNotice extends StatelessWidget {
  const _ConnectSafetyNotice();

  @override
  Widget build(BuildContext context) {
    return Sa7biGlassSurface(
      padding: const EdgeInsets.all(13),
      radius: 16,
      borderColor: Sa7biTheme.border,
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.security_rounded,
            color: Sa7biTheme.gold,
            size: 19,
          ),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'حافظ على خصوصيتك. لا تشارك كلمات المرور أو '
              'البيانات الحساسة. المحادثات في هذه النسخة '
              'ليست مشفرة من طرف إلى طرف.',
              style: TextStyle(
                color: Sa7biTheme.textSecondary,
                fontSize: 10,
                height: 1.7,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
