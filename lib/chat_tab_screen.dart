import 'package:flutter/material.dart';

import 'social_groups_screen.dart';
import 'social_connections_screen.dart';
import 'theme/sa7bi_theme.dart';

/// تبويب الشات الرئيسي.
///
/// الوضع العام يعرض المجموعات العامة والدردشة الجماعية.
/// الوضع الخاص يعرض الدعوات والرسائل المباشرة.
///
/// نستخدم IndexedStack حتى لا نفقد حالة الشاشة عند التبديل
/// بين العام والخاص.
class ChatTabScreen extends StatefulWidget {
  const ChatTabScreen({super.key});

  @override
  State<ChatTabScreen> createState() => _ChatTabScreenState();
}

class _ChatTabScreenState extends State<ChatTabScreen> {
  // 0 = الشات العام.
  // 1 = الشات الخاص.
  int _selectedMode = 0;

  // لا ننشئ شاشة الرسائل الخاصة إلا عند فتحها أول مرة.
  // بعد ذلك تظل محفوظة داخل IndexedStack.
  Widget? _privateScreen;

  void _selectMode(int mode) {
    if (mode == _selectedMode) return;

    setState(() {
      if (mode == 1) {
        _privateScreen ??= const SocialConnectionsScreen();
      }

      _selectedMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
            child: Container(
              height: 49,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Sa7biTheme.surface,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: Sa7biTheme.border,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _ChatModeButton(
                      title: 'الشات العام',
                      icon: Icons.groups_rounded,
                      selected: _selectedMode == 0,
                      onTap: () => _selectMode(0),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: _ChatModeButton(
                      title: 'الشات الخاص',
                      icon: Icons.forum_rounded,
                      selected: _selectedMode == 1,
                      onTap: () => _selectMode(1),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            child: IndexedStack(
              index: _selectedMode,
              children: [
                const SocialGroupsScreen(),
                _privateScreen ?? const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatModeButton extends StatelessWidget {
  const _ChatModeButton({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: title,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(11),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: selected
                  ? Sa7biTheme.cyan.withValues(alpha: 0.14)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: selected
                    ? Sa7biTheme.cyan.withValues(alpha: 0.85)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 7,
              vertical: 5,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 19,
                  color: selected
                      ? Sa7biTheme.cyan
                      : Sa7biTheme.textSecondary,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected
                          ? Sa7biTheme.textPrimary
                          : Sa7biTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: selected
                          ? FontWeight.w900
                          : FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
