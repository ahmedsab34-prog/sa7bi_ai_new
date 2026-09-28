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
    } catch (_) {
      onMessage('تعذر فتح المشاركة حاليًا.');
    }
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) {
          return const SettingsScreen();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        8,
        0,
        8,
        7,
      ),
      child: Column(
        children: [
          _buildActionTile(
            context: context,
            icon: Icons.share_rounded,
            title: 'مشاركة التطبيق',
            subtitle:
                'شارك رابط صاحبي AI مع أصدقائك',
            onTap: _shareApp,
          ),
          const SizedBox(height: 8),
          _buildActionTile(
            context: context,
            icon: Icons.settings_rounded,
            title: 'الإعدادات',
            subtitle:
                'إعدادات التطبيق والاتصال بالذكاء الاصطناعي',
            onTap: () => _openSettings(context),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(
            alpha: 0.07,
          ),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 3,
        ),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [
                Color(0xFFFFD54F),
                Color(0xFFB45CFF),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD54F)
                    .withValues(alpha: 0.14),
                blurRadius: 10,
              ),
            ],
          ),
          child: Icon(
            icon,
            color: Colors.black,
            size: 22,
          ),
        ),
        title: Text(
          title,
          textDirection: TextDirection.rtl,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: Text(
          subtitle,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.58),
          ),
        ),
        trailing: const Icon(
          Icons.chevron_left_rounded,
          size: 22,
        ),
      ),
    );
  }
}
