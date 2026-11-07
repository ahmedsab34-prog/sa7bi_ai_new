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
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    await _initialize();
  }

  Future<void> _open(Widget screen) async {
    if (_loading || _error != null) return;

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
          subtitle: 'العب مع صاحبي AI أو مع أصحابك',
        ),
        body: _loading
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: Color(0xFFFFD76A),
                    ),
                    SizedBox(height: 14),
                    Text(
                      'جاري تجهيز حسابك...',
                      style: TextStyle(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              )
            : _error != null
                ? _buildError()
                : _buildOptions(),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: Colors.orangeAccent,
            ),
            const SizedBox(height: 14),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptions() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF26314D),
                Color(0xFF111827),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0x33FFD76A),
            ),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.sports_esports_rounded,
                color: Color(0xFFFFD76A),
                size: 34,
              ),
              SizedBox(height: 12),
              Text(
                'اختار طريقة اللعب',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'حساب الضيف يتم تجهيزه تلقائيًا، وتُحفظ جلسة اللعب على جهازك.',
                style: TextStyle(
                  color: Colors.white70,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _ExperienceCard(
          icon: Icons.smart_toy_rounded,
          title: 'العب ضد صاحبي AI',
          description:
              'مباريات فردية في إكس أو وحجر ورقة مقص والشطرنج.',
          color: const Color(0xFF8EA8FF),
          onTap: () => _open(
            const SocialAiGamesScreen(),
          ),
        ),
        _ExperienceCard(
          icon: Icons.people_alt_rounded,
          title: 'العب مع أصحابك',
          description:
              'أنشئ غرفة، شارك رمز الدعوة، واحفظ مبارياتك.',
          color: const Color(0xFFFFD76A),
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
              'اكتشف المجموعات، انضم للمحادثات، وأنشئ مجموعتك.',
          color: const Color(0xFF63E6FF),
          onTap: () => _open(
            const SocialGroupsScreen(),
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
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF111827),
      margin: const EdgeInsets.only(bottom: 11),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(17),
        side: const BorderSide(
          color: Colors.white10,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 10,
        ),
        onTap: onTap,
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            color: color,
            size: 27,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            description,
            style: const TextStyle(
              color: Colors.white60,
              height: 1.4,
              fontSize: 12,
            ),
          ),
        ),
        trailing: const Icon(
          Icons.chevron_left_rounded,
          color: Colors.white60,
        ),
      ),
    );
  }
}
