import 'package:flutter/material.dart';

import 'services/reminder_service.dart';

/// واجهة إدارة التذكيرات المحفوظة في التطبيق.
/// تعتمد على ReminderService الحالية حتى لا تنشئ نظام تخزين أو جدولة موازيًا.
class ReminderSettingsScreen extends StatefulWidget {
  const ReminderSettingsScreen({super.key});

  @override
  State<ReminderSettingsScreen> createState() =>
      _ReminderSettingsScreenState();
}

class _ReminderSettingsScreenState extends State<ReminderSettingsScreen> {
  final ReminderService _service = ReminderService.instance;

  bool _initializing = true;
  bool _notificationsEnabled = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _service.initialize();
      final enabled = await _service.areNotificationsEnabled();
      if (!mounted) return;
      setState(() {
        _notificationsEnabled = enabled;
        _initializing = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _error = 'تعذر تهيئة نظام التذكيرات على هذا الجهاز.';
      });
    }
  }

  Future<void> _refreshPermission() async {
    try {
      final enabled = await _service.areNotificationsEnabled();
      if (!mounted) return;
      setState(() => _notificationsEnabled = enabled);
    } catch (_) {
      if (!mounted) return;
      setState(() => _notificationsEnabled = false);
    }
  }

  Future<void> _showTestNotification() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _service.showTestNotification();
      await _refreshPermission();
      _showMessage('تم إرسال تنبيه تجريبي. راجع إشعارات الهاتف.');
    } catch (_) {
      _showMessage('تعذر إرسال التنبيه التجريبي. راجع إذن الإشعارات من إعدادات الهاتف.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addReminder() async {
    final draft = await showDialog<_ReminderDraft>(
      context: context,
      builder: (_) => const _ReminderEditorDialog(),
    );
    if (draft == null) return;

    await _runAction(() async {
      await _service.addReminder(
        title: draft.title,
        category: draft.category,
        dateTime: draft.dateTime,
        repeatDaily: draft.repeatDaily,
      );
      _showMessage('تم حفظ التذكير وجدولته.');
    });
  }

  Future<void> _editReminder(ReminderItem reminder) async {
    final draft = await showDialog<_ReminderDraft>(
      context: context,
      builder: (_) => _ReminderEditorDialog(reminder: reminder),
    );
    if (draft == null) return;

    await _runAction(() async {
      final updated = reminder.copyWith(
        title: draft.title,
        category: draft.category,
        dateTime: draft.dateTime,
        repeatDaily: draft.repeatDaily,
      );
      final saved = await _service.updateReminder(updated);
      if (!saved) throw StateError('Reminder not found');
      _showMessage('تم تحديث التذكير.');
    });
  }

  Future<void> _toggleReminder(ReminderItem reminder, bool enabled) async {
    await _runAction(() async {
      final changed = await _service.setEnabled(reminder.id, enabled);
      if (!changed) throw StateError('Reminder not found');
      _showMessage(enabled ? 'تم تفعيل التذكير.' : 'تم إيقاف التذكير.');
    });
  }

  Future<void> _deleteReminder(ReminderItem reminder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف التذكير؟'),
        content: Text('سيتم حذف «${reminder.title}» وإلغاء إشعاره المجدول.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _runAction(() async {
      final deleted = await _service.deleteReminder(reminder.id);
      if (!deleted) throw StateError('Reminder not found');
      _showMessage('تم حذف التذكير.');
    });
  }

  Future<void> _runAction(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      await _refreshPermission();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'لم نتمكن من تنفيذ العملية. حاول مرة أخرى.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _dateLabel(DateTime value) {
    final date = value.toLocal();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/$year  •  $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF080C16),
        appBar: AppBar(
          backgroundColor: const Color(0xFF111827),
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'التذكيرات والإشعارات',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          actions: [
            IconButton(
              tooltip: 'تحديث حالة الإشعارات',
              onPressed: _initializing ? null : _refreshPermission,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        floatingActionButton: _initializing
            ? null
            : FloatingActionButton.extended(
                onPressed: _busy ? null : _addReminder,
                icon: const Icon(Icons.add_alarm_rounded),
                label: const Text('إضافة تذكير'),
              ),
        body: _initializing
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _initialize,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
                  children: [
                    _notificationStatusCard(),
                    const SizedBox(height: 12),
                    if (_error != null) ...[
                      _errorCard(_error!),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'التذكيرات المحفوظة',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        ValueListenableBuilder<List<ReminderItem>>(
                          valueListenable: _service.reminders,
                          builder: (_, items, __) => Text(
                            '${items.length}',
                            style: const TextStyle(
                              color: Color(0xFF5DE1E6),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ValueListenableBuilder<List<ReminderItem>>(
                      valueListenable: _service.reminders,
                      builder: (context, items, _) {
                        if (items.isEmpty) return _emptyState();
                        final sorted = [...items]
                          ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
                        return Column(
                          children: [
                            for (final reminder in sorted)
                              _reminderCard(reminder),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'ملاحظة: ظهور التنبيه يعتمد على سماح الهاتف بالإشعارات والتنبيهات الدقيقة، وعلى قيود توفير البطارية في الجهاز.',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _notificationStatusCard() {
    final color = _notificationsEnabled
        ? const Color(0xFF61DDAA)
        : const Color(0xFFFFB86B);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF121B2B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                _notificationsEnabled
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_off_rounded,
                color: color,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  _notificationsEnabled
                      ? 'إشعارات التطبيق مفعّلة'
                      : 'الإشعارات متوقفة أو غير مسموح بها',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'تقدر تضيف تذكير مرة واحدة أو تذكير يومي، وتعدّل موعده أو توقفه وتحذفه من هنا.',
            style: TextStyle(color: Colors.white70, height: 1.45),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _showTestNotification,
            icon: const Icon(Icons.notifications_rounded),
            label: const Text('إرسال تنبيه تجريبي'),
          ),
        ],
      ),
    );
  }

  Widget _reminderCard(ReminderItem reminder) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF5DE1E6).withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.alarm_rounded,
                  color: Color(0xFF5DE1E6),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reminder.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${reminder.category}  •  ${reminder.repeatDaily ? 'يومي' : 'مرة واحدة'}',
                      style: const TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                    Text(
                      _dateLabel(reminder.dateTime),
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: reminder.enabled,
                onChanged: _busy
                    ? null
                    : (value) => _toggleReminder(reminder, value),
                activeTrackColor: const Color(0xFF5DE1E6),
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 20),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: _busy ? null : () => _editReminder(reminder),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('تعديل'),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: _busy ? null : () => _deleteReminder(reminder),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('حذف'),
                  style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: const Column(
        children: [
          Icon(Icons.alarm_add_rounded, color: Colors.white38, size: 42),
          SizedBox(height: 9),
          Text(
            'لسه مفيش تذكيرات',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 5),
          Text(
            'اضغط «إضافة تذكير» علشان تحفظ أول موعد ليك.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _errorCard(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF3A1D28),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.redAccent.withValues(alpha: .35)),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white)),
    );
  }
}

class _ReminderDraft {
  const _ReminderDraft({
    required this.title,
    required this.category,
    required this.dateTime,
    required this.repeatDaily,
  });

  final String title;
  final String category;
  final DateTime dateTime;
  final bool repeatDaily;
}

class _ReminderEditorDialog extends StatefulWidget {
  const _ReminderEditorDialog({this.reminder});

  final ReminderItem? reminder;

  @override
  State<_ReminderEditorDialog> createState() => _ReminderEditorDialogState();
}

class _ReminderEditorDialogState extends State<_ReminderEditorDialog> {
  static const List<String> _categories = [
    'شخصي',
    'عمل',
    'دراسة',
    'عبادة',
    'صحة',
    'متابعة',
  ];

  late final TextEditingController _titleController;
  late String _category;
  late DateTime _date;
  late TimeOfDay _time;
  late bool _repeatDaily;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    final existing = widget.reminder;
    final initial = existing?.dateTime.toLocal() ??
        DateTime.now().add(const Duration(hours: 1));
    _titleController = TextEditingController(text: existing?.title ?? '');
    _category = _categories.contains(existing?.category)
        ? existing!.category
        : _categories.first;
    _date = DateTime(initial.year, initial.month, initial.day);
    _time = TimeOfDay.fromDateTime(initial);
    _repeatDaily = existing?.repeatDaily ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(DateTime(now.year, now.month, now.day))
          ? DateTime(now.year, now.month, now.day)
          : _date,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 10),
    );
    if (selected != null && mounted) setState(() => _date = selected);
  }

  Future<void> _pickTime() async {
    final selected = await showTimePicker(context: context, initialTime: _time);
    if (selected != null && mounted) setState(() => _time = selected);
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _validationError = 'اكتب عنوان التذكير أولًا.');
      return;
    }
    final scheduled = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );
    if (!_repeatDaily && !scheduled.isAfter(DateTime.now())) {
      setState(() => _validationError = 'اختار موعدًا في المستقبل.');
      return;
    }
    Navigator.of(context).pop(
      _ReminderDraft(
        title: title,
        category: _category,
        dateTime: scheduled,
        repeatDaily: _repeatDaily,
      ),
    );
  }

  String get _dateLabel {
    final day = _date.day.toString().padLeft(2, '0');
    final month = _date.month.toString().padLeft(2, '0');
    final year = _date.year.toString();
    return '$day/$month/$year';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: const Color(0xFF111827),
        title: Text(
          widget.reminder == null ? 'إضافة تذكير' : 'تعديل التذكير',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _titleController,
                autofocus: true,
                maxLength: 100,
                textDirection: TextDirection.rtl,
                decoration: const InputDecoration(
                  labelText: 'عنوان التذكير',
                  hintText: 'مثال: موعد مهم أو قراءة الورد',
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(labelText: 'التصنيف'),
                items: [
                  for (final category in _categories)
                    DropdownMenuItem(value: category, child: Text(category)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _category = value);
                },
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_month_rounded),
                label: Text('التاريخ: $_dateLabel'),
              ),
              OutlinedButton.icon(
                onPressed: _pickTime,
                icon: const Icon(Icons.schedule_rounded),
                label: Text('الوقت: ${_time.format(context)}'),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _repeatDaily,
                onChanged: (value) => setState(() => _repeatDaily = value),
                title: const Text('يتكرر يوميًا'),
              ),
              if (_validationError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _validationError!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: _save,
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}
