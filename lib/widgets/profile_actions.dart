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
      final url = MonetizationConfig.appDownloadUrl;

      await Share.share(
        'جرّب تطبيق صاحبي AI 🤖\n'
        'مساعدك الذكي في كل يوم.\n\n'
        'رابط التحميل:\n'
        '$url',
        subject: 'صاحبي AI',
      );
    } catch (_) {
      onMessage('تعذر فتح المشاركة');
    }
  }

  void _openSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SettingsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ActionButton(
          icon: Icons.share_rounded,
          title: 'مشاركة التطبيق',
          subtitle:
              'شارك صاحبي مع أصحابك برابط التحميل عبر التطبيقات المتاحة.',
          onTap: _shareApp,
        ),

        _ActionButton(
          icon: Icons.settings_rounded,
          title: 'الإعدادات',
          subtitle: 'إعدادات التطبيق والذكاء الاصطناعي.',
          onTap: () => _openSettings(context),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF131620),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white10,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                Color(0xFFFFD54F),
                Color(0xFFB45CFF),
              ],
            ),
          ),
          child: Icon(
            icon,
            color: Colors.black,
          ),
        ),
        title: Text(
          title,
          textDirection: TextDirection.rtl,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: Text(
          subtitle,
          textDirection: TextDirection.rtl,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_left_rounded,
        ),
      ),
    );
  }
}
