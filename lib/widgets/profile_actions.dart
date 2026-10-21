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
        builder: (context) => const SettingsScreen(),
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
      child: Row(
        children: [
          Expanded(
            child: _buildActionTile(
              context: context,
              icon: Icons.share_rounded,
              title: 'مشاركة التطبيق',
              onTap: _shareApp,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildActionTile(
              context: context,
              icon: Icons.settings_rounded,
              title: 'الإعدادات',
              onTap: () => _openSettings(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.surfaceContainerHighest
          .withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(
            minHeight: 58,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colors.outlineVariant
                  .withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFFFD54F),
                      Color(0xFFB45CFF),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Icon(
                  icon,
                  color: Colors.black,
                  size: 18,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  textDirection: TextDirection.rtl,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
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
