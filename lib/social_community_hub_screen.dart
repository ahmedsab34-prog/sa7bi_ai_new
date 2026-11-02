
import 'package:flutter/material.dart';

import 'social_ai_games_screen.dart';
import 'social_connections_screen.dart';
import 'social_groups_screen.dart';
import 'social_quick_match_screen.dart';
import 'widgets/sa7bi_subpage_app_bar.dart';

/// مدخل موحد للدعوات والرسائل والمجموعات واللعب مع الذكاء الاصطناعي.
class SocialCommunityHubScreen extends StatelessWidget {
  const SocialCommunityHubScreen({super.key});

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF080B13),
        appBar: const Sa7biSubpageAppBar(
          title: 'مركز التواصل واللعب',
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: Colors.white10),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.people_alt_rounded,
                    color: Color(0xFFFFD76A),
                    size: 34,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'تواصل مع لاعبين صاحبي AI، انضم لمجموعات عامة، أو العب ضد الذكاء الاصطناعي.',
                      style: TextStyle(
                        color: Colors.white70,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _CommunityHubTile(
              icon: Icons.people_alt_rounded,
              title: 'العب مع لاعب عشوائي',
              description:
                  'نبحث عن لاعب حقيقي أولًا، وبعد 25 ثانية يتحول البحث تلقائيًا إلى صاحبي AI.',
              onTap: () => _open(
                context,
                const SocialQuickMatchScreen(),
              ),
            ),
            _CommunityHubTile(
              icon: Icons.mark_email_unread_outlined,
              title: 'الدعوات والرسائل الخاصة',
              description:
                  'البحث عن لاعب، دعوات الألعاب، ومحادثات بين شخصين.',
              onTap: () => _open(
                context,
                const SocialConnectionsScreen(),
              ),
            ),
            _CommunityHubTile(
              icon: Icons.groups_rounded,
              title: 'المجموعات العامة',
              description:
                  'إنشاء مجموعة عامة، الانضمام لمجموعات، والدردشة الجماعية.',
              onTap: () => _open(
                context,
                const SocialGroupsScreen(),
              ),
            ),
            _CommunityHubTile(
              icon: Icons.smart_toy_rounded,
              title: 'اللعب مع صاحبي AI',
              description:
                  'إكس أو، حجر ورقة مقص، وشطرنج ضد خصم آلي مع حفظ المباراة.',
              onTap: () => _open(
                context,
                const SocialAiGamesScreen(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommunityHubTile extends StatelessWidget {
  const _CommunityHubTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF111827),
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        minVerticalPadding: 15,
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: const Color(0x223F91FF),
          child: Icon(
            icon,
            color: const Color(0xFF7FB4FF),
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          description,
          style: const TextStyle(
            color: Colors.white60,
            height: 1.45,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_left_rounded,
          color: Colors.white54,
        ),
      ),
    );
  }
}
