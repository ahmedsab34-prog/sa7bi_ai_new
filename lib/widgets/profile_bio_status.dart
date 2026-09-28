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
  State<ProfileBioStatus> createState() =>
      _ProfileBioStatusState();
}

class _ProfileBioStatusState
    extends State<ProfileBioStatus> {
  final ProfileService _profileService =
      ProfileService.instance;

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
  void didUpdateWidget(
    covariant ProfileBioStatus oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (!_savingBio &&
        _bioController.text != widget.bio) {
      _bioController.text = widget.bio;
      _bioController.selection =
          TextSelection.collapsed(
        offset: _bioController.text.length,
      );
    }

    if (!_savingStatus &&
        _statusController.text != widget.status) {
      _statusController.text = widget.status;
      _statusController.selection =
          TextSelection.collapsed(
        offset: _statusController.text.length,
      );
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

    try {
      final saved =
          await _profileService.saveBio(
        _bioController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        _savingBio = false;
      });

      if (!saved) {
        _showMessage('لم يتم حفظ النبذة.');
        return;
      }

      widget.onProfileChanged();
      _showMessage('تم حفظ النبذة ✅');
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _savingBio = false;
      });

      _showMessage(
        'حدث خطأ أثناء حفظ النبذة.',
      );
    }
  }

  Future<void> _saveStatus() async {
    if (_savingStatus) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _savingStatus = true;
    });

    try {
      final saved =
          await _profileService.saveStatus(
        _statusController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        _savingStatus = false;
      });

      if (!saved) {
        _showMessage('لم يتم حفظ الحالة.');
        return;
      }

      widget.onProfileChanged();
      _showMessage('تم حفظ الحالة ✅');
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _savingStatus = false;
      });

      _showMessage(
        'حدث خطأ أثناء حفظ الحالة.',
      );
    }
  }

  void _showMessage(String message) {
    if (!mounted ||
        message.trim().isEmpty) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            textDirection:
                TextDirection.rtl,
          ),
          behavior:
              SnackBarBehavior.floating,
          duration:
              const Duration(seconds: 2),
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
          color:
              const Color(0xFFFFD76A),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            title,
            textDirection:
                TextDirection.rtl,
            textAlign:
                TextAlign.right,
            style: const TextStyle(
              fontSize: 14,
              fontWeight:
                  FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration({
    required String hintText,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor:
          const Color(0xFF0C0F17),
      counterText: '',
      isDense: true,
      prefixIcon: Icon(
        icon,
        size: 20,
      ),
      contentPadding:
          const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 10,
      ),
      border: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(13),
        borderSide:
            BorderSide.none,
      ),
      enabledBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(13),
        borderSide:
            const BorderSide(
          color: Color(0x101FFFFFF),
        ),
      ),
      focusedBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(13),
        borderSide:
            const BorderSide(
          color: Color(0x4463E6FF),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:
          const EdgeInsets.fromLTRB(
        8,
        0,
        8,
        7,
      ),
      padding:
          const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            const Color(0xFF131620),
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color:
              const Color(0x22FFD76A),
        ),
      ),
      child: Column(
        children: [
          _sectionTitle(
            icon:
                Icons.edit_note_rounded,
            title:
                'نبذة وحالتك',
          ),

          const SizedBox(height: 9),

          TextField(
            controller:
                _bioController,
            textDirection:
                TextDirection.rtl,
            textAlign:
                TextAlign.right,
            maxLength: 160,
            maxLines: 2,
            keyboardType:
                TextInputType.multiline,
            textInputAction:
                TextInputAction.newline,
            decoration:
                _fieldDecoration(
              hintText:
                  'اكتب نبذة قصيرة عنك',
              icon:
                  Icons.notes_rounded,
            ),
          ),

          const SizedBox(height: 6),

          SizedBox(
            width: double.infinity,
            child:
                OutlinedButton.icon(
              onPressed:
                  _savingBio
                      ? null
                      : _saveBio,
              icon: _savingBio
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.save_rounded,
                      size: 17,
                    ),
              label:
                  const Text(
                'حفظ النبذة',
                style: TextStyle(
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
              style:
                  OutlinedButton.styleFrom(
                foregroundColor:
                    const Color(
                  0xFF63E6FF,
                ),
                side:
                    const BorderSide(
                  color:
                      Color(0x4463E6FF),
                ),
                padding:
                    const EdgeInsets
                        .symmetric(
                  vertical: 9,
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 9),

          TextField(
            controller:
                _statusController,
            textDirection:
                TextDirection.rtl,
            textAlign:
                TextAlign.right,
            maxLength: 100,
            maxLines: 1,
            textInputAction:
                TextInputAction.done,
            decoration:
                _fieldDecoration(
              hintText:
                  'اكتب حالتك الآن',
              icon:
                  Icons.auto_awesome_rounded,
            ),
            onSubmitted: (_) {
              if (!_savingStatus) {
                _saveStatus();
              }
            },
          ),

          const SizedBox(height: 6),

          SizedBox(
            width: double.infinity,
            child:
                OutlinedButton.icon(
              onPressed:
                  _savingStatus
                      ? null
                      : _saveStatus,
              icon: _savingStatus
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.check_rounded,
                      size: 17,
                    ),
              label:
                  const Text(
                'حفظ الحالة',
                style: TextStyle(
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
              style:
                  OutlinedButton.styleFrom(
                foregroundColor:
                    const Color(
                  0xFFFFD76A,
                ),
                side:
                    const BorderSide(
                  color:
                      Color(0x44FFD76A),
                ),
                padding:
                    const EdgeInsets
                        .symmetric(
                  vertical: 9,
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
