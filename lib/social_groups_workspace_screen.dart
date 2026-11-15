import 'package:flutter/material.dart';

import 'social_groups_screen.dart';
import 'social_private_groups_screen.dart';
import 'widgets/sa7bi_subpage_app_bar.dart';

/// نقطة دخول واحدة للمجموعات العامة والخاصة داخل صاحبي Connect.
class SocialGroupsWorkspaceScreen extends StatelessWidget {
  const SocialGroupsWorkspaceScreen({super.key});

  void _openPublic(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const SocialGroupsScreen(),
      ),
    );
  }

  void _openPrivate(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const SocialPrivateGroupsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF080B13),
        appBar: const Sa7biSubpageAppBar(
          title: 'مجموعات صاحبي Connect',
          subtitle: 'المجتمعات العامة ومجموعاتك الخاصة',
        ),
        body: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            _WorkspaceCard(
              title: 'المجموعات العامة',
              subtitle: 'اكتشف مجتمعات مفتوحة وانضم للمناقشات',
              description:
                  'أي مستخدم يستطيع استكشاف المجموعة العامة والانضمام إليها.',
              icon: Icons.public_rounded,
              color: const Color(0xFF7FB4FF),
              onTap: () => _openPublic(context),
            ),
            const SizedBox(height: 12),
            _WorkspaceCard(
              title: 'مجموعاتي الخاصة',
              subtitle: 'مجموعات لا يدخلها إلا من يحمل رمز الدعوة',
              description:
                  'أنشئ مجموعة خاصة، شارك رمزًا محدود الاستخدام، وأدر الأعضاء والمشرفين.',
              icon: Icons.lock_rounded,
              color: const Color(0xFFFFD76A),
              onTap: () => _openPrivate(context),
            ),
            const SizedBox(height: 14),
            const _WorkspaceNotice(),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceCard extends StatelessWidget {
  const _WorkspaceCard({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF111827),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.32)),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: color, size: 27),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 10,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              Icon(Icons.chevron_left_rounded, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkspaceNotice extends StatelessWidget {
  const _WorkspaceNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF151D2C),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white10),
      ),
      child: const Text(
        'المجموعات الخاصة محمية بعضوية ورمز دعوة. هذا لا يعني أن الرسائل مشفرة من طرف إلى طرف؛ لا تشارك كلمات المرور أو البيانات الحساسة.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white60,
          fontSize: 10,
          height: 1.6,
        ),
      ),
    );
  }
}
