import 'package:flutter/material.dart';

import '../services/profile_service.dart';

class ProfileBioStatus extends StatefulWidget {
  final String bio;
  final String status;
  final void Function(String message) onMessage;
  final VoidCallback onChanged;

  const ProfileBioStatus({
    super.key,
    required this.bio,
    required this.status,
    required this.onMessage,
    required this.onChanged,
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

    _bioController =
        TextEditingController(
      text: widget.bio,
    );

    _statusController =
        TextEditingController(
      text: widget.status,
    );
  }

  @override
  void didUpdateWidget(
    covariant ProfileBioStatus oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (!_savingBio &&
        widget.bio !=
            _bioController.text) {
      _bioController.text =
          widget.bio;
    }

    if (!_savingStatus &&
        widget.status !=
            _statusController.text) {
      _statusController.text =
          widget.status;
    }
  }

  @override
  void dispose() {
    _bioController.dispose();
    _statusController.dispose();
    super.dispose();
  }

  Future<void> _saveBio() async {
    if (_savingBio) {
      return;
    }

    setState(() {
      _savingBio = true;
    });

    final saved =
        await _profileService.saveBio(
      _bioController.text,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _savingBio = false;
    });

    if (!saved) {
      widget.onMessage(
        'لم يتم حفظ النبذة',
      );
      return;
    }

    widget.onChanged();

    widget.onMessage(
      'تم حفظ النبذة الشخصية',
    );
  }

  Future<void> _saveStatus() async {
    if (_savingStatus) {
      return;
    }

    setState(() {
      _savingStatus = true;
    });

    final saved =
        await _profileService.saveStatus(
      _statusController.text,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _savingStatus = false;
    });

    if (!saved) {
      widget.onMessage(
        'لم يتم حفظ الحالة',
      );
      return;
    }

    widget.onChanged();

    widget.onMessage(
      'تم حفظ الحالة',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            const Color(0xFF131620),
        borderRadius:
            BorderRadius.circular(21),
        border: Border.all(
          color:
              const Color(0x2263E6FF),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          Row(
            textDirection:
                TextDirection.rtl,
            children: const [
              Icon(
                Icons.edit_note_rounded,
                color:
                    Color(0xFF63E6FF),
                size: 22,
              ),
              SizedBox(width: 7),
              Text(
                'نبذة وحالة',
                textDirection:
                    TextDirection.rtl,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          TextField(
            controller:
                _bioController,
            textDirection:
                TextDirection.rtl,
            textAlign:
                TextAlign.right,
            maxLines: 3,
            maxLength: 160,
            decoration:
                InputDecoration(
              labelText:
                  'نبذة عنك',
              hintText:
                  'اكتب نبذة قصيرة عن نفسك...',
              prefixIcon:
                  const Icon(
                Icons.person_outline_rounded,
              ),
              filled: true,
              fillColor:
                  const Color(0xFF0C0F17),
              counterText: '',
              border:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(
                  15,
                ),
                borderSide:
                    BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 8),

          SizedBox(
            height: 44,
            child:
                ElevatedButton.icon(
              onPressed:
                  _savingBio
                      ? null
                      : _saveBio,
              icon: _savingBio
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                        color:
                            Colors.black,
                      ),
                    )
                  : const Icon(
                      Icons.save_rounded,
                    ),
              label: const Text(
                'حفظ النبذة',
                style: TextStyle(
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(
                  0xFF63E6FF,
                ),
                foregroundColor:
                    Colors.black,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 15),

          TextField(
            controller:
                _statusController,
            textDirection:
                TextDirection.rtl,
            textAlign:
                TextAlign.right,
            maxLines: 2,
            maxLength: 120,
            decoration:
                InputDecoration(
              labelText:
                  'الحالة',
              hintText:
                  'اكتب حالتك الحالية...',
              prefixIcon:
                  const Icon(
                Icons.bolt_rounded,
              ),
              filled: true,
              fillColor:
                  const Color(0xFF0C0F17),
              counterText: '',
              border:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(
                  15,
                ),
                borderSide:
                    BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 8),

          SizedBox(
            height: 44,
            child:
                ElevatedButton.icon(
              onPressed:
                  _savingStatus
                      ? null
                      : _saveStatus,
              icon: _savingStatus
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                        color:
                            Colors.black,
                      ),
                    )
                  : const Icon(
                      Icons.check_circle_rounded,
                    ),
              label: const Text(
                'حفظ الحالة',
                style: TextStyle(
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(
                  0xFFFFD76A,
                ),
                foregroundColor:
                    Colors.black,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),
              ),
            ),
          ),

          if (widget.bio.trim().isNotEmpty ||
              widget.status.trim().isNotEmpty) ...[
            const SizedBox(height: 14),

            Container(
              padding:
                  const EdgeInsets.all(13),
              decoration:
                  BoxDecoration(
                color:
                    const Color(0xFF0C0F17),
                borderRadius:
                    BorderRadius.circular(
                  15,
                ),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.end,
                children: [
                  if (widget.status
                      .trim()
                      .isNotEmpty)
                    Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      textDirection:
                          TextDirection.rtl,
                      children: [
                        const Icon(
                          Icons.circle,
                          color:
                              Color(0xFF63E6FF),
                          size: 9,
                        ),
                        const SizedBox(
                          width: 7,
                        ),
                        Expanded(
                          child: Text(
                            widget.status,
                            textDirection:
                                TextDirection.rtl,
                            textAlign:
                                TextAlign.right,
                            style:
                                const TextStyle(
                              color:
                                  Colors.white,
                              fontWeight:
                                  FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),

                  if (widget.bio
                      .trim()
                      .isNotEmpty &&
                      widget.status
                          .trim()
                          .isNotEmpty)
                    const SizedBox(
                      height: 9,
                    ),

                  if (widget.bio
                      .trim()
                      .isNotEmpty)
                    Text(
                      widget.bio,
                      textDirection:
                          TextDirection.rtl,
                      textAlign:
                          TextAlign.right,
                      style:
                          const TextStyle(
                        color:
                            Colors.white60,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
