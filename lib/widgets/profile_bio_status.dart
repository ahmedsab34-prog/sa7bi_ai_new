import 'package:flutter/material.dart';

import '../services/profile_service.dart';

class ProfileBioStatus extends StatefulWidget {
  final String bio;
  final String status;
  final VoidCallback onProfileChanged;

  const ProfileBioStatus({
    super.key,
    required this.bio,
    required this.status,
    required this.onProfileChanged,
  });

  @override
  State<ProfileBioStatus> createState() => _ProfileBioStatusState();
}

class _ProfileBioStatusState extends State<ProfileBioStatus> {
  final ProfileService _profileService = ProfileService.instance;

  late final TextEditingController _bioController;
  late final TextEditingController _statusController;

  bool _savingBio = false;
  bool _savingStatus = false;

  @override
  void initState() {
    super.initState();

    _bioController = TextEditingController(
      text: widget.bio,
    );

    _statusController = TextEditingController(
      text: widget.status,
    );
  }

  @override
  void didUpdateWidget(covariant ProfileBioStatus oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!_savingBio && _bioController.text != widget.bio) {
      _bioController.text = widget.bio;
    }

    if (!_savingStatus && _statusController.text != widget.status) {
      _statusController.text = widget.status;
    }
  }

  @override
  void dispose() {
    _bioController.dispose();
    _statusController.dispose();
    super.dispose();
  }

  Future<void> _saveBio() async {
    if (_savingBio) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _savingBio = true;
    });

    final saved = await _profileService.saveBio(
      _bioController.text.trim(),
    );

    if (!mounted) return;

    setState(() {
      _savingBio = false;
    });

    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'لم يتم حفظ النبذة',
            textDirection: TextDirection.rtl,
          ),
        ),
      );
      return;
    }

    widget.onProfileChanged();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'تم حفظ النبذة',
          textDirection: TextDirection.rtl,
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _saveStatus() async {
    if (_savingStatus) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _savingStatus = true;
    });

    final saved = await _profileService.saveStatus(
      _statusController.text.trim(),
    );

    if (!mounted) return;

    setState(() {
      _savingStatus = false;
    });

    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'لم يتم حفظ الحالة',
            textDirection: TextDirection.rtl,
          ),
        ),
      );
      return;
    }

    widget.onProfileChanged();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'تم حفظ الحالة',
          textDirection: TextDirection.rtl,
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _sectionTitle({
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 19,
          color: const Color(0xFFFFD76A),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            title,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 7),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF131620),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0x22FFD76A),
        ),
      ),
      child: Column(
        children: [
          _sectionTitle(
            icon: Icons.edit_note_rounded,
            title: 'نبذة وحالتك',
          ),

          const SizedBox(height: 9),

          TextField(
            controller: _bioController,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            maxLength: 160,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'اكتب نبذة قصيرة عنك',
              filled: true,
              fillColor: const Color(0xFF0C0F17),
              counterText: '',
              isDense: true,
              prefixIcon: const Icon(
                Icons.notes_rounded,
                size: 20,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 11,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 6),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _savingBio ? null : _saveBio,
              icon: _savingBio
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.save_rounded,
                      size: 17,
                    ),
              label: const Text(
                'حفظ النبذة',
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
                  vertical: 9,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 9),

          TextField(
            controller: _statusController,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            maxLength: 100,
            maxLines: 1,
            decoration: InputDecoration(
              hintText: 'اكتب حالتك الآن',
              filled: true,
              fillColor: const Color(0xFF0C0F17),
              counterText: '',
              isDense: true,
              prefixIcon: const Icon(
                Icons.auto_awesome_rounded,
                size: 20,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 11,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 6),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _savingStatus ? null : _saveStatus,
              icon: _savingStatus
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.check_rounded,
                      size: 17,
                    ),
              label: const Text(
                'حفظ الحالة',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFFD76A),
                side: const BorderSide(
                  color: Color(0x44FFD76A),
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 9,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
