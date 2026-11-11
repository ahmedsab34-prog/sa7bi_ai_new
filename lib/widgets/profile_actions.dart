
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../monetization_config.dart';
import '../settings_screen.dart';
import '../social_connections_screen.dart';

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
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const SettingsScreen(),
      ),
    );
  }

  void _openConnections(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const SocialConnectionsScreen(),
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
              icon: Icons.person_search_rounded,
              title: 'البحث عن أصحاب',
              color: const Color(0xFF67B7FF),
              onTap: () => _openConnections(context),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildActionTile(
              icon: Icons.share_rounded,
              title: 'مشاركة التطبيق',
              color: const Color(0xFFE6A1C0),
              onTap: _shareApp,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildActionTile(
              icon: Icons.settings_rounded,
              title: 'الإعدادات',
              color: const Color(0xFF83C8FF),
              onTap: () => _openSettings(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFF101A2B),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(
            minHeight: 64,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: color.withValues(alpha: 0.28),
            ),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF192943),
                Color(0xFF0C1423),
              ],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 5,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 29,
                height: 29,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.13),
                  border: Border.all(
                    color: color.withValues(alpha: 0.4),
                  ),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 17,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                textDirection: TextDirection.rtl,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
