import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../monetization_config.dart';
import '../settings_screen.dart';

class ProfileActions extends StatelessWidget {
final void Function(String message) onMessage;

const ProfileActions({
super.key,
required this.onMessage,
});

Future<void> _shareApp() async {
try {
await Share.share(
MonetizationConfig.appDownloadUrl,
subject: 'صاحبي AI',
);
} catch (error) {
onMessage('تعذر فتح المشاركة');
}
}

void _openSettings(BuildContext context) {
Navigator.of(context).push(
MaterialPageRoute(
builder: (BuildContext context) {
return const SettingsScreen();
},
),
);
}

@override
Widget build(BuildContext context) {
return Column(
children: [
ListTile(
leading: const Icon(
Icons.share_rounded,
),
title: const Text(
'مشاركة التطبيق',
),
subtitle: const Text(
'شارك رابط صاحبي AI مع أصدقائك',
),
onTap: _shareApp,
),
ListTile(
leading: const Icon(
Icons.settings_rounded,
),
title: const Text(
'الإعدادات',
),
subtitle: const Text(
'إعدادات التطبيق والحساب',
),
onTap: () => _openSettings(context),
),
],
);
}
}
