import 'package:flutter/material.dart';

import 'audio_center_screen.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'secure_venting_screen.dart';
import 'social_groups_screen.dart';
import 'audio_center_screen.dart';
import 'service_config.dart';
import 'config/service_keys.dart';
import 'widgets/app_header.dart';
import 'widgets/audio_center_with_header.dart';
import 'theme/sa7bi_theme.dart';

/// تبويب الشات الرئيسي.
///
/// العام: المجموعات العامة الحالية.
/// الخاص: فضفضة AI المشفرة والمحمية برقم سري.
///
/// يحتفظ IndexedStack بحالة كل شاشة عند التبديل.
class ChatTabScreen extends StatefulWidget {
  const ChatTabScreen({super.key});

  @override
  State<ChatTabScreen> createState() =>
      _ChatTabScreenState();
}

class _ChatTabScreenState extends State<ChatTabScreen> {
  int _selectedMode = 0;

  Widget? _privateScreen;

  void _openProfile() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ProfileScreen(
          onProfileTap: null,
          onAudio: _openAudioCenter,
        ),
      ),
    );
  }

  void _openAudioCenter() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AudioCenterWithHeader(
          onProfileTap: _openProfile,
        ),
      ),
    );
  }

  String _ventingContext() {
    for (final service in sa7biServices) {
      if (service.serviceKey == ServiceKeys.venting) {
        return service.aiRole;
      }
    }

    return '''
أنت مساعد فضفضة خاص في صاحبي AI.
استمع للمستخدم باحترام وبدون أحكام.
ساعده على ترتيب أفكاره واختيار خطوات عملية.
لا تدّعي أنك طبيب أو معالج.
''';
  }

  Widget _createPrivateVentingScreen() {
    return SecureVentingScreen(
      child: ChatScreen(
        key: const ValueKey<String>(
          'private-ai-venting-chat',
        ),
        serviceKey: ServiceKeys.venting,
        serviceTitle: 'الفضفضة السرية',
        serviceContext: _ventingContext(),
        embedded: true,
      ),
    );
  }

  void _selectMode(int mode) {
    if (mode == _selectedMode) return;

    setState(() {
      if (mode == 1) {
        _privateScreen ??=
            _createPrivateVentingScreen();
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
          // الهيدر الموحد يظهر قبل اختيار نوع المحادثة.
          AppHeader(
            onProfileTap: _openProfile,
            onAudioTap: _openAudioCenter,
          ),

          // اختيار العام والخاص أسفل الهيدر.
          Padding(
            padding: const EdgeInsets.fromLTRB(
              12,
              5,
              12,
              7,
            ),
            child: Container(
              height: 46,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Sa7biTheme.surface,
                borderRadius: BorderRadius.circular(14),
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
                      title: 'الفضفضة السرية',
                      icon: Icons.lock_rounded,
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
                _privateScreen ??
                    const SizedBox.shrink(),
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
                  ? Sa7biTheme.cyan.withValues(
                      alpha: 0.14,
                    )
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: selected
                    ? Sa7biTheme.cyan.withValues(
                        alpha: 0.85,
                      )
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
                  size: 18,
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
                      fontSize: 10.5,
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
