import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import 'home_screen.dart';
import 'monetization_config.dart';
import 'services/profile_service.dart';
import 'settings_screen.dart';

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
  final ImagePicker picker = ImagePicker();

  final TextEditingController nameController =
      TextEditingController();

  final ProfileService profileService =
      ProfileService.instance;

  Uint8List? photo;
  String? reelName;

  bool loadingProfile = true;
  bool savingName = false;
  bool savingPhoto = false;
  bool savingReel = false;

  @override
  void initState() {
    super.initState();

    profileService.changes.addListener(
      _onProfileChanged,
    );

    _loadProfile();
  }

  @override
  void dispose() {
    profileService.changes.removeListener(
      _onProfileChanged,
    );

    nameController.dispose();

    super.dispose();
  }

  void _onProfileChanged() {
    if (!mounted) return;

    final newName =
        profileService.displayName;

    final newPhoto =
        profileService.photoBytes;

    final newReel =
        profileService.hasReel
            ? profileService.reelName
            : null;

    if (nameController.text != newName &&
        newName !=
            ProfileService.defaultProfileName) {
      nameController.text = newName;
    }

    setState(() {
      photo = newPhoto;
      reelName = newReel;
      loadingProfile = false;
    });
  }

  Future<void> _loadProfile() async {
    try {
      await profileService.initialize();

      if (!mounted) return;

      final savedName =
          profileService.displayName;

      final savedPhoto =
          profileService.photoBytes;

      final savedReel =
          profileService.hasReel
              ? profileService.reelName
              : null;

      setState(() {
        nameController.text =
            savedName ==
                    ProfileService.defaultProfileName
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

      final saved =
          await profileService.savePhotoBytes(
        bytes,
      );

      if (!mounted) return;

      setState(() {
        savingPhoto = false;
      });

      if (!saved) {
        _showMessage(
          'لم يتم حفظ الصورة',
        );
        return;
      }

      setState(() {
        photo = bytes;
      });

      _showMessage(
        'تم حفظ صورة الحساب',
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        savingPhoto = false;
      });

      _showMessage(
        'حدث خطأ أثناء اختيار الصورة',
      );
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

      final saved =
          await profileService.saveReelName(
        file.name,
      );

      if (!mounted) return;

      setState(() {
        savingReel = false;
      });

      if (!saved) {
        _showMessage(
          'لم يتم حفظ الريلز',
        );
        return;
      }

      setState(() {
        reelName = file.name;
      });

      _showMessage(
        'تم حفظ الريلز',
      );
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

    final name =
        nameController.text.trim();

    if (name.isEmpty) {
      _showMessage(
        'اكتب اسمك أولًا',
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      savingName = true;
    });

    final saved =
        await profileService.saveName(
      name,
    );

    if (!mounted) return;

    setState(() {
      savingName = false;
    });

    if (!saved) {
      _showMessage(
        'لم يتم حفظ الاسم',
      );
      return;
    }

    _showMessage(
      'تم حفظ الاسم',
    );
  }

  Future<void> shareApp() async {
    try {
      final url =
          MonetizationConfig.appDownloadUrl;

      await Share.share(
        'جرّب تطبيق صاحبي AI 🤖\n'
        'مساعدك الذكي في كل يوم.\n\n'
        'رابط التحميل:\n'
        '$url',
        subject: 'صاحبي AI',
      );
    } catch (_) {}
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
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w900,
          ),
        ),

        const SizedBox(height: 12),

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
                                Color(
                              0x44FFD76A,
                            ),
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
                          child: const Icon(
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
                                strokeWidth:
                                    2,
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
                  width:
                      double.infinity,
                  padding:
                      const EdgeInsets
                          .symmetric(
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
                            color: Colors
                                .white60,
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

        const SizedBox(height: 12),

        const _ReminderCard(
          icon:
              Icons.mosque_rounded,
          title: 'عبادات',
          subtitle:
              'تذكيرات للعبادات والأذكار والمهام الدينية.',
          color:
              Color(0xFF26A69A),
        ),

        const _ReminderCard(
          icon: Icons
              .sports_soccer_rounded,
          title: 'هوايات',
          subtitle:
              'تذكيرات للرياضة والهوايات والأشياء التي تحبها.',
          color:
              Color(0xFF2196F3),
        ),

        const _ReminderCard(
          icon:
              Icons.person_rounded,
          title: 'شخصي',
          subtitle:
              'تذكيرات شخصية للمهام والمواعيد والأهداف.',
          color:
              Color(0xFFB45CFF),
        ),

        const SizedBox(height: 4),

        _ProfileButton(
          icon:
              Icons.share_rounded,
          title:
              'مشاركة التطبيق',
          subtitle:
              'شارك صاحبي مع أصحابك برابط التحميل عبر التطبيقات المتاحة.',
          onTap: shareApp,
        ),

        _ProfileButton(
          icon:
              Icons.settings_rounded,
          title: 'الإعدادات',
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
}

// ============================================================
// REMINDER CARD
// ============================================================

class _ReminderCard
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _ReminderCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
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
        border: Border.all(
          color:
              color.withOpacity(
            0.28,
          ),
        ),
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

          Expanded(
            flex: 7,
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .end,
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
        border: Border.all(
          color:
              Colors.white10,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 44,
          height: 44,
          decoration:
              const BoxDecoration(
            shape:
                BoxShape.circle,
            gradient:
                LinearGradient(
              colors: [
                Color(0xFFFFD54F),
                Color(0xFFB45CFF),
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
