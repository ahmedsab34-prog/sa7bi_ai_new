import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'ai_service.dart';
import 'config/app_config.dart';
import 'services/profile_service.dart';
import 'services/reminder_service.dart';
import 'widgets/app_header.dart';
import 'widgets/credits_status.dart';
import 'widgets/profile_actions.dart';
import 'widgets/profile_bio_status.dart';
import 'widgets/profile_header.dart';
import 'widgets/profile_reminders.dart';
import 'widgets/rewarded_ad_button.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onAudio;

  const ProfileScreen({
    super.key,
    this.onAudio,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileService _profileService =
      ProfileService.instance;

  final ReminderService _reminderService =
      ReminderService.instance;

  Uint8List? _photo;

  String _displayName = '';
  String _reelName = '';
  String _bio = '';
  String _status = '';

  bool _aiConnected = false;
  bool _loading = true;
  bool _checkingAi = false;

  @override
  void initState() {
    super.initState();

    _profileService.changes.addListener(
      _syncProfile,
    );

    _reminderService.reminders.addListener(
      _onRemindersChanged,
    );

    _initialize();
  }

  @override
  void dispose() {
    _profileService.changes.removeListener(
      _syncProfile,
    );

    _reminderService.reminders.removeListener(
      _onRemindersChanged,
    );

    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      await Future.wait([
        _profileService.initialize(),
        _reminderService.initialize(),
      ]);

      if (!mounted) {
        return;
      }

      _syncProfile();

      setState(() {
        _loading = false;
      });

      await _checkAiConnection();
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
      });
    }
  }

  void _syncProfile() {
    if (!mounted) {
      return;
    }

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
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  Future<void> _checkAiConnection() async {
    if (_checkingAi) {
      return;
    }

    if (mounted) {
      setState(() {
        _checkingAi = true;
      });
    }

    try {
      final connected =
          await AiService.checkConnection();

      await _profileService.saveAiConnection(
        connected,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _aiConnected = connected;
        _checkingAi = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _aiConnected = false;
        _checkingAi = false;
      });

      await _profileService.saveAiConnection(
        false,
      );
    }
  }

  Future<void> _refreshProfile() async {
    try {
      await _profileService.refresh();

      await _reminderService.initialize();
      await _reminderService.rescheduleAll();

      await _checkAiConnection();

      if (!mounted) {
        return;
      }

      _syncProfile();
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'تعذر تحديث بيانات الحساب حاليًا.',
      );
    }
  }

  void _showMessage(String message) {
    if (!mounted ||
        message.trim().isEmpty) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            textDirection: TextDirection.rtl,
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(
            seconds: 2,
          ),
        ),
      );
  }

  Widget _buildAiStatusBar() {
    final connected = _aiConnected;

    final statusColor = connected
        ? Colors.greenAccent
        : Colors.orangeAccent;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        6,
        0,
        6,
        5,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.55),
        borderRadius:
            BorderRadius.circular(13),
        border: Border.all(
          color: statusColor.withValues(
            alpha: 0.30,
          ),
        ),
      ),
      child: Row(
        children: [
          if (_checkingAi)
            SizedBox(
              width: 9,
              height: 9,
              child:
                  CircularProgressIndicator(
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
                    color:
                        statusColor.withValues(
                      alpha: 0.35,
                    ),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              connected
                  ? 'صاحبي AI متصل وجاهز'
                  : 'صاحبي AI غير متصل',
              textDirection:
                  TextDirection.rtl,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Icon(
            connected
                ? Icons.cloud_done_rounded
                : Icons.cloud_off_rounded,
            size: 17,
            color: statusColor,
          ),
          const SizedBox(width: 1),
          IconButton(
            onPressed:
                _checkingAi
                    ? null
                    : _checkAiConnection,
            tooltip: 'فحص الاتصال',
            padding: EdgeInsets.zero,
            constraints:
                const BoxConstraints(
              minWidth: 30,
              minHeight: 30,
            ),
            icon: Icon(
              Icons.refresh_rounded,
              size: 17,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        6,
        0,
        6,
        5,
      ),
      child: Row(
        children: [
          const Expanded(
            child: CreditsStatus(
              compact: true,
              showRewardButton: false,
            ),
          ),
          const SizedBox(width: 6),
          const RewardedAdButton(
            compact: true,
          ),
        ],
      ),
    );
  }

  Widget _buildBuildInfo() {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        6,
        0,
        6,
        5,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF111720),
        borderRadius:
            BorderRadius.circular(11),
        border: Border.all(
          color: const Color(0x33FFD76A),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.verified_rounded,
            size: 14,
            color: Color(0xFFFFD76A),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'نسخة التطبيق: '
              '${AppConfig.appVersion}+'
              '${AppConfig.buildNumber}',
              textDirection:
                  TextDirection.rtl,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            AppConfig.commitSha,
            style: const TextStyle(
              fontSize: 8,
              color: Colors.white54,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileContent(
    BoxConstraints constraints,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
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

        _buildAiStatusBar(),

        _buildCreditsSection(),

        _buildBuildInfo(),

        ProfileActions(
          onMessage: _showMessage,
        ),

        ProfileReminders(
          reminders:
              _reminderService.items,
          onMessage: _showMessage,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // الهيدر كما هو؛ لا يتم تغييره من صفحة البروفايل.
          AppHeader(
            onAudioTap: widget.onAudio,
          ),

          Expanded(
            child: _loading
                ? const Center(
                    child:
                        CircularProgressIndicator(),
                  )
                : LayoutBuilder(
                    builder:
                        (
                      context,
                      constraints,
                    ) {
                      return ClipRect(
                        child: FittedBox(
                          fit:
                              BoxFit.scaleDown,
                          alignment:
                              Alignment.topCenter,
                          child: SizedBox(
                            width:
                                constraints.maxWidth,
                            child:
                                _buildProfileContent(
                              constraints,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
