import 'package:flutter/material.dart';

import '../services/reminder_service.dart';

class ProfileReminders extends StatefulWidget {
  final List<ReminderItem> reminders;
  final void Function(String message) onMessage;

  const ProfileReminders({
    super.key,
    required this.reminders,
    required this.onMessage,
  });

  @override
  State<ProfileReminders> createState() => _ProfileRemindersState();
}

class _ProfileRemindersState extends State<ProfileReminders> {
  Future<void> _openEditor({
    required String category,
    ReminderItem? existing,
  }) async {
    final titleController = TextEditingController(
      text: existing?.title ?? '',
    );

    DateTime selectedDate =
        existing?.dateTime ?? DateTime.now().add(
          const Duration(minutes: 5),
        );

    TimeOfDay selectedTime = TimeOfDay(
      hour: existing?.dateTime.hour ?? TimeOfDay.now().hour,
      minute: existing?.dateTime.minute ?? TimeOfDay.now().minute,
    );

    bool repeatDaily = existing?.repeatDaily ?? false;
    bool enabled = existing?.enabled ?? true;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF12151F),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      18,
                      14,
                      18,
                      22,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 45,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        Text(
                          existing == null
                              ? 'تذكير جديد'
                              : 'تعديل التذكير',
                          textDirection: TextDirection.rtl,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),

                        const SizedBox(height: 5),

                        Text(
                          category,
                          textDirection: TextDirection.rtl,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: Color(0xFFFFD76A),
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 16),

                        TextField(
                          controller: titleController,
                          autofocus: existing == null,
                          textDirection: TextDirection.rtl,
                          textAlign: TextAlign.right,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'نص التذكير',
                            hintText: 'مثال: صلاة الفجر أو التمرين',
                            prefixIcon: const Icon(
                              Icons.edit_note_rounded,
                            ),
                            filled: true,
                            fillColor: const Color(0xFF0C0F17),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        _OptionTile(
                          icon: Icons.calendar_month_rounded,
                          title: 'التاريخ',
                          value: _formatDate(selectedDate),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate.isBefore(
                                DateTime.now(),
                              )
                                  ? DateTime.now()
                                  : selectedDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(
                                const Duration(days: 3650),
                              ),
                            );

                            if (picked == null) return;

                            setModalState(() {
                              selectedDate = DateTime(
                                picked.year,
                                picked.month,
                                picked.day,
                                selectedTime.hour,
                                selectedTime.minute,
                              );
                            });
                          },
                        ),

                        const SizedBox(height: 8),

                        _OptionTile(
                          icon: Icons.access_time_rounded,
                          title: 'الوقت',
                          value: selectedTime.format(context),
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: selectedTime,
                            );

                            if (picked == null) return;

                            setModalState(() {
                              selectedTime = picked;

                              selectedDate = DateTime(
                                selectedDate.year,
                                selectedDate.month,
                                selectedDate.day,
                                picked.hour,
                                picked.minute,
                              );
                            });
                          },
                        ),

                        const SizedBox(height: 8),

                        _SwitchTile(
                          value: repeatDaily,
                          title: 'تكرار يومي',
                          subtitle: 'نفس الوقت كل يوم',
                          onChanged: (value) {
                            setModalState(() {
                              repeatDaily = value;
                            });
                          },
                        ),

                        const SizedBox(height: 8),

                        _SwitchTile(
                          value: enabled,
                          title: 'التذكير مفعّل',
                          subtitle: 'يمكنك إيقافه وتشغيله لاحقًا',
                          onChanged: (value) {
                            setModalState(() {
                              enabled = value;
                            });
                          },
                        ),

                        const SizedBox(height: 18),

                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: () async {
                              final title =
                                  titleController.text.trim();

                              if (title.isEmpty) {
                                ScaffoldMessenger.of(context)
                                  ..hideCurrentSnackBar()
                                  ..showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'اكتب نص التذكير أولًا',
                                        textDirection: TextDirection.rtl,
                                      ),
                                    ),
                                  );
                                return;
                              }

                              final finalDateTime = DateTime(
                                selectedDate.year,
                                selectedDate.month,
                                selectedDate.day,
                                selectedTime.hour,
                                selectedTime.minute,
                              );

                              try {
                                if (existing == null) {
                                  await ReminderService.instance
                                      .addReminder(
                                    title: title,
                                    category: category,
                                    dateTime: finalDateTime,
                                    repeatDaily: repeatDaily,
                                    enabled: enabled,
                                  );
                                } else {
                                  await ReminderService.instance
                                      .updateReminder(
                                    existing.copyWith(
                                      title: title,
                                      category: category,
                                      dateTime: finalDateTime,
                                      repeatDaily: repeatDaily,
                                      enabled: enabled,
                                    ),
                                  );
                                }

                                if (!sheetContext.mounted) return;

                                Navigator.of(sheetContext).pop(true);
                              } catch (_) {
                                if (!sheetContext.mounted) return;

                                Navigator.of(sheetContext).pop(false);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFD76A),
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              existing == null
                                  ? 'حفظ التذكير'
                                  : 'حفظ التعديل',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    titleController.dispose();

    if (result == true) {
      widget.onMessage(
        existing == null
            ? 'تم إضافة التذكير'
            : 'تم تعديل التذكير',
      );
    }
  }

  Future<void> _toggle(ReminderItem reminder) async {
    final success = await ReminderService.instance.toggle(
      reminder.id,
    );

    if (success) {
      widget.onMessage(
        reminder.enabled
            ? 'تم إيقاف التذكير'
            : 'تم تشغيل التذكير',
      );
    }
  }

  Future<void> _delete(ReminderItem reminder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF151925),
          title: const Text(
            'حذف التذكير؟',
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
          ),
          content: Text(
            reminder.title,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'حذف',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final success = await ReminderService.instance.deleteReminder(
      reminder.id,
    );

    if (success) {
      widget.onMessage('تم حذف التذكير');
    }
  }

  Future<void> _clearAll() async {
    if (widget.reminders.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF151925),
          title: const Text(
            'حذف كل التذكيرات؟',
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
          ),
          content: const Text(
            'سيتم حذف جميع التذكيرات المحفوظة.',
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'حذف الكل',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await ReminderService.instance.clearAll();

    widget.onMessage('تم حذف جميع التذكيرات');
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.reminders;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          textDirection: TextDirection.rtl,
          children: [
            const Expanded(
              child: Text(
                'التذكيرات',
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (items.isNotEmpty)
              TextButton(
                onPressed: _clearAll,
                child: const Text(
                  'حذف الكل',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 11,
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 8),

        _CategoryCard(
          icon: Icons.mosque_rounded,
          title: 'عبادات',
          subtitle: 'الصلاة والأذكار والعبادات',
          color: const Color(0xFF26A69A),
          onAdd: () => _openEditor(
            category: 'عبادات',
          ),
        ),

        _CategoryCard(
          icon: Icons.sports_soccer_rounded,
          title: 'هوايات',
          subtitle: 'رياضة وتمارين وهواياتك',
          color: const Color(0xFF2196F3),
          onAdd: () => _openEditor(
            category: 'هوايات',
          ),
        ),

        _CategoryCard(
          icon: Icons.notifications_active_rounded,
          title: 'شخصي',
          subtitle: 'أي تذكير آخر تحتاجه',
          color: const Color(0xFFB45CFF),
          onAdd: () => _openEditor(
            category: 'شخصي',
          ),
        ),

        const SizedBox(height: 10),

        if (items.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF131620),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white10,
              ),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.notifications_none_rounded,
                  size: 36,
                  color: Color(0xFFFFD76A),
                ),
                SizedBox(height: 8),
                Text(
                  'لا توجد تذكيرات حتى الآن',
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'اضغط + بجوار أي قسم لإضافة أول تذكير.',
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            children: [
              Row(
                textDirection: TextDirection.rtl,
                children: [
                  const Expanded(
                    child: Text(
                      'تذكيراتك المحفوظة',
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Text(
                    '${items.length}',
                    style: const TextStyle(
                      color: Color(0xFFFFD76A),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ...items.map(
                (reminder) => _SavedReminderTile(
                  reminder: reminder,
                  onToggle: () => _toggle(reminder),
                  onEdit: () => _openEditor(
                    category: reminder.category,
                    existing: reminder,
                  ),
                  onDelete: () => _delete(reminder),
                ),
              ),
            ],
          ),
      ],
    );
  }

  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}

class _CategoryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onAdd;

  const _CategoryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFF131620),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withOpacity(0.28),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onAdd,
            tooltip: 'إضافة تذكير',
            style: IconButton.styleFrom(
              backgroundColor: color.withOpacity(0.12),
            ),
            icon: Icon(
              Icons.add_alarm_rounded,
              color: color,
            ),
          ),
          const Spacer(),
          Expanded(
            flex: 7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  title,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.16),
              border: Border.all(
                color: color.withOpacity(0.4),
              ),
            ),
            child: Icon(
              icon,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedReminderTile extends StatelessWidget {
  final ReminderItem reminder;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SavedReminderTile({
    required this.reminder,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  Color get _color {
    switch (reminder.category) {
      case 'عبادات':
        return const Color(0xFF26A69A);
      case 'هوايات':
        return const Color(0xFF2196F3);
      default:
        return const Color(0xFFB45CFF);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF131620),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withOpacity(
            reminder.enabled ? 0.30 : 0.12,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          7,
          7,
          10,
          7,
        ),
        child: Row(
          children: [
            Switch(
              value: reminder.enabled,
              onChanged: (_) => onToggle(),
              activeThumbColor: const Color(0xFFFFD76A),
            ),

            IconButton(
              onPressed: onDelete,
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.redAccent,
                size: 21,
              ),
            ),

            IconButton(
              onPressed: onEdit,
              icon: const Icon(
                Icons.edit_rounded,
                color: Colors.white70,
                size: 20,
              ),
            ),

            const Spacer(),

            Expanded(
              flex: 7,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    reminder.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: reminder.enabled
                          ? Colors.white
                          : Colors.white38,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${_date(reminder.dateTime)} • '
                    '${TimeOfDay.fromDateTime(reminder.dateTime).format(context)}',
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (reminder.repeatDaily)
                        const Icon(
                          Icons.repeat_rounded,
                          size: 14,
                          color: Color(0xFFFFD76A),
                        ),
                      if (reminder.repeatDaily)
                        const SizedBox(width: 5),
                      Text(
                        reminder.category,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.12),
              ),
              child: Icon(
                reminder.repeatDaily
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_none_rounded,
                color: reminder.enabled
                    ? color
                    : Colors.white24,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _date(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}';
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF0C0F17),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(
                Icons.chevron_left_rounded,
                color: Colors.white38,
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    title,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFFD76A)
                      .withOpacity(0.12),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFFFFD76A),
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final bool value;
  final String title;
  final String subtitle;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0C0F17),
        borderRadius: BorderRadius.circular(16),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeThumbColor: const Color(0xFFFFD76A),
        title: Text(
          title,
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.right,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          subtitle,
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.right,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}
