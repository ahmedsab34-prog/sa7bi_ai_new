import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/profile_service.dart';

/// أيقونة المستخدم داخل المحادثة.
///
/// الأولوية:
/// 1. صورة البروفايل المحفوظة.
/// 2. صورة افتراضية جميلة إذا لم توجد صورة.
///
/// هذا الـWidget مستقل عن شعار صاحبي AI وعن أيقونة الذكاء الاصطناعي.
class ChatUserAvatar extends StatefulWidget {
  final double size;
  final bool showName;
  final String? name;

  const ChatUserAvatar({
    super.key,
    this.size = 42,
    this.showName = false,
    this.name,
  });

  @override
  State<ChatUserAvatar> createState() => _ChatUserAvatarState();
}

class _ChatUserAvatarState extends State<ChatUserAvatar> {
  Uint8List? _photoBytes;
  String _displayName = 'صاحبي';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = ProfileService.instance;

    await profile.initialize();

    if (!mounted) {
      return;
    }

    setState(() {
      _photoBytes = profile.photoBytes;
      _displayName = profile.displayName.trim().isEmpty
          ? 'صاحبي'
          : profile.displayName.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    final avatar = _buildAvatar();

    if (!widget.showName) {
      return avatar;
    }

    final name = widget.name?.trim().isNotEmpty == true
        ? widget.name!.trim()
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
          textDirection: TextDirection.rtl,
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

    if (_photoBytes != null && _photoBytes!.isNotEmpty) {
      return Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.12),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: ClipOval(
          child: Image.memory(
            _photoBytes!,
            width: diameter,
            height: diameter,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
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
            color: const Color(0xFF6C63FF).withValues(alpha: 0.25),
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
