import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'ai_service.dart';
import 'app_diagnostics_screen.dart';
import 'chat_screen.dart';
import 'config/service_keys.dart';
import 'monetization_config.dart';
import 'reminder_settings_screen.dart';
import 'service_config.dart';
import 'services/chat_history_service.dart';
import 'services/profile_service.dart';
import 'services/reminder_service.dart';
import 'settings_screen.dart';
import 'theme/sa7bi_theme.dart';
import 'widgets/app_header.dart';
import 'widgets/credits_status.dart';
import 'widgets/profile_bio_status.dart';
import 'widgets/profile_header.dart';
import 'widgets/rewarded_ad_button.dart';

/// لوحة الحساب الرئيسية.
///
/// الصفحة الأساسية ثابتة بدون تمرير رأسي؛ تحرير الصورة والاسم والنبذة
/// والحالة يتم داخل نافذة منفصلة قابلة للتمرير حتى لا تزاحم شبكة الاختصارات.
class ProfileScreen extends StatefulWidget {
  final VoidCallback? onProfileTap;
  final VoidCallback? onAudio;

  const ProfileScreen({
    super.key,
    this.onProfileTap,
    this.onAudio,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileService _profileService = ProfileService.instance;
  final ReminderService _reminderService = ReminderService.instance;
  final ChatHistoryService _chatHistory = ChatHistoryService.instance;

  Uint8List? _photo;
  String _displayName = ProfileService.defaultProfileName;
  String _reelName = '';
  String _bio = '';
  String _status = '';

  bool _aiConnected = false;
  bool _loading = true;
  bool _checkingAi = false;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _profileService.changes.addListener(_syncProfile);
    _reminderService.reminders.addListener(_onRemindersChanged);
    _initialize();
  }

  @override
  void dispose() {
    _profileService.changes.removeListener(_syncProfile);
    _reminderService.reminders.removeListener(_onRemindersChanged);
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      await Future.wait<void>([
        _profileService.initialize(),
        _reminderService.initialize(),
      ]);

      if (!mounted) return;

      _syncProfile();

      setState(() {
        _loading = false;
      });

      await _checkAiConnection();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    }
  }

  void _syncProfile() {
    if (!mounted) return;

    setState(() {
      _photo = _profileService.photoBytes;
      _displayName = _profileService.displayName;
      _reelName = _profileService.reelName;
      _bio = _profileService.bio;
      _status = _profileService.status;
      _aiConnected = _profileService.aiConnected;
    });
  }

  void _onRemindersChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _checkAiConnection() async {
    if (_checkingAi) return;

    if (mounted) {
      setState(() {
        _checkingAi = true;
      });
    }

    try {
      final connected = await AiService.checkConnection();
      await _profileService.saveAiConnection(connected);

      if (!mounted) return;

      setState(() {
        _aiConnected = connected;
        _checkingAi = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _aiConnected = false;
        _checkingAi = false;
      });

      try {
        await _profileService.saveAiConnection(false);
      } catch (_) {
        // حفظ حالة الاتصال ليس سببًا لإغلاق صفحة الحساب.
      }
    }
  }

  Future<void> _refreshProfile() async {
    if (_refreshing) return;

    setState(() {
      _refreshing = true;
    });

    try {
      await _profileService.refresh();
      await _reminderService.initialize();
      await _reminderService.rescheduleAll();

      if (!mounted) return;

      _syncProfile();
      await _checkAiConnection();
    } catch (_) {
      if (!mounted) return;
      _showMessage('تعذر تحديث بيانات الحساب حاليًا.');
    } finally {
      if (mounted) {
        setState(() {
          _refreshing = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted || message.trim().isEmpty) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            textDirection: TextDirection.rtl,
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> _openProfileEditor() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.84,
          minChildSize: 0.55,
          maxChildSize: 0.96,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Sa7biTheme.background,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(26),
                ),
                border: Border(
                  top: BorderSide(color: Sa7biTheme.border),
                  left: BorderSide(color: Sa7biTheme.border),
                  right: BorderSide(color: Sa7biTheme.border),
                ),
              ),
              child: SafeArea(
                top: false,
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(8, 12, 8, 24),
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Sa7biTheme.textSecondary
                              .withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'تعديل الملف الشخصي',
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Sa7biTheme.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ProfileHeader(
                      photo: _photo,
                      displayName: _displayName,
                      reelName: _reelName,
                      onChanged: _syncProfile,
                      onMessage: _showMessage,
                    ),
                    ProfileBioStatus(
                      bio: _bio,
                      status: _status,
                      onProfileChanged: _syncProfile,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildIdentityCard() {
    final hasPhoto = _photo != null && _photo!.isNotEmpty;
    final secondaryText = _status.trim().isNotEmpty
        ? _status.trim()
        : (_bio.trim().isNotEmpty
            ? _bio.trim()
            : 'أضف نبذة وحالة تعبر عنك');

    return Material(
      color: Sa7biTheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: _openProfileEditor,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Sa7biTheme.gold.withValues(alpha: 0.28)),
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: Sa7biTheme.goldGradient,
                ),
                child: ClipOval(
                  child: ColoredBox(
                    color: Sa7biTheme.background,
                    child: hasPhoto
                        ? Image.memory(
                            _photo!,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                            errorBuilder: (_, __, ___) {
                              return const Icon(
                                Icons.person_rounded,
                                color: Sa7biTheme.gold,
                                size: 29,
                              );
                            },
                          )
                        : const Icon(
                            Icons.person_rounded,
                            color: Sa7biTheme.gold,
                            size: 29,
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _displayName,
                      textDirection: TextDirection.rtl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Sa7biTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      secondaryText,
                      textDirection: TextDirection.rtl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Sa7biTheme.textSecondary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.edit_rounded,
                color: Sa7biTheme.gold,
                size: 19,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAiStatusBar() {
    final statusColor =
        _aiConnected ? Sa7biTheme.success : Sa7biTheme.gold;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: Sa7biTheme.surfaceRaised,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        children: [
          if (_checkingAi || _refreshing)
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.7,
                color: statusColor,
              ),
            )
          else
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusColor,
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withValues(alpha: 0.3),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _aiConnected
                  ? 'صاحبي AI متصل وجاهز'
                  : 'الاتصال غير مؤكد — افحص الشبكة',
              textDirection: TextDirection.rtl,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Sa7biTheme.textPrimary,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Icon(
            _aiConnected ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
            size: 17,
            color: statusColor,
          ),
          IconButton(
            onPressed: _refreshing ? null : _refreshProfile,
            tooltip: 'تحديث الحساب والاتصال',
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(
              minWidth: 34,
              minHeight: 32,
            ),
            icon: Icon(
              Icons.refresh_rounded,
              size: 18,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditsSection() {
    return Row(
      children: [
        const Expanded(
          child: CreditsStatus(
            compact: true,
            showRewardButton: false,
          ),
        ),
        const SizedBox(width: 7),
        const RewardedAdButton(compact: true),
      ],
    );
  }

  List<_ProfileAction> _buildActions() {
    return [
      _ProfileAction(
        icon: Icons.history_rounded,
        title: 'المحادثات',
        subtitle: 'السجل المحفوظ',
        onTap: _openChatHistory,
      ),
      _ProfileAction(
        icon: Icons.notifications_active_outlined,
        title: 'التذكيرات',
        subtitle: _reminderService.items.isEmpty
            ? 'الإشعارات والمواعيد'
            : '${_reminderService.items.length} تذكير محفوظ',
        onTap: _openReminders,
      ),
      _ProfileAction(
        icon: Icons.headphones_rounded,
        title: 'مركز الصوت',
        subtitle: 'قرآن وراديو وبودكاست',
        onTap: _openAudioCenter,
      ),
      _ProfileAction(
        icon: Icons.settings_rounded,
        title: 'الإعدادات',
        subtitle: 'التحكم والخصوصية',
        onTap: _openSettings,
      ),
      _ProfileAction(
        icon: Icons.fact_check_outlined,
        title: 'تشخيص التطبيق',
        subtitle: 'فحص الشبكة والخدمات',
        onTap: _openDiagnostics,
      ),
      _ProfileAction(
        icon: Icons.share_rounded,
        title: 'مشاركة التطبيق',
        subtitle: 'أرسل رابط صاحبي AI',
        onTap: _shareApp,
      ),
    ];
  }

  Widget _buildActionTile(_ProfileAction action) {
    return Material(
      color: Sa7biTheme.surface,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Sa7biTheme.border),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  gradient: Sa7biTheme.brandGradient,
                ),
                child: Icon(
                  action.icon,
                  color: Sa7biTheme.background,
                  size: 19,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      action.title,
                      textDirection: TextDirection.rtl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Sa7biTheme.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      action.subtitle,
                      textDirection: TextDirection.rtl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Sa7biTheme.textSecondary,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
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

  void _openReminders() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const ReminderSettingsScreen(),
      ),
    );
  }

  void _openSettings() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const SettingsScreen(),
      ),
    );
  }

  void _openDiagnostics() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const AppDiagnosticsScreen(),
      ),
    );
  }

  void _openAudioCenter() {
    final callback = widget.onAudio;
    if (callback != null) {
      callback();
      return;
    }

    _showMessage('افتح مركز الصوت من زر الصوت في الهيدر.');
  }

  Future<void> _shareApp() async {
    try {
      await Share.share(
        MonetizationConfig.appDownloadUrl,
        subject: 'صاحبي AI',
      );
    } catch (_) {
      _showMessage('تعذر فتح المشاركة حاليًا.');
    }
  }

  void _openChatHistory() {
    final entries = <_ChatHistoryEntry>[
      const _ChatHistoryEntry(
        serviceKey: ServiceKeys.khalasana,
        title: 'خلصانة AI',
        serviceContext: null,
        icon: Icons.auto_awesome_rounded,
      ),
      const _ChatHistoryEntry(
        serviceKey: ServiceKeys.general,
        title: 'الشات العام',
        serviceContext: null,
        icon: Icons.chat_bubble_rounded,
      ),
      ...sa7biServices
          .where((service) => service.serviceKey != ServiceKeys.venting)
          .map(
            (service) => _ChatHistoryEntry(
              serviceKey: service.serviceKey,
              title: service.title,
              serviceContext: service.aiRole,
              icon: service.icon,
            ),
          ),
    ];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            height: MediaQuery.of(sheetContext).size.height * 0.76,
            decoration: const BoxDecoration(
              color: Sa7biTheme.background,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(25),
              ),
              border: Border(
                top: BorderSide(color: Sa7biTheme.border),
                left: BorderSide(color: Sa7biTheme.border),
                right: BorderSide(color: Sa7biTheme.border),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Sa7biTheme.textSecondary
                          .withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'المحادثات المحفوظة',
                    style: TextStyle(
                      color: Sa7biTheme.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 18),
                    child: Text(
                      'اختر المحادثة لفتح سجلها المحفوظ. الفضفضة السرية تظل داخل قسمها المحمي.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Sa7biTheme.textSecondary,
                        fontSize: 10,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 18),
                      itemCount: entries.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 6),
                      itemBuilder: (_, index) {
                        final entry = entries[index];

                        return FutureBuilder<int>(
                          future: _chatHistory.messageCount(entry.serviceKey),
                          builder: (context, snapshot) {
                            final count = snapshot.data;
                            final subtitle = snapshot.connectionState !=
                                    ConnectionState.done
                                ? 'جاري قراءة السجل…'
                                : (count == null || count == 0
                                    ? 'لا توجد رسائل محفوظة بعد'
                                    : '$count رسالة محفوظة');

                            return Material(
                              color: Sa7biTheme.surface,
                              borderRadius: BorderRadius.circular(13),
                              child: ListTile(
                                leading: Icon(
                                  entry.icon,
                                  color: Sa7biTheme.cyan,
                                ),
                                title: Text(
                                  entry.title,
                                  style: const TextStyle(
                                    color: Sa7biTheme.textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                subtitle: Text(
                                  subtitle,
                                  style: const TextStyle(
                                    color: Sa7biTheme.textSecondary,
                                    fontSize: 10,
                                  ),
                                ),
                                trailing: const Icon(
                                  Icons.chevron_left_rounded,
                                  color: Sa7biTheme.textSecondary,
                                ),
                                onTap: () {
                                  Navigator.of(sheetContext).pop();

                                  Navigator.of(this.context).push<void>(
                                    MaterialPageRoute<void>(
                                      builder: (chatContext) => ChatScreen(
                                        serviceKey: entry.serviceKey,
                                        serviceTitle: entry.title,
                                        serviceContext: entry.serviceContext,
                                        onProfileTap: () {
                                          Navigator.of(chatContext).maybePop();
                                        },
                                        onAudioTap: _openAudioCenter,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final actions = _buildActions();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Column(
          children: [
            AppHeader(
              onProfileTap: widget.onProfileTap,
              onAudioTap: widget.onAudio,
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : Padding(
                          padding: const EdgeInsets.fromLTRB(9, 4, 9, 7),
                          child: Column(
                            children: [
                              _buildIdentityCard(),
                              const SizedBox(height: 7),
                              _buildAiStatusBar(),
                              const SizedBox(height: 7),
                              _buildCreditsSection(),
                              const SizedBox(height: 9),
                              Expanded(
                                child: GridView.builder(
                                  padding: EdgeInsets.zero,
                                  physics:
                                      const NeverScrollableScrollPhysics(),
                                  itemCount: actions.length,
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 8,
                                    mainAxisSpacing: 8,
                                    childAspectRatio: 2.0,
                                  ),
                                  itemBuilder: (context, index) {
                                    return _buildActionTile(actions[index]);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileAction {
  const _ProfileAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

class _ChatHistoryEntry {
  const _ChatHistoryEntry({
    required this.serviceKey,
    required this.title,
    required this.serviceContext,
    required this.icon,
  });

  final String serviceKey;
  final String title;
  final String? serviceContext;
  final IconData icon;
}
