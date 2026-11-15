import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_screen.dart';
import 'config/service_keys.dart';
import 'profile_screen.dart';
import 'secure_venting_screen.dart';
import 'service_config.dart';
import 'services/social_games_service.dart';
import 'services/social_guest_session_service.dart';
import 'social_connect_hub_screen.dart';
import 'theme/sa7bi_theme.dart';
import 'widgets/app_header.dart';
import 'widgets/audio_center_with_header.dart';

class ChatTabScreen extends StatefulWidget {
  const ChatTabScreen({super.key});

  @override
  State<ChatTabScreen> createState() => _ChatTabScreenState();
}

class _ChatTabScreenState extends State<ChatTabScreen> {
  static const String _connectWelcomeKey =
      'sa7bi_connect_welcome_shown_v1';

  static const String _ventingWelcomeKey =
      'sa7bi_venting_welcome_shown_v1';

  bool _opening = false;

  String _ventingContext() {
    for (final service in sa7biServices) {
      if (service.serviceKey == ServiceKeys.venting) {
        return service.aiRole;
      }
    }

    return '''
أنت مساعد فضفضة خاص في تطبيق صاحبي AI.
استمع للمستخدم باحترام وبدون أحكام.
ساعده على ترتيب أفكاره واختيار خطوات عملية.
لا تدّعي أنك طبيب أو معالج.
حافظ على خصوصية المحادثة ولا تطلب بيانات حساسة.
''';
  }

  Future<void> _showWelcomeOnce({
    required String preferenceKey,
    required String message,
  }) async {
    try {
      final preferences = await SharedPreferences.getInstance();

      if (preferences.getBool(preferenceKey) == true) {
        return;
      }

      await preferences.setBool(preferenceKey, true);

      if (!mounted) return;

      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;

      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              message,
              textDirection: TextDirection.rtl,
              style: const TextStyle(
                color: Colors.white,
                height: 1.5,
              ),
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
    } catch (_) {
      // تعذر حفظ حالة الترحيب لا يمنع فتح الخدمة.
    }
  }

  Future<void> _openConnect() async {
    if (_opening) return;

    setState(() => _opening = true);

    await _showWelcomeOnce(
      preferenceKey: _connectWelcomeKey,
      message:
          'أهلًا بيك في صاحبي Connect. تواصل مع أصحابك في محادثات خاصة أو ادخل المجموعات العامة وشاركهم الكلام واللعب.',
    );

    try {
      // إنشاء أو استعادة جلسة الضيف قبل فتح Connect.
      await SocialGuestSessionService.instance.ensureSession();

      if (!mounted) return;

      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const SocialConnectHubScreen(),
        ),
      );
    } on SocialGamesException catch (error) {
      if (mounted) {
        _showMessage(error.message);
      }
    } catch (_) {
      if (mounted) {
        _showMessage(
          'تعذر فتح صاحبي Connect حاليًا. تحقق من الإنترنت وحاول مرة أخرى.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _opening = false);
      }
    }
  }

  Future<void> _openVenting() async {
    if (_opening) return;

    setState(() => _opening = true);

    await _showWelcomeOnce(
      preferenceKey: _ventingWelcomeKey,
      message:
          'أهلًا بيك في فضفضة. اتكلم براحتك مع صاحبي AI، واسأل أو فضفض أو اطلب نصيحة.',
    );

    if (!mounted) return;

    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            backgroundColor: Sa7biTheme.background,
            appBar: AppBar(
              backgroundColor: Sa7biTheme.background,
              foregroundColor: Sa7biTheme.textPrimary,
              elevation: 0,
              centerTitle: true,
              title: const Text(
                'فضفضة مع صاحبي',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              actions: [
                IconButton(
                  tooltip: 'مركز الصوت',
                  onPressed: _openAudioCenter,
                  icon: const Icon(Icons.headphones_rounded),
                ),
                IconButton(
                  tooltip: 'حسابي',
                  onPressed: _openProfile,
                  icon: const Icon(Icons.person_outline_rounded),
                ),
              ],
            ),
            body: SecureVentingScreen(
              child: ChatScreen(
                key: const ValueKey<String>(
                  'private-ai-venting-chat',
                ),
                serviceKey: ServiceKeys.venting,
                serviceTitle: 'فضفضة مع صاحبي',
                serviceContext: _ventingContext(),
                embedded: true,
                onProfileTap: _openProfile,
                onAudioTap: _openAudioCenter,
              ),
            ),
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        _showMessage('تعذر فتح الفضفضة حاليًا.');
      }
    } finally {
      if (mounted) {
        setState(() => _opening = false);
      }
    }
  }

  void _openProfile() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (profileContext) => ProfileScreen(
          onProfileTap: () {
            Navigator.of(profileContext).maybePop();
          },
          onAudio: _openAudioCenter,
        ),
      ),
    );
  }

  void _openAudioCenter() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AudioCenterWithHeader(
          onProfileTap: _openProfile,
        ),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted || message.trim().isEmpty) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            textDirection: TextDirection.rtl,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        children: [
          AppHeader(
            onProfileTap: _openProfile,
            onAudioTap: _openAudioCenter,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(13, 18, 13, 26),
              children: [
                const Text(
                  'المحادثات',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Sa7biTheme.textPrimary,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'اختار نوع المحادثة اللي يناسبك',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Sa7biTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 22),
                _ConversationServiceCard(
                  title: 'صاحبي Connect',
                  subtitle: 'للتواصل مع الأشخاص الحقيقيين',
                  description:
                      'رسائل خاصة، البحث عن الأصدقاء، المجموعات العامة، '
                      'ومتابعة دعوات الألعاب من مكان واحد.',
                  icon: Icons.people_alt_rounded,
                  color: Sa7biTheme.cyan,
                  buttonText: 'افتح صاحبي Connect',
                  onTap: _opening ? null : _openConnect,
                  loading: _opening,
                ),
                const SizedBox(height: 14),
                _ConversationServiceCard(
                  title: 'فضفضة مع صاحبي',
                  subtitle: 'محادثتك الشخصية مع الذكاء الاصطناعي',
                  description:
                      'فضفض واسأل واطلب نصيحة أو العب مع صاحبك الذكي. '
                      'المحادثة محمية بقفل الفضفضة على جهازك.',
                  icon: Icons.favorite_rounded,
                  color: Sa7biTheme.violet,
                  buttonText: 'ابدأ الفضفضة',
                  onTap: _opening ? null : _openVenting,
                  loading: _opening,
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
                        size: 17,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Connect للتواصل مع الناس، وفضفضة للمحادثة مع الذكاء الاصطناعي. كل خدمة لها محادثاتها المستقلة.',
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
        ],
      ),
    );
  }
}

class _ConversationServiceCard extends StatelessWidget {
  const _ConversationServiceCard({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.color,
    required this.buttonText,
    required this.onTap,
    required this.loading,
  });

  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color color;
  final String buttonText;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Sa7biTheme.surface,
      borderRadius: BorderRadius.circular(21),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(21),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(21),
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
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.08),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: color.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: 28,
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
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: color,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_left_rounded,
                    color: color,
                    size: 25,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                description,
                style: const TextStyle(
                  color: Sa7biTheme.textSecondary,
                  fontSize: 11,
                  height: 1.65,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 42,
                child: FilledButton.icon(
                  onPressed: onTap,
                  style: FilledButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Sa7biTheme.background,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  icon: loading
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Sa7biTheme.background,
                          ),
                        )
                      : const Icon(Icons.arrow_forward_rounded, size: 17),
                  label: Text(
                    buttonText,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
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
