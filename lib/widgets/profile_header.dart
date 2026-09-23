import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/profile_service.dart';

class ProfileHeader extends StatefulWidget {
  final String displayName;
  final Uint8List? photo;
  final String? reelName;
  final VoidCallback onChanged;
  final void Function(String message) onMessage;

  const ProfileHeader({
    super.key,
    required this.displayName,
    required this.photo,
    required this.reelName,
    required this.onChanged,
    required this.onMessage,
  });

  @override
  State<ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<ProfileHeader> {
  final ImagePicker _picker = ImagePicker();
  final ProfileService _profileService = ProfileService.instance;

  late final TextEditingController _nameController;

  bool _savingName = false;
  bool _savingPhoto = false;
  bool _savingReel = false;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(
      text: widget.displayName == ProfileService.defaultProfileName
          ? ''
          : widget.displayName,
    );
  }

  @override
  void didUpdateWidget(covariant ProfileHeader oldWidget) {
    super.didUpdateWidget(oldWidget);

    final newName = widget.displayName;

    if (!_savingName &&
        newName != ProfileService.defaultProfileName &&
        _nameController.text != newName) {
      _nameController.text = newName;
    }

    if (newName == ProfileService.defaultProfileName &&
        _nameController.text.isEmpty) {
      return;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _choosePhoto() async {
    if (_savingPhoto) return;

    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 900,
      );

      if (file == null) return;

      final Uint8List bytes = await file.readAsBytes();

      if (bytes.isEmpty) {
        widget.onMessage('الصورة فارغة');
        return;
      }

      setState(() {
        _savingPhoto = true;
      });

      final saved = await _profileService.savePhotoBytes(bytes);

      if (!mounted) return;

      setState(() {
        _savingPhoto = false;
      });

      if (!saved) {
        widget.onMessage('لم يتم حفظ الصورة');
        return;
      }

      widget.onChanged();
      widget.onMessage('تم حفظ صورة الحساب');
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _savingPhoto = false;
      });

      widget.onMessage('حدث خطأ أثناء اختيار الصورة');
    }
  }

  Future<void> _chooseReel() async {
    if (_savingReel) return;

    try {
      final XFile? file = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 2),
      );

      if (file == null) return;

      setState(() {
        _savingReel = true;
      });

      final saved = await _profileService.saveReelName(file.name);

      if (!mounted) return;

      setState(() {
        _savingReel = false;
      });

      if (!saved) {
        widget.onMessage('لم يتم حفظ الريلز');
        return;
      }

      widget.onChanged();
      widget.onMessage('تم حفظ الريلز');
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _savingReel = false;
      });

      widget.onMessage('حدث خطأ أثناء اختيار الريلز');
    }
  }

  Future<void> _clearReel() async {
    if (_savingReel) return;

    setState(() {
      _savingReel = true;
    });

    final saved = await _profileService.clearReel();

    if (!mounted) return;

    setState(() {
      _savingReel = false;
    });

    if (!saved) {
      widget.onMessage('لم يتم حذف الريلز');
      return;
    }

    widget.onChanged();
    widget.onMessage('تم حذف الريلز');
  }

  Future<void> _saveName() async {
    if (_savingName) return;

    final name = _nameController.text.trim();

    if (name.isEmpty) {
      widget.onMessage('اكتب اسمك أولًا');
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _savingName = true;
    });

    final saved = await _profileService.saveName(name);

    if (!mounted) return;

    setState(() {
      _savingName = false;
    });

    if (!saved) {
      widget.onMessage('لم يتم حفظ الاسم');
      return;
    }

    widget.onChanged();
    widget.onMessage('تم حفظ الاسم');
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = widget.photo != null && widget.photo!.isNotEmpty;
    final hasReel =
        widget.reelName != null && widget.reelName!.trim().isNotEmpty;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF131620),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0x33FFD76A),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD76A).withOpacity(0.06),
                blurRadius: 22,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  GestureDetector(
                    onTap: _choosePhoto,
                    child: Container(
                      width: 112,
                      height: 112,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: hasReel
                            ? const SweepGradient(
                                colors: [
                                  Color(0xFFFFD76A),
                                  Color(0xFFFF4D8D),
                                  Color(0xFFB45CFF),
                                  Color(0xFF63E6FF),
                                  Color(0xFFFFD76A),
                                ],
                              )
                            : const LinearGradient(
                                colors: [
                                  Color(0xFFFFD76A),
                                  Color(0xFF8B6A25),
                                ],
                              ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFD76A)
                                .withOpacity(0.16),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Container(
                          color: const Color(0xFF0C0F17),
                          child: hasPhoto
                              ? Image.memory(
                                  widget.photo!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) {
                                    return const Icon(
                                      Icons.person_rounded,
                                      size: 52,
                                      color: Color(0xFFFFD76A),
                                    );
                                  },
                                )
                              : const Icon(
                                  Icons.person_rounded,
                                  size: 52,
                                  color: Color(0xFFFFD76A),
                                ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFF181C28),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFFFD76A),
                          width: 1.5,
                        ),
                      ),
                      child: _savingPhoto
                          ? const Padding(
                              padding: EdgeInsets.all(8),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFFFD76A),
                              ),
                            )
                          : const Icon(
                              Icons.camera_alt_rounded,
                              size: 17,
                              color: Color(0xFFFFD76A),
                            ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              const Text(
                'حسابك الشخصي',
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  color: Color(0xFFFFD76A),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 5),

              Text(
                widget.displayName,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),

              const SizedBox(height: 18),

              TextField(
                controller: _nameController,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                maxLength: 40,
                decoration: InputDecoration(
                  labelText: 'اسمك',
                  hintText: 'اكتب اسمك',
                  prefixIcon: const Icon(
                    Icons.person_outline_rounded,
                  ),
                  filled: true,
                  fillColor: const Color(0xFF0C0F17),
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 9),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _savingName ? null : _saveName,
                  icon: _savingName
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Icon(Icons.save_rounded),
                  label: const Text(
                    'حفظ الاسم',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD76A),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      vertical: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _savingPhoto ? null : _choosePhoto,
                      icon: const Icon(
                        Icons.photo_camera_rounded,
                      ),
                      label: const Text(
                        'الصورة',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF63E6FF),
                        side: const BorderSide(
                          color: Color(0x4463E6FF),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _savingReel ? null : _chooseReel,
                      icon: const Icon(
                        Icons.video_library_rounded,
                      ),
                      label: Text(
                        hasReel ? 'تغيير Reel' : 'إضافة Reel',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFF4D8D),
                        side: const BorderSide(
                          color: Color(0x44FF4D8D),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              if (hasReel) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C0F17),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _savingReel ? null : _clearReel,
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.reelName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textDirection: TextDirection.rtl,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.play_circle_fill_rounded,
                        color: Color(0xFFFF4D8D),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
