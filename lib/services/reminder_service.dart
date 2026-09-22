import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Represents one saved reminder.
///
/// The reminder data is kept separate from ProfileService because
/// reminders are their own feature and should not modify the existing
/// profile storage.
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

  factory ReminderItem.fromJson(Map<String, dynamic> json) {
    final rawDate = json['dateTime'];

    DateTime parsedDate;

    if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    return ReminderItem(
      id: _readInt(json['id']),
      title: (json['title'] ?? '').toString(),
      category: (json['category'] ?? 'شخصي').toString(),
      dateTime: parsedDate,
      repeatDaily: json['repeatDaily'] == true,
      enabled: json['enabled'] != false,
    );
  }

  static int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ??
        DateTime.now().millisecondsSinceEpoch;
  }
}

/// Persistent reminder storage and state.
///
/// Notification scheduling is intentionally kept behind this service.
/// The actual platform notification implementation will be connected
/// in the next step, without changing the existing profile system.
class ReminderService {
  ReminderService._();

  static final ReminderService instance = ReminderService._();

  static const String _storageKey = 'sa7bi_saved_reminders';

  final ValueNotifier<List<ReminderItem>> reminders =
      ValueNotifier<List<ReminderItem>>(<ReminderItem>[]);

  SharedPreferences? _prefs;
  bool _initialized = false;

  bool get isInitialized => _initialized;

  List<ReminderItem> get items =>
      List<ReminderItem>.unmodifiable(reminders.value);

  List<ReminderItem> get enabledItems => reminders.value
      .where((ReminderItem reminder) => reminder.enabled)
      .toList(growable: false);

  List<ReminderItem> get disabledItems => reminders.value
      .where((ReminderItem reminder) => !reminder.enabled)
      .toList(growable: false);

  List<ReminderItem> byCategory(String category) {
    return reminders.value
        .where(
          (ReminderItem reminder) =>
              reminder.category == category,
        )
        .toList(growable: false);
  }

  /// Initializes the reminder database.
  ///
  /// Safe to call more than once.
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _prefs = await SharedPreferences.getInstance();

    final String? raw = _prefs!.getString(_storageKey);

    if (raw == null || raw.trim().isEmpty) {
      reminders.value = <ReminderItem>[];
      _initialized = true;
      return;
    }

    try {
      final dynamic decoded = jsonDecode(raw);

      if (decoded is List) {
        final List<ReminderItem> loaded = <ReminderItem>[];

        for (final dynamic item in decoded) {
          if (item is Map) {
            try {
              loaded.add(
                ReminderItem.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              );
            } catch (_) {
              // Ignore one damaged reminder instead of breaking
              // the complete reminder database.
            }
          }
        }

        reminders.value = loaded;
      } else {
        reminders.value = <ReminderItem>[];
      }
    } catch (_) {
      // If the stored JSON is damaged, start with an empty list.
      // Existing profile data remains untouched.
      reminders.value = <ReminderItem>[];
    }

    _initialized = true;
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  Future<void> _save() async {
    await _ensureInitialized();

    final String encoded = jsonEncode(
      reminders.value
          .map((ReminderItem reminder) => reminder.toJson())
          .toList(),
    );

    await _prefs!.setString(_storageKey, encoded);
  }

  /// Creates a new reminder.
  ///
  /// Returns the newly created reminder.
  Future<ReminderItem> addReminder({
    required String title,
    required String category,
    required DateTime dateTime,
    bool repeatDaily = false,
    bool enabled = true,
  }) async {
    await _ensureInitialized();

    final String cleanTitle = title.trim();

    if (cleanTitle.isEmpty) {
      throw ArgumentError('عنوان التذكير لا يمكن أن يكون فارغًا.');
    }

    final int id = _createId();

    final ReminderItem reminder = ReminderItem(
      id: id,
      title: cleanTitle,
      category: category.trim().isEmpty ? 'شخصي' : category.trim(),
      dateTime: dateTime,
      repeatDaily: repeatDaily,
      enabled: enabled,
    );

    final List<ReminderItem> updated =
        List<ReminderItem>.from(reminders.value);

    updated.add(reminder);

    reminders.value = updated;

    await _save();

    return reminder;
  }

  /// Updates an existing reminder.
  Future<bool> updateReminder(ReminderItem updatedReminder) async {
    await _ensureInitialized();

    final List<ReminderItem> updated =
        List<ReminderItem>.from(reminders.value);

    final int index = updated.indexWhere(
      (ReminderItem item) => item.id == updatedReminder.id,
    );

    if (index == -1) {
      return false;
    }

    updated[index] = updatedReminder;

    reminders.value = updated;

    await _save();

    return true;
  }

  /// Changes only the enabled/disabled state.
  Future<bool> setEnabled(
    int id,
    bool enabled,
  ) async {
    await _ensureInitialized();

    final int index = reminders.value.indexWhere(
      (ReminderItem item) => item.id == id,
    );

    if (index == -1) {
      return false;
    }

    final ReminderItem current = reminders.value[index];

    return updateReminder(
      current.copyWith(enabled: enabled),
    );
  }

  /// Toggles an existing reminder.
  Future<bool> toggle(int id) async {
    await _ensureInitialized();

    final int index = reminders.value.indexWhere(
      (ReminderItem item) => item.id == id,
    );

    if (index == -1) {
      return false;
    }

    final ReminderItem current = reminders.value[index];

    return updateReminder(
      current.copyWith(
        enabled: !current.enabled,
      ),
    );
  }

  /// Deletes one reminder.
  Future<bool> deleteReminder(int id) async {
    await _ensureInitialized();

    final List<ReminderItem> updated =
        List<ReminderItem>.from(reminders.value);

    final int oldLength = updated.length;

    updated.removeWhere(
      (ReminderItem item) => item.id == id,
    );

    if (updated.length == oldLength) {
      return false;
    }

    reminders.value = updated;

    await _save();

    return true;
  }

  /// Deletes all reminders.
  Future<void> clearAll() async {
    await _ensureInitialized();

    reminders.value = <ReminderItem>[];

    await _save();
  }

  ReminderItem? findById(int id) {
    for (final ReminderItem reminder in reminders.value) {
      if (reminder.id == id) {
        return reminder;
      }
    }

    return null;
  }

  /// Returns reminders that should be considered upcoming.
  ///
  /// This is useful for the profile screen and for the notification
  /// scheduler that will be connected next.
  List<ReminderItem> upcoming({
    Duration window = const Duration(days: 30),
  }) {
    final DateTime now = DateTime.now();
    final DateTime end = now.add(window);

    return reminders.value
        .where(
          (ReminderItem reminder) =>
              reminder.enabled &&
              reminder.dateTime.isAfter(now) &&
              reminder.dateTime.isBefore(end),
        )
        .toList(growable: false)
      ..sort(
        (ReminderItem a, ReminderItem b) =>
            a.dateTime.compareTo(b.dateTime),
      );
  }

  /// Returns the next enabled reminder.
  ReminderItem? get nextReminder {
    final List<ReminderItem> list = upcoming(
      window: const Duration(days: 3650),
    );

    if (list.isEmpty) {
      return null;
    }

    return list.first;
  }

  /// Creates a reasonably unique local ID.
  int _createId() {
    int id = DateTime.now().millisecondsSinceEpoch;

    while (reminders.value.any(
      (ReminderItem reminder) => reminder.id == id,
    )) {
      id++;
    }

    return id;
  }

  void dispose() {
    reminders.dispose();
  }
}
