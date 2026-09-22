import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import 'home_screen.dart';
import 'monetization_config.dart';
import 'services/profile_service.dart';
import 'services/reminder_service.dart';
import 'settings_screen.dart';

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
  final ImagePicker picker = ImagePicker();

  final TextEditingController nameController =
      TextEditingController();

  final ProfileService profileService =
      ProfileService.instance;

  final ReminderService reminderService =
      ReminderService.instance;

  Uint8List? photo;
  String? reelName;

  bool loadingProfile = true;
  bool loadingReminders = true;
  bool savingName = false;
  bool savingPhoto = false;
  bool savingReel = false;

  @override
  void initState() {
    super.initState();

    profileService.changes.addListener(
      _onProfileChanged,
    );

    reminderService.reminders.addListener(
      _onRemindersChanged,
    );

    _loadProfile();
    _loadReminders();
  }

  @override
  void dispose() {
    profileService.changes.removeListener(
      _onProfileChanged,
    );

    reminderService.reminders.removeListener(
      _onRemindersChanged,
    );

    nameController.dispose();

    super.dispose();
  }

  void _onProfileChanged() {
    if (!mounted) return;

    final newName = profileService.displayName;
    final newPhoto = profileService.photoBytes;

    final newReel = profileService.hasReel
        ? profileService.reelName
        : null;

    if (nameController.text != newName &&
        newName != ProfileService.defaultProfileName) {
      nameController.text = newName;
    }

    setState(() {
      photo = newPhoto;
      reelName = newReel;
      loadingProfile = false;
    });
  }

  void _onRemindersChanged() {
    if (!mounted) return;

    setState(() {
      loadingReminders = false;
    });
  }

  Future<void> _loadProfile() async {
    try {
      await profileService.initialize();

      if (!mounted) return;

      final savedName = profileService.displayName;
      final savedPhoto = profileService.photoBytes;

      final savedReel = profileService.hasReel
          ? profileService.reelName
          : null;

      setState(() {
        nameController.text =
            savedName == ProfileService.defaultProfileName
                ? ''
                : savedName;

        photo = savedPhoto;
        reelName = savedReel;
        loadingProfile = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        loadingProfile = false;
      });
    }
  }

  Future<void> _loadReminders() async {
    try {
      await reminderService.initialize();

      if (!mounted) return;

      setState(() {
        loadingReminders = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        loadingReminders = false;
      });
    }
  }

  Future<void> choosePhoto() async {
    if (savingPhoto) return;

    try {
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 900,
      );

      if (file == null) return;

      final bytes = await file.readAsBytes();

      if (bytes.isEmpty) return;

      if (!mounted) return;

      setState(() {
        savingPhoto = true;
      });

      final saved = await profileService.savePhotoBytes(
        bytes,
      );

      if (!mounted) return;

      setState(() {
        savingPhoto = false;
      });

      if (!saved) {
        _showMessage('لم يتم حفظ الصورة');
        return;
      }

      setState(() {
        photo = bytes;
      });

      _showMessage('تم حفظ صورة الحساب');
    } catch (_) {
      if (!mounted) return;

      setState(() {
        savingPhoto = false;
      });

      _showMessage('حدث خطأ أثناء اختيار الصورة');
    }
  }

  Future<void> chooseReel() async {
    if (savingReel) return;

    try {
      final file = await picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(
          minutes: 2,
        ),
      );

      if (file == null) return;

      if (!mounted) return;

      setState(() {
        savingReel = true;
      });

      final saved = await profileService.saveReelName(
        file.name,
      );

      if (!mounted) return;

      setState(() {
        savingReel = false;
      });

      if (!saved) {
        _showMessage('لم يتم حفظ الريلز');
        return;
      }

      setState(() {
        reelName = file.name;
      });

      _showMessage('تم حفظ الريلز');
    } catch (_) {
      if (!mounted) return;

      setState(() {
        savingReel = false;
      });

      _showMessage(
        'حدث خطأ أثناء اختيار الريلز',
      );
    }
  }

  Future<void> saveName() async {
    if (savingName) return;

    final name = nameController.text.trim();

    if (name.isEmpty) {
      _showMessage('اكتب اسمك أولًا');
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      savingName = true;
    });

    final saved = await profileService.saveName(
      name,
    );

    if (!mounted) return;

    setState(() {
      savingName = false;
    });

    if (!saved) {
      _showMessage('لم يتم حفظ الاسم');
      return;
    }

    _showMessage('تم حفظ الاسم');
  }

  Future<void> shareApp() async {
    try {
      final url = MonetizationConfig.appDownloadUrl;

      await Share.share(
        'جرّب تطبيق صاحبي AI 🤖\n'
        'مساعدك الذكي في كل يوم.\n\n'
        'رابط التحميل:\n'
        '$url',
        subject: 'صاحبي AI',
      );
    } catch (_) {}
  }

  // ==========================================================
  // REMINDERS
  // ==========================================================

  Future<void> _openAddReminder(
    String category,
  ) async {
    await _showReminderEditor(
      category: category,
    );
  }

  Future<void> _openEditReminder(
    ReminderItem reminder,
  ) async {
    await _showReminderEditor(
      category: reminder.category,
      existing: reminder,
    );
  }

  Future<void> _showReminderEditor({
    required String category,
    ReminderItem? existing,
  }) async {
    final TextEditingController titleController =
        TextEditingController(
      text: existing?.title ?? '',
    );

    DateTime selectedDate =
        existing?.dateTime ?? DateTime.now();

    TimeOfDay selectedTime = TimeOfDay(
      hour: existing?.dateTime.hour ??
          TimeOfDay.now().hour,
      minute: existing?.dateTime.minute ??
          TimeOfDay.now().minute,
    );

    bool repeatDaily =
        existing?.repeatDaily ?? false;

    bool enabled =
        existing?.enabled ?? true;

    final bool editing = existing != null;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (
            context,
            setModalState,
          ) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context)
                    .viewInsets
                    .bottom,
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
                      crossAxisAlignment:
                          CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 45,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius:
                                  BorderRadius.circular(20),
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        Text(
                          editing
                              ? 'تعديل التذكير'
                              : 'تذكير جديد',
                          textDirection:
                              TextDirection.rtl,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),

                        const SizedBox(height: 5),

                        Text(
                          category,
                          textDirection:
                              TextDirection.rtl,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: Color(0xFFFFD76A),
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 16),

                        TextField(
                          controller: titleController,
                          autofocus: !editing,
                          textDirection:
                              TextDirection.rtl,
                          textAlign: TextAlign.right,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'نص التذكير',
                            hintText:
                                'مثال: صلاة الفجر أو التمرين',
                            prefixIcon: const Icon(
                              Icons.edit_note_rounded,
                            ),
                            filled: true,
                            fillColor:
                                const Color(0xFF0C0F17),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        _ReminderOptionTile(
                          icon: Icons.calendar_month_rounded,
                          title: 'التاريخ',
                          value: _formatDate(
                            selectedDate,
                          ),
                          onTap: () async {
                            final DateTime? picked =
                                await showDatePicker(
                              context: context,
                              initialDate:
                                  selectedDate.isBefore(
                                DateTime.now(),
                              )
                                      ? DateTime.now()
                                      : selectedDate,
                              firstDate:
                                  DateTime.now(),
                              lastDate:
                                  DateTime.now().add(
                                const Duration(
                                  days: 3650,
                                ),
                              ),
                              builder: (
                                context,
                                child,
                              ) {
                                return Theme(
                                  data: Theme.of(context)
                                      .copyWith(
                                    colorScheme:
                                        const ColorScheme.dark(
                                      primary:
                                          Color(0xFFFFD76A),
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
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

                        _ReminderOptionTile(
                          icon: Icons.access_time_rounded,
                          title: 'الوقت',
                          value: selectedTime.format(
                            context,
                          ),
                          onTap: () async {
                            final TimeOfDay? picked =
                                await showTimePicker(
                              context: context,
                              initialTime:
                                  selectedTime,
                              builder: (
                                context,
                                child,
                              ) {
                                return Theme(
                                  data: Theme.of(context)
                                      .copyWith(
                                    colorScheme:
                                        const ColorScheme.dark(
                                      primary:
                                          Color(0xFFFFD76A),
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
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

                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF0C0F17),
                            borderRadius:
                                BorderRadius.circular(16),
                          ),
                          child: SwitchListTile(
                            value: repeatDaily,
                            onChanged: (value) {
                              setModalState(() {
                                repeatDaily = value;
                              });
                            },
                            activeThumbColor:
                                const Color(0xFFFFD76A),
                            title: const Text(
                              'تكرار يومي',
                              textDirection:
                                  TextDirection.rtl,
                              textAlign:
                                  TextAlign.right,
                              style: TextStyle(
                                fontWeight:
                                    FontWeight.w800,
                              ),
                            ),
                            subtitle: const Text(
                              'سيظهر التذكير كل يوم في نفس الوقت',
                              textDirection:
                                  TextDirection.rtl,
                              textAlign:
                                  TextAlign.right,
                              style: TextStyle(
                                color:
                                    Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF0C0F17),
                            borderRadius:
                                BorderRadius.circular(16),
                          ),
                          child: SwitchListTile(
                            value: enabled,
                            onChanged: (value) {
                              setModalState(() {
                                enabled = value;
                              });
                            },
                            activeThumbColor:
                                const Color(0xFFFFD76A),
                            title: const Text(
                              'التذكير مفعّل',
                              textDirection:
                                  TextDirection.rtl,
                              textAlign:
                                  TextAlign.right,
                              style: TextStyle(
                                fontWeight:
                                    FontWeight.w800,
                              ),
                            ),
                            subtitle: const Text(
                              'يمكنك إيقافه وتشغيله في أي وقت',
                              textDirection:
                                  TextDirection.rtl,
                              textAlign:
                                  TextAlign.right,
                              style: TextStyle(
                                color:
                                    Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        SizedBox(
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              if (titleController.text
                                  .trim()
                                  .isEmpty) {
                                ScaffoldMessenger.of(
                                  context,
                                ).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'اكتب نص التذكير أولًا',
                                      textDirection:
                                          TextDirection.rtl,
                                    ),
                                  ),
                                );
                                return;
                              }

                              Navigator.pop(
                                context,
                                true,
                              );
                            },
                            icon: Icon(
                              editing
                                  ? Icons.save_rounded
                                  : Icons.add_alarm_rounded,
                            ),
                            label: Text(
                              editing
                                  ? 'حفظ التعديل'
                                  : 'حفظ التذكير',
                              style: const TextStyle(
                                fontWeight:
                                    FontWeight.w900,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  const Color(0xFFFFD76A),
                              foregroundColor:
                                  Colors.black,
                              shape:
                                  RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(16),
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

    if (result != true) {
      titleController.dispose();
      return;
    }

    final String title =
        titleController.text.trim();

    titleController.dispose();

    try {
      if (editing) {
        await reminderService.updateReminder(
          existing.copyWith(
            title: title,
            category: category,
            dateTime: DateTime(
              selectedDate.year,
              selectedDate.month,
              selectedDate.day,
              selectedTime.hour,
              selectedTime.minute,
            ),
            repeatDaily: repeatDaily,
            enabled: enabled,
          ),
        );

        _showMessage('تم تعديل التذكير');
      } else {
        await reminderService.addReminder(
          title: title,
          category: category,
          dateTime: DateTime(
            selectedDate.year,
            selectedDate.month,
            selectedDate.day,
            selectedTime.hour,
            selectedTime.minute,
          ),
          repeatDaily: repeatDaily,
          enabled: enabled,
        );

        _showMessage('تم حفظ التذكير');
      }
    } catch (_) {
      _showMessage(
        'حدث خطأ أثناء حفظ التذكير',
      );
    }
  }

  Future<void> _deleteReminder(
    ReminderItem reminder,
  ) async {
    final bool? confirmed =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor:
              const Color(0xFF171A24),
          title: const Text(
            'حذف التذكير؟',
            textDirection:
                TextDirection.rtl,
            textAlign: TextAlign.right,
          ),
          content: Text(
            reminder.title,
            textDirection:
                TextDirection.rtl,
            textAlign: TextAlign.right,
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                context,
                false,
              ),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                context,
                true,
              ),
              child: const Text(
                'حذف',
                style: TextStyle(
                  color: Colors.redAccent,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await reminderService.deleteReminder(
        reminder.id,
      );

      _showMessage('تم حذف التذكير');
    } catch (_) {
      _showMessage(
        'تعذر حذف التذكير',
      );
    }
  }

  Future<void> _toggleReminder(
    ReminderItem reminder,
  ) async {
    try {
      await reminderService.toggle(
        reminder.id,
      );
    } catch (_) {
      _showMessage(
        'تعذر تغيير حالة التذكير',
      );
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            textDirection:
                TextDirection.rtl,
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    if (loadingProfile) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFFFD76A),
        ),
      );
    }

    final displayName =
        profileService.displayName;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        14,
        8,
        14,
        125,
      ),
      children: [
        AppHeader(
          onAudioTap: widget.onAudio,
        ),

        const SizedBox(height: 10),

        const Text(
          'حسابي',
          textDirection:
              TextDirection.rtl,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w900,
          ),
        ),

        const SizedBox(height: 12),

        // ======================================================
        // PROFILE CARD
        // ======================================================

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(23),
            gradient: const LinearGradient(
              colors: [
                Color(0xFF20243A),
                Color(0xFF10131C),
              ],
            ),
            border: Border.all(
              color: Color(0x44FFD76A),
            ),
          ),
          child: Column(
            children: [
              GestureDetector(
                onTap: choosePhoto,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 98,
                      height: 98,
                      decoration:
                          BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              const Color(
                            0xFFFFD76A,
                          ),
                          width: 2,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color:
                                Color(0x44FFD76A),
                            blurRadius: 18,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: photo == null
                            ? const Icon(
                                Icons
                                    .person_rounded,
                                color:
                                    Color(
                                  0xFFFFD76A,
                                ),
                                size: 46,
                              )
                            : Image.memory(
                                photo!,
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),

                    if (savingPhoto)
                      Container(
                        width: 98,
                        height: 98,
                        decoration:
                            BoxDecoration(
                          shape:
                              BoxShape.circle,
                          color: Colors.black
                              .withOpacity(
                            0.55,
                          ),
                        ),
                        child:
                            const CircularProgressIndicator(
                          strokeWidth: 3,
                          color:
                              Color(
                            0xFFFFD76A,
                          ),
                        ),
                      ),

                    if (profileService
                        .hasReel)
                      Positioned(
                        right: 1,
                        bottom: 4,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration:
                              BoxDecoration(
                            shape:
                                BoxShape.circle,
                            gradient:
                                const LinearGradient(
                              colors: [
                                Color(
                                  0xFFFFD54F,
                                ),
                                Color(
                                  0xFFB45CFF,
                                ),
                              ],
                            ),
                            border:
                                Border.all(
                              color:
                                  const Color(
                                0xFF10131C,
                              ),
                              width: 3,
                            ),
                          ),
                          child:
                              const Icon(
                            Icons
                                .play_arrow_rounded,
                            color:
                                Colors.black,
                            size: 17,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              Text(
                displayName,
                textDirection:
                    TextDirection.rtl,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),

              const SizedBox(height: 10),

              TextField(
                controller:
                    nameController,
                textDirection:
                    TextDirection.rtl,
                textAlign:
                    TextAlign.right,
                decoration:
                    InputDecoration(
                  hintText:
                      'اكتب اسمك',
                  prefixIcon:
                      const Icon(
                    Icons
                        .badge_outlined,
                  ),
                  suffixIcon:
                      savingName
                          ? const Padding(
                              padding:
                                  EdgeInsets.all(
                                13,
                              ),
                              child:
                                  SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth:
                                      2.5,
                                  color:
                                      Color(
                                    0xFFFFD76A,
                                  ),
                                ),
                              ),
                            )
                          : IconButton(
                              onPressed:
                                  saveName,
                              icon:
                                  const Icon(
                                Icons
                                    .check_rounded,
                              ),
                            ),
                  filled: true,
                  fillColor:
                      const Color(
                    0xFF0D1018,
                  ),
                  border:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius
                            .circular(
                      15,
                    ),
                    borderSide:
                        BorderSide.none,
                  ),
                ),
                onSubmitted:
                    (_) => saveName(),
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child:
                        OutlinedButton.icon(
                      onPressed:
                          savingPhoto
                              ? null
                              : choosePhoto,
                      icon: const Icon(
                        Icons.photo,
                      ),
                      label:
                          const Text(
                        'الصورة',
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 8,
                  ),
                  Expanded(
                    child:
                        OutlinedButton.icon(
                      onPressed:
                          savingReel
                              ? null
                              : chooseReel,
                      icon: savingReel
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.movie,
                            ),
                      label:
                          const Text(
                        'ريلز',
                      ),
                    ),
                  ),
                ],
              ),

              if (reelName != null) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        const Color(
                      0xFF0D1018,
                    ),
                    borderRadius:
                        BorderRadius
                            .circular(
                      12,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons
                            .play_circle_outline,
                        color:
                            Color(
                          0xFFFFD76A,
                        ),
                        size: 20,
                      ),
                      const SizedBox(
                        width: 7,
                      ),
                      Expanded(
                        child: Text(
                          reelName!,
                          textDirection:
                              TextDirection
                                  .rtl,
                          maxLines: 1,
                          overflow:
                              TextOverflow
                                  .ellipsis,
                          style:
                              const TextStyle(
                            color:
                                Colors.white60,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 14),

        // ======================================================
        // REMINDERS
        // ======================================================

        const Text(
          'التذكيرات',
          textDirection:
              TextDirection.rtl,
          textAlign:
              TextAlign.right,
          style: TextStyle(
            fontSize: 21,
            fontWeight:
                FontWeight.w900,
          ),
        ),

        const SizedBox(height: 5),

        const Text(
          'حدد عباداتك وهواياتك ومهامك الشخصية وخلي صاحبي يفكرك في وقتها.',
          textDirection:
              TextDirection.rtl,
          textAlign:
              TextAlign.right,
          style: TextStyle(
            color: Colors.white54,
            fontSize: 11,
          ),
        ),

        const SizedBox(height: 10),

        _ReminderCategoryCard(
          icon:
              Icons.mosque_rounded,
          title: 'عبادات',
          subtitle:
              'تذكيرات للعبادات والأذكار والمهام الدينية.',
          color:
              const Color(0xFF26A69A),
          onAdd: () =>
              _openAddReminder('عبادات'),
        ),

        _ReminderCategoryCard(
          icon:
              Icons.sports_soccer_rounded,
          title: 'هوايات',
          subtitle:
              'تذكيرات للرياضة والهوايات والأشياء التي تحبها.',
          color:
              const Color(0xFF2196F3),
          onAdd: () =>
              _openAddReminder('هوايات'),
        ),

        _ReminderCategoryCard(
          icon:
              Icons.person_rounded,
          title: 'شخصي',
          subtitle:
              'تذكيرات شخصية للمهام والمواعيد والأهداف.',
          color:
              const Color(0xFFB45CFF),
          onAdd: () =>
              _openAddReminder('شخصي'),
        ),

        const SizedBox(height: 8),

        if (loadingReminders)
          const Padding(
            padding:
                EdgeInsets.all(18),
            child:
                Center(
              child:
                  CircularProgressIndicator(
                color:
                    Color(0xFFFFD76A),
              ),
            ),
          )
        else if (reminderService
            .items
            .isNotEmpty)
          _buildSavedReminders()
        else
          Container(
            padding:
                const EdgeInsets.all(18),
            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xFF131620,
              ),
              borderRadius:
                  BorderRadius.circular(
                18,
              ),
              border:
                  Border.all(
                color:
                    Colors.white10,
              ),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons
                      .notifications_none_rounded,
                  size: 34,
                  color:
                      Color(0xFFFFD76A),
                ),
                SizedBox(
                  height: 8,
                ),
                Text(
                  'لا توجد تذكيرات حتى الآن',
                  textDirection:
                      TextDirection.rtl,
                  textAlign:
                      TextAlign.center,
                  style:
                      TextStyle(
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                SizedBox(
                  height: 4,
                ),
                Text(
                  'اضغط + بجوار أي قسم لإضافة أول تذكير.',
                  textDirection:
                      TextDirection.rtl,
                  textAlign:
                      TextAlign.center,
                  style:
                      TextStyle(
                    color:
                        Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 10),

        // ======================================================
        // SHARE / SETTINGS
        // ======================================================

        _ProfileButton(
          icon:
              Icons.share_rounded,
          title:
              'مشاركة التطبيق',
          subtitle:
              'شارك صاحبي مع أصحابك برابط التحميل عبر التطبيقات المتاحة.',
          onTap:
              shareApp,
        ),

        _ProfileButton(
          icon:
              Icons.settings_rounded,
          title:
              'الإعدادات',
          subtitle:
              'إعدادات التطبيق والذكاء الاصطناعي.',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const SettingsScreen(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSavedReminders() {
    final List<ReminderItem> items =
        reminderService.items;

    return Column(
      children: [
        Row(
          textDirection:
              TextDirection.rtl,
          children: [
            const Expanded(
              child: Text(
                'تذكيراتك المحفوظة',
                textDirection:
                    TextDirection.rtl,
                textAlign:
                    TextAlign.right,
                style:
                    TextStyle(
                  fontWeight:
                      FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                await reminderService
                    .clearAll();

                _showMessage(
                  'تم حذف جميع التذكيرات',
                );
              },
              child: const Text(
                'حذف الكل',
                style: TextStyle(
                  color:
                      Colors.redAccent,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 4),

        ...items.map(
          (ReminderItem reminder) =>
              _SavedReminderTile(
            reminder: reminder,
            onToggle: () =>
                _toggleReminder(
              reminder,
            ),
            onEdit: () =>
                _openEditReminder(
              reminder,
            ),
            onDelete: () =>
                _deleteReminder(
              reminder,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// REMINDER CATEGORY CARD
// ============================================================

class _ReminderCategoryCard
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onAdd;

  const _ReminderCategoryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onAdd,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 8,
      ),
      padding:
          const EdgeInsets.all(11),
      decoration:
          BoxDecoration(
        color:
            const Color(0xFF131620),
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        border:
            Border.all(
          color:
              color.withOpacity(
            0.28,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onAdd,
            tooltip: 'إضافة تذكير',
            style: IconButton.styleFrom(
              backgroundColor:
                  color.withOpacity(
                0.12,
              ),
            ),
            icon: Icon(
              Icons.add_alarm_rounded,
              color: color,
              size: 22,
            ),
          ),

          const Spacer(),

          Expanded(
            flex: 7,
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.end,
              children: [
                Text(
                  title,
                  textDirection:
                      TextDirection.rtl,
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                const SizedBox(
                  height: 2,
                ),
                Text(
                  subtitle,
                  textDirection:
                      TextDirection.rtl,
                  textAlign:
                      TextAlign.right,
                  style:
                      const TextStyle(
                    color:
                        Colors.white54,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            width: 10,
          ),

          Container(
            width: 43,
            height: 43,
            decoration:
                BoxDecoration(
              shape:
                  BoxShape.circle,
              color:
                  color.withOpacity(
                0.16,
              ),
              border:
                  Border.all(
                color:
                    color.withOpacity(
                  0.4,
                ),
              ),
            ),
            child: Icon(
              icon,
              color: color,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SAVED REMINDER
// ============================================================

class _SavedReminderTile
    extends StatelessWidget {
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

  Color get _categoryColor {
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
  Widget build(
    BuildContext context,
  ) {
    final Color color =
        _categoryColor;

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 8,
      ),
      decoration:
          BoxDecoration(
        color:
            const Color(0xFF131620),
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        border:
            Border.all(
          color:
              color.withOpacity(
            reminder.enabled
                ? 0.30
                : 0.12,
          ),
        ),
      ),
      child: Padding(
        padding:
            const EdgeInsets.fromLTRB(
          8,
          8,
          12,
          8,
        ),
        child: Row(
          children: [
            Switch(
              value:
                  reminder.enabled,
              onChanged:
                  (_) => onToggle(),
              activeThumbColor:
                  const Color(
                0xFFFFD76A,
              ),
            ),

            IconButton(
              onPressed:
                  onDelete,
              tooltip:
                  'حذف',
              icon:
                  const Icon(
                Icons
                    .delete_outline_rounded,
                color:
                    Colors.redAccent,
                size: 21,
              ),
            ),

            IconButton(
              onPressed:
                  onEdit,
              tooltip:
                  'تعديل',
              icon:
                  const Icon(
                Icons
                    .edit_rounded,
                color:
                    Colors.white70,
                size: 20,
              ),
            ),

            const Spacer(),

            Expanded(
              flex: 7,
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.end,
                children: [
                  Text(
                    reminder.title,
                    maxLines: 2,
                    overflow:
                        TextOverflow.ellipsis,
                    textDirection:
                        TextDirection.rtl,
                    textAlign:
                        TextAlign.right,
                    style:
                        TextStyle(
                      fontWeight:
                          FontWeight.w900,
                      color:
                          reminder.enabled
                              ? Colors.white
                              : Colors.white38,
                    ),
                  ),

                  const SizedBox(
                    height: 5,
                  ),

                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.end,
                    children: [
                      if (reminder
                          .repeatDaily)
                        const Padding(
                          padding:
                              EdgeInsets.only(
                            left: 7,
                          ),
                          child:
                              Icon(
                            Icons
                                .repeat_rounded,
                            size: 14,
                            color:
                                Color(
                              0xFFFFD76A,
                            ),
                          ),
                        ),

                      Text(
                        '${_formatReminderDate(reminder.dateTime)}  •  ${_formatReminderTime(context, reminder.dateTime)}',
                        textDirection:
                            TextDirection.rtl,
                        style:
                            const TextStyle(
                          color:
                              Colors.white54,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 3,
                  ),

                  Text(
                    reminder.category,
                    textDirection:
                        TextDirection.rtl,
                    style:
                        TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              width: 10,
            ),

            Container(
              width: 40,
              height: 40,
              decoration:
                  BoxDecoration(
                shape:
                    BoxShape.circle,
                color:
                    color.withOpacity(
                  0.12,
                ),
              ),
              child:
                  Icon(
                reminder
                        .repeatDaily
                    ? Icons
                        .notifications_active_rounded
                    : Icons
                        .notifications_none_rounded,
                color:
                    reminder.enabled
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

  static String _formatReminderDate(
    DateTime date,
  ) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}';
  }

  static String _formatReminderTime(
    BuildContext context,
    DateTime date,
  ) {
    return TimeOfDay.fromDateTime(
      date,
    ).format(context);
  }
}

// ============================================================
// REMINDER OPTION TILE
// ============================================================

class _ReminderOptionTile
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  const _ReminderOptionTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Material(
      color:
          const Color(0xFF0C0F17),
      borderRadius:
          BorderRadius.circular(
        16,
      ),
      child: InkWell(
        borderRadius:
            BorderRadius.circular(
          16,
        ),
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.all(
            14,
          ),
          child: Row(
            children: [
              const Icon(
                Icons
                    .chevron_left_rounded,
                color:
                    Colors.white38,
              ),

              const Spacer(),

              Column(
                crossAxisAlignment:
                    CrossAxisAlignment.end,
                children: [
                  Text(
                    title,
                    textDirection:
                        TextDirection.rtl,
                    style:
                        const TextStyle(
                      color:
                          Colors.white54,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(
                    height: 3,
                  ),
                  Text(
                    value,
                    textDirection:
                        TextDirection.rtl,
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                ],
              ),

              const SizedBox(
                width: 12,
              ),

              Container(
                width: 40,
                height: 40,
                decoration:
                    BoxDecoration(
                  shape:
                      BoxShape.circle,
                  color:
                      const Color(
                    0xFFFFD76A,
                  ).withOpacity(
                    0.12,
                  ),
                ),
                child:
                    Icon(
                  icon,
                  color:
                      const Color(
                    0xFFFFD76A,
                  ),
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

// ============================================================
// PROFILE BUTTON
// ============================================================

class _ProfileButton
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ProfileButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 9,
      ),
      decoration:
          BoxDecoration(
        color:
            const Color(0xFF131620),
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        border:
            Border.all(
          color:
              Colors.white10,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading:
            Container(
          width: 44,
          height: 44,
          decoration:
              const BoxDecoration(
            shape:
                BoxShape.circle,
            gradient:
                LinearGradient(
              colors: [
                Color(
                  0xFFFFD54F,
                ),
                Color(
                  0xFFB45CFF,
                ),
              ],
            ),
          ),
          child: Icon(
            icon,
            color:
                Colors.black,
          ),
        ),
        title: Text(
          title,
          textDirection:
              TextDirection.rtl,
          style:
              const TextStyle(
            fontWeight:
                FontWeight.w900,
          ),
        ),
        subtitle: Text(
          subtitle,
          textDirection:
              TextDirection.rtl,
          style:
              const TextStyle(
            color:
                Colors.white54,
            fontSize: 11,
          ),
        ),
        trailing:
            const Icon(
          Icons
              .chevron_left_rounded,
        ),
      ),
    );
  }
}
