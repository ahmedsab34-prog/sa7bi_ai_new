import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'ai_service.dart';
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
State<ProfileScreen> createState() =>
_ProfileScreenState();
}

class _ProfileScreenState
extends State<ProfileScreen> {
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

setState(() {
  _checkingAi = true;
});

final connected =
    await AiService.checkConnection();

await _profileService.saveAiConnection(
  connected,
);

if (!mounted) return;

setState(() {
  _aiConnected = connected;
  _checkingAi = false;
});

}

Future<void> _refreshProfile() async {
await _profileService.refresh();

await _reminderService.initialize();
await _reminderService.rescheduleAll();

await _checkAiConnection();

if (!mounted) return;

_syncProfile();

}

void _showMessage(String message) {
if (!mounted || message.trim().isEmpty) {
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
      duration: const Duration(seconds: 2),
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
    8,
    0,
    8,
    7,
  ),
  padding: const EdgeInsets.symmetric(
    horizontal: 12,
    vertical: 9,
  ),
  decoration: BoxDecoration(
    color: Theme.of(context)
        .colorScheme
        .surfaceContainerHighest
        .withValues(alpha: 0.55),
    borderRadius: BorderRadius.circular(15),
    border: Border.all(
      color: statusColor.withValues(alpha: 0.30),
    ),
  ),
  child: Row(
    children: [
      if (_checkingAi)
        SizedBox(
          width: 10,
          height: 10,
          child: CircularProgressIndicator(
            strokeWidth: 1.8,
            color: statusColor,
          ),
        )
      else
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: statusColor,
            boxShadow: [
              BoxShadow(
                color: statusColor.withValues(
                  alpha: 0.35,
                ),
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
        color: statusColor,
      ),
      const SizedBox(width: 4),
      IconButton(
        onPressed:
            _checkingAi ? null : _checkAiConnection,
        tooltip: 'فحص الاتصال',
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

@override
Widget build(BuildContext context) {
return SafeArea(
child: Column(
children: [
AppHeader(
onAudioTap: widget.onAudio,
),

      Expanded(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : RefreshIndicator(
                onRefresh: _refreshProfile,
                child: ListView(
                  physics:
                      const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(
                    top: 3,
                    bottom: 18,
                  ),
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

                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        8,
                        0,
                        8,
                        7,
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: CreditsStatus(
                              compact: true,
                              showRewardButton: false,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const RewardedAdButton(
                            compact: true,
                          ),
                        ],
                      ),
                    ),

                    ProfileActions(
                      onMessage: _showMessage,
                    ),

                    ProfileReminders(
                      reminders:
                          _reminderService.items,
                      onMessage: _showMessage,
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
