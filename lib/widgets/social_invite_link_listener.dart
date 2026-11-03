import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import '../services/social_invite_link_service.dart';
import '../social_game_invite_screen.dart';
import '../social_group_invite_screen.dart';

/// يستقبل روابط HTTPS الموثّقة والروابط الداخلية القديمة،
/// سواء عند تشغيل التطبيق أو أثناء عمله.
class SocialInviteLinkListener extends StatefulWidget {
  const SocialInviteLinkListener({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<SocialInviteLinkListener> createState() =>
      _SocialInviteLinkListenerState();
}

class _SocialInviteLinkListenerState extends State<SocialInviteLinkListener> {
  StreamSubscription<Uri>? _subscription;

  String? _lastHandledKey;
  DateTime? _lastHandledAt;

  @override
  void initState() {
    super.initState();

    final appLinks = AppLinks();

    _subscription = appLinks.uriLinkStream.listen(
      _handleIncomingUri,
      onError: (Object _) {},
    );

    unawaited(_readInitialLink(appLinks));
  }

  Future<void> _readInitialLink(AppLinks appLinks) async {
    try {
      final initialUri = await appLinks.getInitialLink();

      if (initialUri != null && mounted) {
        _handleIncomingUri(initialUri);
      }
    } catch (_) {
      // بعض إصدارات Android لا تعيد رابط تشغيل أوليًا؛ يظل stream فعالًا.
    }
  }

  void _handleIncomingUri(Uri uri) {
    final gameCode = SocialInviteLinkService.extractInviteCode(uri);
    final groupId = SocialInviteLinkService.extractGroupInviteId(uri);

    if (gameCode == null && groupId == null) return;

    final key = gameCode != null
        ? 'game:$gameCode'
        : 'group:$groupId';

    final now = DateTime.now();

    // منع استقبال الرابط نفسه مرتين من initialLink و uriLinkStream.
    if (_lastHandledKey == key &&
        _lastHandledAt != null &&
        now.difference(_lastHandledAt!) < const Duration(seconds: 3)) {
      return;
    }

    _lastHandledKey = key;
    _lastHandledAt = now;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final navigator = Navigator.of(
        context,
        rootNavigator: true,
      );

      if (gameCode != null) {
        navigator.push<void>(
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: '/game/invite'),
            builder: (_) => SocialGameInviteScreen(
              inviteCode: gameCode,
            ),
          ),
        );
      } else if (groupId != null) {
        navigator.push<void>(
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: '/groups/invite'),
            builder: (_) => SocialGroupInviteScreen(
              groupId: groupId,
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
