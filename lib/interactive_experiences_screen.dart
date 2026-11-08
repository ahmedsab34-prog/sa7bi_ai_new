
import 'package:flutter/material.dart';

import 'services/social_guest_session_service.dart';
import 'social_ai_games_screen.dart';
import 'social_games_hub_screen.dart';
import 'social_groups_screen.dart';
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
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await SocialGuestSessionService.instance.ensureSession();

      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error =
            'تعذر تجهيز حساب الألعاب تلقائيًا. تحقق من الإنترنت وحاول مرة أخرى.';
      });
    }
  }

  Future<void> _retry() async {
    if (!mounted || _loading) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    await _initialize();
  }

  Future<void> _open(Widget screen) async {
    if (!mounted || _loading || _error != null) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => screen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF080B13),
        appBar: const Sa7biSubpageAppBar(
          title: 'الألعاب والتواصل',
          subtitle: 'اختار تجربتك وابدأ مع صاحبي AI',
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: _loading
              ? _buildLoading()
              : _error != null
                  ? _buildError()
                  : _buildOptions(),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      key: ValueKey('loading'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Color(0xFFFFD76A),
            ),
          ),
          SizedBox(height: 16),
          Text(
            'جاري تجهيز حسابك...',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'لحظات ونكون جاهزين للعب',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      key: const ValueKey('error'),
      child: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: const Color(0x22FFB45C),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0x55FFB45C),
                ),
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 38,
                color: Color(0xFFFFB45C),
              ),
            ),
            const SizedBox(height: 17),
            const Text(
              'مش قادرين نجهز اللعب دلوقتي',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white60,
                height: 1.6,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _retry,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFFD76A),
                foregroundColor: const Color(0xFF171717),
                padding: const EdgeInsets.symmetric(
                  horizontal: 23,
                  vertical: 12,
                ),
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text(
                'إعادة المحاولة',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptions() {
    return ListView(
      key: const ValueKey('options'),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 100),
      children: [
        _buildWelcomeCard(),
        const SizedBox(height: 22),
        const _SectionHeading(
          title: 'اختار طريقة اللعب',
          subtitle: 'كل تجربة لها طريقتها الخاصة',
        ),
        const SizedBox(height: 12),
        _ExperienceCard(
          icon: Icons.smart_toy_rounded,
          title: 'العب ضد صاحبي AI',
          description:
              'تحدَّ الذكاء الاصطناعي في إكس أو وحجر ورقة مقص والشطرنج، وارجع لمبارياتك المحفوظة.',
          color: const Color(0xFF8EA8FF),
          tag: 'ذكاء اصطناعي',
          onTap: () => _open(const SocialAiGamesScreen()),
        ),
        _ExperienceCard(
          icon: Icons.people_alt_rounded,
          title: 'العب مع أصحابك',
          description:
              'أنشئ مباراة وشارك رمز الدعوة مع صاحبك أو انضم إلى مباراة موجودة.',
          color: const Color(0xFFFFD76A),
          tag: 'تحديات مباشرة',
          onTap: () => _open(
            SocialGamesHubScreen(
              onShareInvite: widget.onShareResult,
            ),
          ),
        ),
        _ExperienceCard(
          icon: Icons.groups_rounded,
          title: 'المجموعات العامة',
          description:
              'اكتشف المجموعات، انضم للنقاشات، وشارك اهتماماتك مع الآخرين.',
          color: const Color(0xFF63E6FF),
          tag: 'مجتمع صاحبي',
          onTap: () => _open(const SocialGroupsScreen()),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF101827),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.07),
            ),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.save_outlined,
                color: Color(0xFFFFD76A),
                size: 21,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'يتم تجهيز جلسة ضيف تلقائيًا على جهازك. حفظ المباريات والرجوع إليها يعتمد على نجاح الاتصال بخدمات الألعاب.',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(23),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color(0xFF293653),
            Color(0xFF171F32),
            Color(0xFF101522),
          ],
        ),
        border: Border.all(
          color: const Color(0x55FFD76A),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'وقتك مع صاحبي أحلى',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'العب، اتحدى أصحابك، وشارك في مجتمع صاحبي AI.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 13),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x22FFD76A),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0x55FFD76A),
                    ),
                  ),
                  child: const Text(
                    'جاهز للتحدي؟',
                    style: TextStyle(
                      color: Color(0xFFFFD76A),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFFE7A0),
                  Color(0xFFFFC94D),
                ],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x44FFD76A),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Icon(
              Icons.sports_esports_rounded,
              color: Color(0xFF182033),
              size: 39,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.subtitle,
  });

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
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
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
      color: const Color(0xFF111827),
      margin: const EdgeInsets.only(bottom: 11),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(19),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 51,
                height: 51,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: color.withValues(alpha: 0.25),
                  ),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 27,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
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
                  ],
                ),
              ),
              const SizedBox(width: 5),
              Icon(
                Icons.chevron_left_rounded,
                color: color.withValues(alpha: 0.9),
                size: 23,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
