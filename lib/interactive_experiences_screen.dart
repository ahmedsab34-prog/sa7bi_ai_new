import 'dart:async';

import 'package:flutter/material.dart';

import 'achievements_screen.dart';
import 'local_games_hub_screen.dart';
import 'services/social_guest_session_service.dart';
import 'social_ai_games_screen.dart';
import 'social_games_hub_screen.dart';
import 'social_groups_screen.dart';
import 'theme/sa7bi_theme.dart';
import 'widgets/sa7bi_subpage_app_bar.dart';

class InteractiveExperiencesScreen extends StatefulWidget {
  const InteractiveExperiencesScreen({
    super.key,
    this.onShareResult,
  });

  final ValueChanged<String>? onShareResult;

  @override
  State<InteractiveExperiencesScreen> createState() =>
      _InteractiveExperiencesScreenState();
}

class _InteractiveExperiencesScreenState
    extends State<InteractiveExperiencesScreen> {
  bool _onlineReady = false;
  bool _checkingOnline = true;
  String? _onlineError;

  @override
  void initState() {
    super.initState();
    unawaited(_initializeOnlineSession());
  }

  Future<void> _initializeOnlineSession() async {
    if (mounted) {
      setState(() {
        _checkingOnline = true;
        _onlineError = null;
      });
    }

    try {
      await SocialGuestSessionService.instance.ensureSession().timeout(
        const Duration(seconds: 18),
      );
      if (!mounted) return;
      setState(() {
        _onlineReady = true;
        _checkingOnline = false;
        _onlineError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _onlineReady = false;
        _checkingOnline = false;
        _onlineError = 'الألعاب الجماعية تحتاج اتصالًا بالإنترنت. الألعاب المحلية تعمل بدون اتصال.';
      });
    }
  }

  Future<void> _open(Widget screen) async {
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  void _showOnlineUnavailable() {
    final message = _checkingOnline
        ? 'جاري تجهيز اتصال الألعاب.'
        : (_onlineError ?? 'اتصال الألعاب غير متاح حاليًا.');
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, textDirection: TextDirection.rtl),
          behavior: SnackBarBehavior.floating,
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
          title: 'الألعاب والتواصل',
          subtitle: 'اختار تجربتك وابدأ مع صاحبي AI',
        ),
        body: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 100),
          children: [
            _buildWelcomeCard(),
            const SizedBox(height: 20),
            const _SectionHeading(
              title: 'ألعابك وإنجازاتك',
              subtitle: 'ألعاب محلية سريعة، وتقدم محفوظ على جهازك',
            ),
            const SizedBox(height: 10),
            _ExperienceCard(
              icon: Icons.sports_esports_rounded,
              title: 'ألعاب بدون إنترنت',
              description: 'الذاكرة و2048 وخمن الرقم واختبر معلوماتك.',
              color: Sa7biTheme.cyan,
              tag: '4 ألعاب محلية',
              onTap: () => _open(const LocalGamesHubScreen()),
            ),
            _ExperienceCard(
              icon: Icons.emoji_events_rounded,
              title: 'إنجازاتي',
              description: 'تابع الألعاب التي بدأتَها والأسئلة الصحيحة والإنجازات التي فتحتها.',
              color: Sa7biTheme.violet,
              tag: 'حفظ محلي',
              onTap: () => _open(const AchievementsScreen()),
            ),
            const SizedBox(height: 14),
            const _SectionHeading(
              title: 'اللعب والتواصل أونلاين',
              subtitle: 'تحتاج اتصالًا صالحًا بخدمات صاحبي',
            ),
            const SizedBox(height: 10),
            if (!_onlineReady)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: Sa7biTheme.surfaceRaised,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: Sa7biTheme.border),
                ),
                child: Row(
                  children: [
                    if (_checkingOnline)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      const Icon(Icons.cloud_off_rounded, color: Sa7biTheme.textSecondary),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        _checkingOnline ? 'جاري تجهيز حساب اللعب...' : (_onlineError ?? 'الاتصال غير متاح.'),
                        style: const TextStyle(
                          color: Sa7biTheme.textSecondary,
                          fontSize: 10,
                          height: 1.5,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'إعادة المحاولة',
                      visualDensity: VisualDensity.compact,
                      onPressed: _checkingOnline ? null : _initializeOnlineSession,
                      icon: const Icon(Icons.refresh_rounded, color: Sa7biTheme.cyan),
                    ),
                  ],
                ),
              ),
            _ExperienceCard(
              icon: Icons.smart_toy_rounded,
              title: 'العب ضد صاحبي AI',
              description: 'إكس أو وحجر ورقة مقص والشطرنج مع مبارياتك المحفوظة.',
              color: Sa7biTheme.blue,
              tag: 'ذكاء اصطناعي',
              onTap: _onlineReady ? () => _open(const SocialAiGamesScreen()) : _showOnlineUnavailable,
            ),
            _ExperienceCard(
              icon: Icons.people_alt_rounded,
              title: 'العب مع أصحابك',
              description: 'أنشئ مباراة وشارك رمز الدعوة أو انضم إلى مباراة قائمة.',
              color: Sa7biTheme.violet,
              tag: 'تحديات مباشرة',
              onTap: _onlineReady
                  ? () => _open(SocialGamesHubScreen(onShareInvite: widget.onShareResult))
                  : _showOnlineUnavailable,
            ),
            _ExperienceCard(
              icon: Icons.groups_rounded,
              title: 'المجموعات العامة',
              description: 'اكتشف المجموعات وانضم للنقاشات وشارك اهتماماتك.',
              color: Sa7biTheme.success,
              tag: 'مجتمع صاحبي',
              onTap: _onlineReady ? () => _open(const SocialGroupsScreen()) : _showOnlineUnavailable,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: Sa7biTheme.surface,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Sa7biTheme.border),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.save_outlined, color: Sa7biTheme.cyan, size: 20),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'الألعاب المحلية لا تحتاج حسابًا أو إنترنت. الغرف الجماعية الحالية ما زالت تستخدم الألعاب الثلاث المدعومة من الخادم.',
                      style: TextStyle(
                        color: Sa7biTheme.textSecondary,
                        fontSize: 10,
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(21),
        gradient: Sa7biTheme.premiumGradient,
        border: Border.all(color: Sa7biTheme.cyan.withValues(alpha: 0.20)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: const Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'وقتك مع صاحبي أحلى',
                  style: TextStyle(
                    color: Sa7biTheme.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 7),
                Text(
                  'العب، اتحدى أصحابك، واجمع إنجازاتك خطوة بخطوة.',
                  style: TextStyle(
                    color: Sa7biTheme.textSecondary,
                    fontSize: 11,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 10),
          Icon(Icons.extension_rounded, color: Sa7biTheme.cyan, size: 48),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
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
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: Sa7biTheme.textSecondary,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _ExperienceCard extends StatelessWidget {
  const _ExperienceCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.tag,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final String tag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Sa7biTheme.surface,
      margin: const EdgeInsets.only(bottom: 9),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(17),
        side: BorderSide(color: Sa7biTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withValues(alpha: 0.25)),
                ),
                child: Icon(icon, color: color, size: 25),
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
                      description,
                      style: const TextStyle(
                        color: Sa7biTheme.textSecondary,
                        fontSize: 10,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tag,
                      style: TextStyle(
                        color: color,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_left_rounded, color: color, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
