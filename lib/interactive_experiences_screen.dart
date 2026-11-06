import 'package:flutter/material.dart';

import 'social_games_hub_screen.dart';

/// مركز الألعاب الرئيسي.
/// تمت إزالة تبويب التجارب والألعاب المحلية القديمة.
/// نستخدم مركز الألعاب المتصل بالخادم حتى تكون الغرف والدعوات
/// والمباريات المحفوظة في مكان واحد.
class InteractiveExperiencesScreen extends StatelessWidget {
  const InteractiveExperiencesScreen({
    super.key,
    this.onShareResult,
  });

  /// محفوظ للتوافق مع استدعاءات الشاشات الموجودة.
  final ValueChanged<String>? onShareResult;

  @override
  Widget build(BuildContext context) {
    return SocialGamesHubScreen(
      onShareInvite: onShareResult,
    );
  }
}
