import 'package:flutter/material.dart';

/// The character now lives in the single app-wide floating portal.
/// Keep this compatibility widget so existing HomeScreen imports remain safe,
/// but do not allocate a second 3D WebView or reserve vertical page space.
class Sa7biHeroLitePanel extends StatelessWidget {
  const Sa7biHeroLitePanel({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
