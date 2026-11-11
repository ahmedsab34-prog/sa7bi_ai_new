
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/profile_service.dart';
import '../services/social_reels_service.dart';
import '../shorts_feed_screen.dart';

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
  State<ProfileHeader> createState() =>
      _ProfileHeaderState();
}

class _ProfileHeaderState extends State<ProfileHeader> {
  final ImagePicker _picker = ImagePicker();

  final ProfileService _profileService =
      ProfileService.instance;

  final SocialReelsService _reelsService =
      SocialReelsService.instance;

  late final TextEditingController _nameController;

  bool _savingName = false;
  bool _savingPhoto = false;
  bool _savingReel = false;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(
      text: widget.displayName ==
              ProfileService.defaultProfileName
          ? ''
          : widget.displayName,
    );
  }

  @override
  void didUpdateWidget(
    covariant ProfileHeader oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (_savingName) return;

    final newName = widget.displayName;

    if (newName == ProfileService.defaultProfileName) {
      if (_nameController.text.isNotEmpty) {
        _nameController.clear();
      }
      return;
    }

    if (_nameController.text != newName) {
      _nameController.text = newName;
      _nameController.selection =
          TextSelection.collapsed(
        offset: _nameController.text.length,
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _sendMessage(String message) {
    if (!mounted) return;
    widget.onMessage(message);
  }

  Future<void> _choosePhoto() async {
    if (_savingPhoto) return;

    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 900,
      );

      if (file == null) return;

      final bytes = await file.readAsBytes();

      if (bytes.isEmpty) {
        _sendMessage('الصورة فارغة.');
        return;
      }

      if (!mounted) return;

      setState(() {
        _savingPhoto = true;
      });

      final saved = await _profileService.savePhotoBytes(
        bytes,
      );

      if (!mounted) return;

      setState(() {
        _savingPhoto = false;
      });

      if (!saved) {
        _sendMessage('لم يتم حفظ صورة الحساب.');
        return;
      }

      widget.onChanged();
      _sendMessage('تم حفظ صورة الحساب ✅');
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _savingPhoto = false;
      });

      _sendMessage('حدث خطأ أثناء اختيار الصورة.');
    }
  }

  Future<void> _chooseReel() async {
    if (_savingReel) return;

    try {
      final file = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 2),
      );

      if (file == null) return;

      final length = await file.length();

      if (length <= 0) {
        _sendMessage('الفيديو فارغ.');
        return;
      }

      if (length > SocialReelsService.maximumVideoBytes) {
        _sendMessage(
          'حجم الفيديو أكبر من 50 ميجابايت.',
        );
        return;
      }

      if (!mounted) return;

      setState(() {
        _savingReel = true;
      });

      // Upload is performed once.
      // A timeout is not retried automatically to avoid duplicates.
      await _reelsService.uploadReel(
        file: file,
      );

      if (!mounted) return;

      // This name is only profile display metadata.
      // The actual video has already been uploaded to R2.
      final savedName = await _profileService.saveReelName(
        file.name,
      );

      if (!mounted) return;

      setState(() {
        _savingReel = false;
      });

      widget.onChanged();

      if (savedName) {
        _sendMessage(
          'تم رفع الفيديو ونشره في ريلز المجتمع بنجاح ✅',
        );
      } else {
        _sendMessage(
          'تم نشر الفيديو بنجاح، لكن تعذر حفظ اسمه في الحساب.',
        );
      }
    } on SocialReelsException catch (error) {
      if (!mounted) return;

      setState(() {
        _savingReel = false;
      });

      _sendMessage(error.message);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _savingReel = false;
      });

      _sendMessage(
        'تعذر رفع الفيديو. افتح الريلز وحدّث القائمة قبل إعادة المحاولة.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _savingReel = false;
        });
      }
    }
  }

  Future<void> _saveName() async {
    if (_savingName) return;

    final name = _nameController.text.trim();

    if (name.isEmpty) {
      _sendMessage('اكتب اسمك أولًا.');
      return;
    }

    if (name.length > 40) {
      _sendMessage('الاسم يجب ألا يتجاوز 40 حرفًا.');
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _savingName = true;
    });

    try {
      final saved = await _profileService.saveName(name);

      if (!mounted) return;

      setState(() {
        _savingName = false;
      });

      if (!saved) {
        _sendMessage('لم يتم حفظ الاسم.');
        return;
      }

      widget.onChanged();
      _sendMessage('تم حفظ الاسم ✅');
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _savingName = false;
      });

      _sendMessage('حدث خطأ أثناء حفظ الاسم.');
    }
  }

  Future<void> _openReels() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const ShortsFeedScreen(),
      ),
    );
  }

  Widget _buildProfileImage(bool hasPhoto, bool hasReel) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: _choosePhoto,
          child: Container(
            width: 92,
            height: 92,
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
                      .withValues(alpha: 0.15),
                  blurRadius: 18,
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
                            size: 44,
                            color: Color(0xFFFFD76A),
                          );
                        },
                      )
                    : const Icon(
                        Icons.person_rounded,
                        size: 44,
                        color: Color(0xFFFFD76A),
                      ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -1,
          right: -1,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: const Color(0xFF181C28),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFFFD76A),
                width: 1.4,
              ),
            ),
            child: _savingPhoto
                ? const Padding(
                    padding: EdgeInsets.all(7),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFFFD76A),
                    ),
                  )
                : const Icon(
                    Icons.camera_alt_rounded,
                    size: 15,
                    color: Color(0xFFFFD76A),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildNameField() {
    return TextField(
      controller: _nameController,
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.right,
      maxLength: 40,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) {
        if (!_savingName) {
          _saveName();
        }
      },
      decoration: InputDecoration(
        labelText: 'اسمك',
        hintText: 'اكتب اسمك',
        prefixIcon: const Icon(
          Icons.person_outline_rounded,
          size: 20,
        ),
        filled: true,
        fillColor: const Color(0xFF0C0F17),
        counterText: '',
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0x44FFD76A),
          ),
        ),
      ),
    );
  }

  Widget _buildNameButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _savingName ? null : _saveName,
        icon: _savingName
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.black,
                ),
              )
            : const Icon(
                Icons.save_rounded,
                size: 18,
              ),
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
            vertical: 11,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoButton() {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: _savingPhoto ? null : _choosePhoto,
        icon: const Icon(
          Icons.photo_camera_rounded,
          size: 18,
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
            vertical: 10,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
      ),
    );
  }

  Widget _buildReelButton() {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: _savingReel ? null : _chooseReel,
        icon: _savingReel
            ? const SizedBox(
                width: 17,
                height: 17,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFFF4D8D),
                ),
              )
            : const Icon(
                Icons.video_library_rounded,
                size: 18,
              ),
        label: Text(
          _savingReel
              ? 'جاري الرفع'
              : 'إضافة Reel',
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
            vertical: 10,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
      ),
    );
  }

  Widget _buildReelStatus() {
    final name = widget.reelName?.trim() ?? '';

    if (name.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0F17),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF63E6FF),
            size: 18,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              'آخر فيديو رفعته: $name',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
              ),
            ),
          ),
          IconButton(
            onPressed: _openReels,
            tooltip: 'عرض الريلز',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(
              minWidth: 34,
              minHeight: 34,
            ),
            padding: EdgeInsets.zero,
            icon: const Icon(
              Icons.play_circle_fill_rounded,
              color: Color(0xFFFF4D8D),
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto =
        widget.photo != null && widget.photo!.isNotEmpty;

    final hasReel =
        widget.reelName != null &&
        widget.reelName!.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 7),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFF131620),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0x33FFD76A),
        ),
      ),
      child: Column(
        children: [
          _buildProfileImage(hasPhoto, hasReel),
          const SizedBox(height: 9),
          Text(
            widget.displayName,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          _buildNameField(),
          const SizedBox(height: 7),
          _buildNameButton(),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildPhotoButton(),
              const SizedBox(width: 7),
              _buildReelButton(),
            ],
          ),
          if (hasReel) ...[
            const SizedBox(height: 8),
            _buildReelStatus(),
          ],
        ],
      ),
    );
  }
}
