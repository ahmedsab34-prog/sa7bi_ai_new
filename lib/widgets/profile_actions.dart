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

Future<void> shareApp() async {
try {
await Share.share(
'جرّب تطبيق صاحبي AI 🤖\n'
'مساعدك الذكي في كل يوم.\n\n'
'رابط التحميل:\n'
'${MonetizationConfig.appDownloadUrl}',
subject: 'صاحبي AI',
);
} catch () {
onMessage('تعذر فتح المشاركة.');
}
}

void openSettings(BuildContext context) {
Navigator.push(
context,
MaterialPageRoute(
builder: () => const SettingsScreen(),
),
);
}

@override
Widget build(BuildContext context) {
return Padding(
padding: const EdgeInsets.fromLTRB(
8,
2,
8,
8,
),
child: Row(
children: [
Expanded(
child: _ActionCard(
icon: Icons.share_rounded,
title: 'مشاركة التطبيق',
subtitle: 'شارك صاحبي AI',
color: const Color(0xFF70D7FF),
onTap: _shareApp,
),
),
const SizedBox(width: 8),
Expanded(
child: _ActionCard(
icon: Icons.settings_rounded,
title: 'الإعدادات',
subtitle: 'التطبيق والحساب',
color: const Color(0xFFBFC7D5),
onTap: () => _openSettings(context),
),
),
],
),
);
}
}

class _ActionCard extends StatelessWidget {
final IconData icon;
final String title;
final String subtitle;
final Color color;
final VoidCallback onTap;

const _ActionCard({
required this.icon,
required this.title,
required this.subtitle,
required this.color,
required this.onTap,
});

@override
Widget build(BuildContext context) {
return Material(
color: const Color(0xFF131620),
borderRadius: BorderRadius.circular(17),
child: InkWell(
onTap: onTap,
borderRadius: BorderRadius.circular(17),
child: Padding(
padding: const EdgeInsets.symmetric(
horizontal: 10,
vertical: 10,
),
child: Row(
children: [
Container(
width: 40,
height: 40,
decoration: BoxDecoration(
shape: BoxShape.circle,
color: color.withValues(alpha: 0.12),
border: Border.all(
color: color.withValues(alpha: 0.30),
),
),
child: Icon(
icon,
color: color,
size: 20,
),
),
const SizedBox(width: 9),
Expanded(
child: Column(
crossAxisAlignment:
CrossAxisAlignment.end,
children: [
Text(
title,
textDirection: TextDirection.rtl,
textAlign: TextAlign.right,
maxLines: 1,
overflow: TextOverflow.ellipsis,
style: const TextStyle(
fontWeight: FontWeight.w900,
fontSize: 12,
),
),
const SizedBox(height: 2),
Text(
subtitle,
textDirection: TextDirection.rtl,
textAlign: TextAlign.right,
maxLines: 1,
overflow: TextOverflow.ellipsis,
style: const TextStyle(
color: Colors.white54,
fontSize: 9,
),
),
],
),
),
],
),
),
),
);
}
}
