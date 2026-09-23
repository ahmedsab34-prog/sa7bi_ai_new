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
  final VoidCallback onAudio;

  const ProfileScreen({
    super.key,
    required this.onAudio,
  });

  @override
  State<ProfileScreen> createState() =>
      _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileService profileService =
      ProfileService.instance;

  final ReminderService reminderService =
      ReminderService.instance;

  Uint8List? _photo;

  String _displayName =
      ProfileService.defaultProfileName;

  String? _reelName;

  String _bio = '';

  String _status = '';

  bool _aiConnected = false;

  bool _loading = true;

  @override
  void initState() {
    super.initState();

    profileService.changes.addListener(
      _onProfileChanged,
    );

    reminderService.reminders.addListener(
      _onRemindersChanged,
    );

    _initialize();
  }

  @override
  void dispose() {
    profileService.changes.removeListener(
      _onProfileChanged,
    );

    reminderService.reminders.removeListener(
      _onRemindersChanged,
    );

    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      await Future.wait<void>([
        profileService.initialize(),
        reminderService.initialize(),
      ]);

      _syncProfile();

      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
      });
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
    _displayName =
        profileService.displayName;

    _photo =
        profileService.photoBytes;

    _reelName =
        profileService.hasReel
            ? profileService.reelName
            : null;

    _bio =
        profileService.bio;

    _status =
        profileService.status;

    _aiConnected =
        profileService.aiConnected;
  }

  void _onProfileChanged() {
    if (!mounted) {
      return;
    }

    setState(() {
      _syncProfile();
    });
  }

  void _onRemindersChanged() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

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

  Future<void> _refreshProfile() async {
    await profileService.refresh();

    await reminderService.rescheduleAll();

    if (!mounted) {
      return;
    }

    _syncProfile();

    setState(() {});
  }

  Widget _buildAiStatusCard() {
    final bool connected = _aiConnected;

    return Container(
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: connected
            ? const Color(0xFF10251C)
            : const Color(0xFF131620),
        border: Border.all(
          color: connected
              ? const Color(0x5549E58A)
              : const Color(0x33FFD76A),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: connected
                  ? const Color(0x2249E58A)
                  : const Color(0x22FFD76A),
            ),
            child: Icon(
              connected
                  ? Icons.check_circle_rounded
                  : Icons.smart_toy_rounded,
              color: connected
                  ? const Color(0xFF69F0AE)
                  : const Color(0xFFFFD76A),
              size: 23,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.end,
              children: [
                Text(
                  'صاحبي AI',
                  textDirection:
                      TextDirection.rtl,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  connected
                      ? 'متصل وجاهز للعمل'
                      : 'حالة الاتصال محفوظة وسيتم تحديثها من الإعدادات',
                  textDirection:
                      TextDirection.rtl,
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: connected
                        ? const Color(0xFF69F0AE)
                        : Colors.white54,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickInfo() {
    final bool hasPhoto =
        _photo != null &&
        _photo!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF131620),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0x22FFFFFF),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [
                  Color(0xFFFFD76A),
                  Color(0xFFFF4D8D),
                  Color(0xFFB45CFF),
                  Color(0xFF63E6FF),
                  Color(0xFFFFD76A),
                ],
              ),
            ),
            child: ClipOval(
              child: Container(
                color: const Color(0xFF0C0F17),
                child: hasPhoto
                    ? Image.memory(
                        _photo!,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (_, __, ___) {
                          return const Icon(
                            Icons.person_rounded,
                            color:
                                Color(0xFFFFD76A),
                            size: 30,
                          );
                        },
                      )
                    : const Icon(
                        Icons.person_rounded,
                        color:
                            Color(0xFFFFD76A),
                        size: 30,
                      ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.end,
              children: [
                Text(
                  _displayName,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  textDirection:
                      TextDirection.rtl,
                  textAlign:
                      TextAlign.right,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _status.isNotEmpty
                      ? _status
                      : _bio.isNotEmpty
                          ? _bio
                          : 'ملفك الشخصي في صاحبي AI',
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  textDirection:
                      TextDirection.rtl,
                  textAlign:
                      TextAlign.right,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFF080A10),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                12,
                8,
                12,
                2,
              ),
              child: AppHeader(
                onAudioTap:
                    widget.onAudio,
              ),
            ),

            Expanded(
              child: _loading
                  ? const Center(
                      child:
                          CircularProgressIndicator(
                        color:
                            Color(0xFFFFD76A),
                      ),
                    )
                  : RefreshIndicator(
                      color:
                          const Color(0xFFFFD76A),
                      backgroundColor:
                          const Color(0xFF131620),
                      onRefresh:
                          _refreshProfile,
                      child: ListView(
                        physics:
                            const AlwaysScrollableScrollPhysics(),
                        padding:
                            const EdgeInsets.fromLTRB(
                          12,
                          6,
                          12,
                          22,
                        ),
                        children: [
                          // معلومات سريعة
                          _buildQuickInfo(),

                          // حالة اتصال صاحبي AI
                          _buildAiStatusCard(),

                          // بيانات الحساب والصورة والـReel
                          ProfileHeader(
                            displayName:
                                _displayName,
                            photo:
                                _photo,
                            reelName:
                                _reelName,
                            onChanged:
                                _syncProfileAndRefresh,
                            onMessage:
                                _showMessage,
                          ),

                          const SizedBox(
                            height: 10,
                          ),

                          // النبذة والحالة
                          ProfileBioStatus(
                            bio: _bio,
                            status: _status,
                            onChanged:
                                _syncProfileAndRefresh,
                            onMessage:
                                _showMessage,
                          ),

                          const SizedBox(
                            height: 10,
                          ),

                          // التذكيرات
                          ProfileReminders(
                            reminders:
                                reminderService.items,
                            onMessage:
                                _showMessage,
                          ),

                          const SizedBox(
                            height: 4,
                          ),

                          // المشاركة والإعدادات
                          ProfileActions(
                            onMessage:
                                _showMessage,
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
    if (!mounted) {
      return;
    }

    setState(() {
      _syncProfile();
    });
  }
}
