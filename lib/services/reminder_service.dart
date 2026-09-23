import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Represents one saved reminder.
class ReminderItem {
  final int id;
  final String title;
  final String category;
  final DateTime dateTime;
  final bool repeatDaily;
  final bool enabled;

  const ReminderItem({
    required this.id,
    required this.title,
    required this.category,
    required this.dateTime,
    required this.repeatDaily,
    required this.enabled,
  });

  ReminderItem copyWith({
    int? id,
    String? title,
    String? category,
    DateTime? dateTime,
    bool? repeatDaily,
    bool? enabled,
  }) {
    return ReminderItem(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      dateTime: dateTime ?? this.dateTime,
      repeatDaily: repeatDaily ?? this.repeatDaily,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'dateTime': dateTime.toIso8601String(),
      'repeatDaily': repeatDaily,
      'enabled': enabled,
    };
  }

  factory ReminderItem.fromJson(
    Map<String, dynamic> json,
  ) {
    final dynamic rawDate = json['dateTime'];

    DateTime parsedDate;

    if (rawDate is String) {
      parsedDate =
          DateTime.tryParse(rawDate) ??
          DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    return ReminderItem(
      id: _readInt(json['id']),
      title: (json['title'] ?? '').toString(),
      category:
          (json['category'] ?? 'شخصي').toString(),
      dateTime: parsedDate,
      repeatDaily:
          json['repeatDaily'] == true,
      enabled:
          json['enabled'] != false,
    );
  }

  static int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        DateTime.now()
            .millisecondsSinceEpoch;
  }
}

/// Complete reminder manager.
///
/// Responsibilities:
/// - Save reminders permanently.
/// - Load reminders after app restart.
/// - Request Android notification permission.
/// - Request exact-alarm permission.
/// - Schedule one-time reminders.
/// - Schedule daily reminders.
/// - Cancel reminders.
/// - Re-schedule reminders after changes.
class ReminderService {
  ReminderService._();

  static final ReminderService instance =
      ReminderService._();

  static const String _storageKey =
      'sa7bi_saved_reminders';

  static const String _channelId =
      'sa7bi_reminders';

  static const String _channelName =
      'تذكيرات صاحبي AI';

  static const String _channelDescription =
      'إشعارات التذكيرات الشخصية في تطبيق صاحبي AI';

  final ValueNotifier<List<ReminderItem>>
      reminders =
      ValueNotifier<List<ReminderItem>>(
    <ReminderItem>[],
  );

  final FlutterLocalNotificationsPlugin
      _notifications =
      FlutterLocalNotificationsPlugin();

  SharedPreferences? _prefs;

  bool _initialized = false;
  bool _notificationsInitialized = false;

  bool get isInitialized =>
      _initialized;

  bool get isNotificationsInitialized =>
      _notificationsInitialized;

  List<ReminderItem> get items =>
      List<ReminderItem>.unmodifiable(
        reminders.value,
      );

  List<ReminderItem> get enabledItems =>
      reminders.value
          .where(
            (ReminderItem reminder) =>
                reminder.enabled,
          )
          .toList(
            growable: false,
          );

  List<ReminderItem> get disabledItems =>
      reminders.value
          .where(
            (ReminderItem reminder) =>
                !reminder.enabled,
          )
          .toList(
            growable: false,
          );

  List<ReminderItem> byCategory(
    String category,
  ) {
    return reminders.value
        .where(
          (ReminderItem reminder) =>
              reminder.category == category,
        )
        .toList(
          growable: false,
        );
  }

  // ============================================================
  // INITIALIZATION
  // ============================================================

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _prefs =
        await SharedPreferences.getInstance();

    _initializeTimeZone();

    await _initializeNotifications();

    await _loadSavedReminders();

    _initialized = true;

    await rescheduleAll();
  }

  void _initializeTimeZone() {
    try {
      tz.initializeTimeZones();

      tz.setLocalLocation(
        tz.getLocation('Africa/Cairo'),
      );
    } catch (_) {
      // Keep the plugin usable if timezone
      // initialization fails.
    }
  }

  Future<void> _initializeNotifications() async {
    if (_notificationsInitialized) {
      return;
    }

    const AndroidInitializationSettings
        androidSettings =
        AndroidInitializationSettings(
      'app_icon',
    );

    const InitializationSettings
        settings =
        InitializationSettings(
      android: androidSettings,
    );

    // flutter_local_notifications 22.x:
    // settings is a named parameter.
    await _notifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse:
          _onNotificationTapped,
    );

    final AndroidFlutterLocalNotificationsPlugin?
        android =
        _notifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

    if (android != null) {
      try {
        await android
            .requestNotificationsPermission();
      } catch (_) {
        // Permission can be requested later.
      }

      try {
        await android
            .requestExactAlarmsPermission();
      } catch (_) {
        // Exact alarms may already be granted
        // or unavailable.
      }

      const AndroidNotificationChannel
          channel =
          AndroidNotificationChannel(
        _channelId,
        _channelName,
        description:
            _channelDescription,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      try {
        await android
            .createNotificationChannel(
          channel,
        );
      } catch (_) {
        // Channel may already exist.
      }
    }

    _notificationsInitialized = true;
  }

  void _onNotificationTapped(
    NotificationResponse response,
  ) {
    // The payload contains the reminder ID.
    //
    // Navigation can be connected later if needed.
  }

  // ============================================================
  // STORAGE
  // ============================================================

  Future<void> _loadSavedReminders() async {
    final String? raw =
        _prefs!.getString(_storageKey);

    if (raw == null ||
        raw.trim().isEmpty) {
      reminders.value =
          <ReminderItem>[];
      return;
    }

    try {
      final dynamic decoded =
          jsonDecode(raw);

      if (decoded is! List) {
        reminders.value =
            <ReminderItem>[];
        return;
      }

      final List<ReminderItem> loaded =
          <ReminderItem>[];

      for (final dynamic item
          in decoded) {
        if (item is Map) {
          try {
            final ReminderItem reminder =
                ReminderItem.fromJson(
              Map<String, dynamic>.from(
                item,
              ),
            );

            if (reminder.title
                .trim()
                .isNotEmpty) {
              loaded.add(reminder);
            }
          } catch (_) {
            // Ignore only the damaged reminder.
          }
        }
      }

      reminders.value = loaded;
    } catch (_) {
      reminders.value =
          <ReminderItem>[];
    }
  }

  Future<void> _save() async {
    final String encoded =
        jsonEncode(
      reminders.value
          .map(
            (ReminderItem reminder) =>
                reminder.toJson(),
          )
          .toList(),
    );

    await _prefs!.setString(
      _storageKey,
      encoded,
    );
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  // ============================================================
  // ADD
  // ============================================================

  Future<ReminderItem> addReminder({
    required String title,
    required String category,
    required DateTime dateTime,
    bool repeatDaily = false,
    bool enabled = true,
  }) async {
    await _ensureInitialized();

    final String cleanTitle =
        title.trim();

    if (cleanTitle.isEmpty) {
      throw ArgumentError(
        'عنوان التذكير لا يمكن أن يكون فارغًا.',
      );
    }

    final DateTime localDateTime =
        dateTime.toLocal();

    final ReminderItem reminder =
        ReminderItem(
      id: _createId(),
      title: cleanTitle,
      category:
          category.trim().isEmpty
              ? 'شخصي'
              : category.trim(),
      dateTime: localDateTime,
      repeatDaily: repeatDaily,
      enabled: enabled,
    );

    final List<ReminderItem> updated =
        List<ReminderItem>.from(
      reminders.value,
    );

    updated.add(reminder);

    reminders.value = updated;

    await _save();

    if (reminder.enabled) {
      await scheduleReminder(
        reminder,
      );
    }

    return reminder;
  }

  // ============================================================
  // UPDATE
  // ============================================================

  Future<bool> updateReminder(
    ReminderItem updatedReminder,
  ) async {
    await _ensureInitialized();

    final List<ReminderItem> updated =
        List<ReminderItem>.from(
      reminders.value,
    );

    final int index =
        updated.indexWhere(
      (ReminderItem item) =>
          item.id ==
          updatedReminder.id,
    );

    if (index == -1) {
      return false;
    }

    await cancelNotification(
      updatedReminder.id,
    );

    updated[index] =
        updatedReminder.copyWith(
      dateTime:
          updatedReminder.dateTime.toLocal(),
    );

    reminders.value = updated;

    await _save();

    if (updated[index].enabled) {
      await scheduleReminder(
        updated[index],
      );
    }

    return true;
  }

  // ============================================================
  // ENABLE / DISABLE
  // ============================================================

  Future<bool> setEnabled(
    int id,
    bool enabled,
  ) async {
    await _ensureInitialized();

    final ReminderItem? current =
        findById(id);

    if (current == null) {
      return false;
    }

    return updateReminder(
      current.copyWith(
        enabled: enabled,
      ),
    );
  }

  Future<bool> toggle(
    int id,
  ) async {
    await _ensureInitialized();

    final ReminderItem? current =
        findById(id);

    if (current == null) {
      return false;
    }

    return updateReminder(
      current.copyWith(
        enabled: !current.enabled,
      ),
    );
  }

  // ============================================================
  // DELETE
  // ============================================================

  Future<bool> deleteReminder(
    int id,
  ) async {
    await _ensureInitialized();

    final int oldLength =
        reminders.value.length;

    await cancelNotification(id);

    final List<ReminderItem> updated =
        List<ReminderItem>.from(
      reminders.value,
    );

    updated.removeWhere(
      (ReminderItem item) =>
          item.id == id,
    );

    if (updated.length ==
        oldLength) {
      return false;
    }

    reminders.value = updated;

    await _save();

    return true;
  }

  Future<void> clearAll() async {
    await _ensureInitialized();

    reminders.value =
        <ReminderItem>[];

    await _save();

    await _notifications.cancelAll();
  }

  // ============================================================
  // SCHEDULING
  // ============================================================

  Future<void> scheduleReminder(
    ReminderItem reminder,
  ) async {
    await _ensureInitialized();

    await cancelNotification(
      reminder.id,
    );

    if (!reminder.enabled) {
      return;
    }

    final DateTime now =
        DateTime.now();

    DateTime scheduledDate =
        reminder.dateTime.toLocal();

    if (reminder.repeatDaily) {
      scheduledDate = DateTime(
        now.year,
        now.month,
        now.day,
        reminder.dateTime.hour,
        reminder.dateTime.minute,
      );

      if (!scheduledDate
          .isAfter(now)) {
        scheduledDate =
            scheduledDate.add(
          const Duration(days: 1),
        );
      }
    } else {
      if (!scheduledDate
          .isAfter(now)) {
        return;
      }
    }

    final tz.TZDateTime tzDate =
        tz.TZDateTime.from(
      scheduledDate,
      tz.local,
    );

    const AndroidNotificationDetails
        androidDetails =
        AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription:
          _channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: 'app_icon',
      category:
          AndroidNotificationCategory.reminder,
    );

    const NotificationDetails details =
        NotificationDetails(
      android: androidDetails,
    );

    await _notifications.zonedSchedule(
      id: reminder.id,
      title: 'تذكير من صاحبي AI',
      body: reminder.title,
      scheduledDate: tzDate,
      notificationDetails: details,
      androidScheduleMode:
          AndroidScheduleMode
              .exactAllowWhileIdle,
      payload:
          null,
      matchDateTimeComponents:
          reminder.repeatDaily
              ? DateTimeComponents.time
              : null,
    );
  }

  Future<void> rescheduleAll() async {
    await _ensureInitialized();

    for (final ReminderItem reminder
        in reminders.value) {
      if (!reminder.enabled) {
        await cancelNotification(
          reminder.id,
        );
        continue;
      }

      try {
        await scheduleReminder(
          reminder,
        );
      } catch (_) {
        // Do not let one invalid reminder
        // prevent all others from loading.
      }
    }
  }

  Future<void> cancelNotification(
    int id,
  ) async {
    if (!_notificationsInitialized) {
      return;
    }

    try {
      await _notifications.cancel(
        id: id,
      );
    } catch (_) {
      // Ignore cancellation errors.
    }
  }

  // ============================================================
  // TEST NOTIFICATION
  // ============================================================

  Future<void> showTestNotification() async {
    await _ensureInitialized();

    const AndroidNotificationDetails
        androidDetails =
        AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription:
          _channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: 'app_icon',
    );

    const NotificationDetails details =
        NotificationDetails(
      android: androidDetails,
    );

    await _notifications.show(
      id: 999999,
      title: 'صاحبي AI',
      body:
          'نظام التذكيرات يعمل بنجاح.',
      notificationDetails: details,
      payload: 'test',
    );
  }

  // ============================================================
  // PERMISSIONS
  // ============================================================

  Future<bool>
      areNotificationsEnabled() async {
    await _ensureInitialized();

    final AndroidFlutterLocalNotificationsPlugin?
        android =
        _notifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

    if (android == null) {
      return true;
    }

    try {
      return await android
              .areNotificationsEnabled() ??
          false;
    } catch (_) {
      return false;
    }
  }

  // ============================================================
  // FIND / FILTER
  // ============================================================

  ReminderItem? findById(int id) {
    for (final ReminderItem reminder
        in reminders.value) {
      if (reminder.id == id) {
        return reminder;
      }
    }

    return null;
  }

  List<ReminderItem> upcoming({
    Duration window =
        const Duration(days: 30),
  }) {
    final DateTime now =
        DateTime.now();

    final DateTime end =
        now.add(window);

    final List<ReminderItem> result =
        reminders.value
            .where(
              (ReminderItem reminder) =>
                  reminder.enabled &&
                  reminder.dateTime
                      .isAfter(now) &&
                  reminder.dateTime
                      .isBefore(end),
            )
            .toList();

    result.sort(
      (ReminderItem a, ReminderItem b) =>
          a.dateTime.compareTo(
        b.dateTime,
      ),
    );

    return List<ReminderItem>
        .unmodifiable(result);
  }

  ReminderItem? get nextReminder {
    final DateTime now =
        DateTime.now();

    final List<ReminderItem> active =
        reminders.value
            .where(
              (ReminderItem reminder) =>
                  reminder.enabled,
            )
            .toList();

    if (active.isEmpty) {
      return null;
    }

    active.sort(
      (ReminderItem a, ReminderItem b) {
        final DateTime aNext =
            _nextOccurrence(
          a,
          now,
        );

        final DateTime bNext =
            _nextOccurrence(
          b,
          now,
        );

        return aNext.compareTo(
          bNext,
        );
      },
    );

    return active.first;
  }

  DateTime _nextOccurrence(
    ReminderItem reminder,
    DateTime now,
  ) {
    if (!reminder.repeatDaily) {
      return reminder.dateTime;
    }

    DateTime next = DateTime(
      now.year,
      now.month,
      now.day,
      reminder.dateTime.hour,
      reminder.dateTime.minute,
    );

    if (!next.isAfter(now)) {
      next = next.add(
        const Duration(days: 1),
      );
    }

    return next;
  }

  int _createId() {
    int id =
        DateTime.now()
            .millisecondsSinceEpoch;

    while (reminders.value.any(
      (ReminderItem reminder) =>
          reminder.id == id,
    )) {
      id++;
    }

    return id;
  }

  void dispose() {
    reminders.dispose();
  }
}
