
import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import '../services/social_invite_link_service.dart';
import '../social_game_invite_screen.dart';

/// يستقبل روابط الدعوات عند تشغيل التطبيق أو أثناء عمله.
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

class _SocialInviteLinkListenerState
    extends State<SocialInviteLinkListener> {
  StreamSubscription<Uri>? _subscription;

  String? _lastInviteCode;
  DateTime? _lastHandledAt;

  @override
  void initState() {
    super.initState();

    // يستقبل الرابط الأولي وروابط التشغيل اللاحقة.
    _subscription = AppLinks().uriLinkStream.listen(
      _handleIncomingUri,
    );
  }

  void _handleIncomingUri(Uri uri) {
    final code = SocialInviteLinkService.extractInviteCode(uri);
    if (code == null) return;

    final now = DateTime.now();

    // منع فتح شاشتين إذا أرسل Android الرابط نفسه أكثر من مرة.
    if (_lastInviteCode == code &&
        _lastHandledAt != null &&
        now.difference(_lastHandledAt!) <
            const Duration(seconds: 3)) {
      return;
    }

    _lastInviteCode = code;
    _lastHandledAt = now;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      Navigator.of(context, rootNavigator: true).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => SocialGameInviteScreen(
            inviteCode: code,
          ),
        ),
      );
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
