import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/profile_service.dart';

/// صورة المستخدم داخل المحادثة.
///
/// الأولوية:
/// 1. صورة البروفايل المحفوظة.
/// 2. صورة افتراضية إذا لم توجد صورة.
///
/// هذا الـWidget مستقل تمامًا عن:
/// - شعار صاحبي AI.
/// - أيقونة الذكاء الاصطناعي.
/// - تصميم Khalasana.
///
/// كما أنه يستمع إلى ProfileService حتى تتحدث الصورة والاسم
/// فورًا بعد تعديلهما من صفحة الحساب.
class ChatUserAvatar extends StatefulWidget {
  final double size;

  /// إظهار اسم المستخدم أسفل الصورة.
  final bool showName;

  /// اسم اختياري يفرضه المكان المستخدم فيه الـWidget.
  ///
  /// إذا لم يتم تمريره، يستخدم الاسم المحفوظ في ProfileService.
  final String? name;

  const ChatUserAvatar({
    super.key,
    this.size = 42,
    this.showName = false,
    this.name,
  });

  @override
  State<ChatUserAvatar> createState() =>
      _ChatUserAvatarState();
}

class _ChatUserAvatarState
    extends State<ChatUserAvatar> {
  final ProfileService _profile =
      ProfileService.instance;

  Uint8List? _photoBytes;

  String _displayName =
      ProfileService.defaultProfileName;

  @override
  void initState() {
    super.initState();

    _profile.changes.addListener(
      _onProfileChanged,
    );

    _loadProfile();
  }

  @override
  void dispose() {
    _profile.changes.removeListener(
      _onProfileChanged,
    );

    super.dispose();
  }

  void _onProfileChanged() {
    if (!mounted) {
      return;
    }

    _readCurrentProfile();
  }

  Future<void> _loadProfile() async {
    try {
      await _profile.initialize();
    } catch (_) {
      // في حالة فشل SharedPreferences نستخدم
      // الصورة والاسم الافتراضيين.
    }

    if (!mounted) {
      return;
    }

    _readCurrentProfile();
  }

  void _readCurrentProfile() {
    final name =
        _profile.displayName.trim();

    setState(() {
      _photoBytes =
          _profile.photoBytes;

      _displayName =
          name.isEmpty
              ? ProfileService.defaultProfileName
              : name;
    });
  }

  @override
  Widget build(BuildContext context) {
    final avatar = _buildAvatar();

    if (!widget.showName) {
      return avatar;
    }

    final customName =
        widget.name?.trim();

    final name =
        customName != null &&
                customName.isNotEmpty
            ? customName
            : _displayName;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        avatar,
        const SizedBox(height: 4),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textDirection:
              TextDirection.rtl,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar() {
    final diameter = widget.size;

    final bytes = _photoBytes;

    if (bytes != null &&
        bytes.isNotEmpty) {
      return Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(
                alpha: 0.12,
              ),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: ClipOval(
          child: Image.memory(
            bytes,
            width: diameter,
            height: diameter,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (
              context,
              error,
              stackTrace,
            ) {
              return _fallbackAvatar();
            },
          ),
        ),
      );
    }

    return _fallbackAvatar();
  }

  Widget _fallbackAvatar() {
    final diameter = widget.size;

    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF6C63FF),
            Color(0xFF36D1DC),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(
              0xFF6C63FF,
            ).withValues(
              alpha: 0.25,
            ),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Icon(
        Icons.person_rounded,
        size: diameter * 0.52,
        color: Colors.white,
      ),
    );
  }
}
