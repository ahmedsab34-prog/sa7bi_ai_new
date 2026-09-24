import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'services/profile_service.dart';
import 'services/reminder_service.dart';
import 'widgets/app_header.dart';
import 'widgets/profile_actions.dart';
import 'widgets/profile_bio_status.dart';
import 'widgets/profile_header.dart';
import 'widgets/profile_reminders.dart';

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
  final ProfileService _profileService = ProfileService.instance;
  final ReminderService _reminderService = ReminderService.instance;

  Uint8List? _photo;
  String _displayName = '';
  String _reelName = '';
  String _bio = '';
  String _status = '';
  bool _aiConnected = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();

    _profileService.addListener(_syncProfile);
    _reminderService.addListener(_onRemindersChanged);

    _initialize();
  }

  @override
  void dispose() {
    _profileService.removeListener(_syncProfile);
    _reminderService.removeListener(_onRemindersChanged);
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      await Future.wait([
        _profileService.initialize(),
        _reminderService.initialize(),
      ]);

      if (!mounted) return;

      _syncProfile();

      setState(() {
        _loading = false;
      });
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
      _photo = _profileService.photo;
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

  Future<void> _refreshProfile() async {
    await _profileService.initialize();
    await _reminderService.initialize();
    await _reminderService.rescheduleAll();

    if (!mounted) return;

    _syncProfile();
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

  Widget _buildAiStatusBar() {
    final connected = _aiConnected;

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 2, 8, 6),
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: connected
              ? Colors.greenAccent.withValues(alpha: 0.35)
              : Theme.of(context)
                  .colorScheme
                  .outline
                  .withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: connected
                  ? Colors.greenAccent
                  : Colors.orangeAccent,
              boxShadow: [
                BoxShadow(
                  color: (connected
                          ? Colors.greenAccent
                          : Colors.orangeAccent)
                      .withValues(alpha: 0.35),
                  blurRadius: 7,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              connected
                  ? 'صاحبي AI متصل وجاهز'
                  : 'صاحبي AI غير متصل',
              textDirection: TextDirection.rtl,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Icon(
            connected
                ? Icons.cloud_done_rounded
                : Icons.cloud_off_rounded,
            size: 18,
            color: connected
                ? Colors.greenAccent
                : Colors.orangeAccent,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          AppHeader(
            onAudio: widget.onAudio,
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : RefreshIndicator(
                    onRefresh: _refreshProfile,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(
                        top: 2,
                        bottom: 14,
                      ),
                      children: [
                        _buildAiStatusBar(),

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

                        ProfileReminders(
                          reminderService: _reminderService,
                        ),

                        ProfileActions(
                          profileService: _profileService,
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
