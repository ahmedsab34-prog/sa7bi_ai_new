import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'services/profile_service.dart';
import 'services/reminder_service.dart';
import 'widgets/app_header.dart';
import 'widgets/profile_actions.dart';
import 'widgets/profile_header.dart';
import 'widgets/profile_reminders.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback onAudio;

  const ProfileScreen({
    super.key,
    required this.onAudio,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileService profileService = ProfileService.instance;
  final ReminderService reminderService = ReminderService.instance;

  Uint8List? _photo;
  String _displayName = ProfileService.defaultProfileName;
  String? _reelName;

  bool _loading = true;

  @override
  void initState() {
    super.initState();

    profileService.changes.addListener(_onProfileChanged);
    reminderService.reminders.addListener(_onRemindersChanged);

    _initialize();
  }

  @override
  void dispose() {
    profileService.changes.removeListener(_onProfileChanged);
    reminderService.reminders.removeListener(_onRemindersChanged);
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      await Future.wait<void>([
        profileService.initialize(),
        reminderService.initialize(),
      ]);

      _syncProfile();

      if (!mounted) return;

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
    _displayName = profileService.displayName;
    _photo = profileService.photoBytes;
    _reelName = profileService.hasReel
        ? profileService.reelName
        : null;
  }

  void _onProfileChanged() {
    if (!mounted) return;

    setState(() {
      _syncProfile();
    });
  }

  void _onRemindersChanged() {
    if (!mounted) return;

    setState(() {});
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080A10),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                12,
                10,
                12,
                4,
              ),
              child: AppHeader(
                onAudioTap: widget.onAudio,
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFFFD76A),
                      ),
                    )
                  : RefreshIndicator(
                      color: const Color(0xFFFFD76A),
                      backgroundColor: const Color(0xFF131620),
                      onRefresh: () async {
                        await profileService.refresh();
                        await reminderService.rescheduleAll();
                      },
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                          14,
                          10,
                          14,
                          28,
                        ),
                        children: [
                          ProfileHeader(
                            displayName: _displayName,
                            photo: _photo,
                            reelName: _reelName,
                            onChanged: _syncProfileAndRefresh,
                            onMessage: _showMessage,
                          ),

                          const SizedBox(height: 18),

                          ProfileReminders(
                            reminders: reminderService.items,
                            onMessage: _showMessage,
                          ),

                          const SizedBox(height: 8),

                          ProfileActions(
                            onMessage: _showMessage,
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

  void _syncProfileAndRefresh() {
    if (!mounted) return;

    setState(() {
      _syncProfile();
    });
  }
}
