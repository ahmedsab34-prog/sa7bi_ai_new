import 'package:flutter/material.dart';

import 'services/social_community_service.dart';
import 'services/social_games_service.dart';
import 'social_games_hub_screen.dart';
import 'social_groups_screen.dart';
import 'widgets/sa7bi_subpage_app_bar.dart';

/// يستقبل رابط دعوة مجموعة عامة، ثم يتحقق من الحساب ويطلب الانضمام.
class SocialGroupInviteScreen extends StatefulWidget {
  const SocialGroupInviteScreen({
    super.key,
    required this.groupId,
  });

  final String groupId;

  @override
  State<SocialGroupInviteScreen> createState() =>
      _SocialGroupInviteScreenState();
}

class _SocialGroupInviteScreenState extends State<SocialGroupInviteScreen> {
  final SocialCommunityService _community =
      SocialCommunityService.instance;

  final SocialGamesService _games =
      SocialGamesService.instance;

  bool _busy = false;
  bool _loginRequired = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _joinGroup(),
    );
  }

  Future<void> _joinGroup() async {
    if (_busy) return;

    setState(() {
      _busy = true;
      _loginRequired = false;
      _error = null;
    });

    try {
      await _community.refreshSession();

      if (!_community.isSignedIn) {
        if (mounted) {
          setState(() => _loginRequired = true);
        }
        return;
      }

      await _games.initialize();
      await _games.getCurrentUser();

      final group = await _community.joinGroup(widget.groupId);

      if (!mounted) return;

      await Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/groups/chat'),
          builder: (_) => SocialGroupChatScreen(group: group),
        ),
      );
    } on SocialCommunityException catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.message;
        _loginRequired = error.code == 'AUTH_REQUIRED' ||
            error.code == 'SESSION_EXPIRED';
      });
    } on SocialGamesException catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.message;
        _loginRequired = error.code == 'AUTH_REQUIRED' ||
            error.code == 'SESSION_EXPIRED';
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'تعذر الانضمام للمجموعة. تحقق من الاتصال.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _login() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const SocialGamesHubScreen(),
      ),
    );

    if (mounted) {
      await _joinGroup();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF080B13),
        appBar: const Sa7biSubpageAppBar(
          title: 'دعوة للانضمام إلى مجموعة',
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.groups_rounded,
                  color: Color(0xFFFFD76A),
                  size: 58,
                ),
                const SizedBox(height: 14),
                const Text(
                  'تمت دعوتك إلى مجموعة عامة في صاحبي AI',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                if (_busy) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 10),
                  const Text(
                    'جارٍ التحقق والانضمام...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ] else if (_loginRequired) ...[
                  Text(
                    _error ??
                        'سجّل الدخول أولًا حتى تنضم للمجموعة.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _login,
                    icon: const Icon(Icons.login_rounded),
                    label: const Text('تسجيل الدخول ثم الانضمام'),
                  ),
                ] else if (_error != null) ...[
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _joinGroup,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('إعادة المحاولة'),
                  ),
                ] else ...[
                  FilledButton.icon(
                    onPressed: _joinGroup,
                    icon: const Icon(Icons.group_add_rounded),
                    label: const Text('الانضمام إلى المجموعة'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
