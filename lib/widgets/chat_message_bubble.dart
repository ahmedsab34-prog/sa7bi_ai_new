import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/chat_theme_service.dart';
import 'chat_ai_avatar.dart';

/// فقاعة رسالة واحدة داخل المحادثة.
///
/// مسؤول عن عرض:
/// - رسائل المستخدم.
/// - رسائل الذكاء الاصطناعي.
/// - الصور المرفقة.
/// - حالة التحميل.
/// - هوية المستخدم والـAI.
///
/// لا يحتوي على أي منطق لإرسال الرسائل أو الاتصال بالـBackend.
class ChatMessageBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  final ChatThemeData theme;

  /// اسم المستخدم المحفوظ في البروفايل.
  final String userName;

  /// صورة المستخدم المحفوظة.
  final Uint8List? userPhoto;

  /// صورة مرفقة بالرسالة إن وجدت.
  final Uint8List? imageBytes;

  /// اسم الذكاء الاصطناعي الظاهر للمستخدم.
  final String aiName;

  /// هل الرسالة قيد المعالجة؟
  final bool isLoading;

  /// حجم صورة الحساب / أيقونة الـAI.
  final double avatarSize;

  const ChatMessageBubble({
    super.key,
    required this.text,
    required this.isUser,
    required this.theme,
    this.userName = 'صاحبي',
    this.userPhoto,
    this.imageBytes,
    this.aiName = 'خلصانة AI',
    this.isLoading = false,
    this.avatarSize = 40,
  });

  @override
  Widget build(BuildContext context) {
    final safeText = text.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            ChatAiAvatar(
              theme: theme,
              size: avatarSize,
              animated: !isLoading,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: _buildBubble(
              safeText,
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            _UserAvatar(
              size: avatarSize,
              photoBytes: userPhoto,
              name: userName,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBubble(String safeText) {
    final bubbleColor =
        isUser ? theme.userBubble : theme.aiBubble;

    final borderColor = isUser
        ? theme.primary.withValues(alpha: 0.32)
        : theme.secondary.withValues(alpha: 0.22);

    return Container(
      constraints: const BoxConstraints(
        maxWidth: 340,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 11,
      ),
      decoration: BoxDecoration(
        color: bubbleColor.withValues(alpha: 0.94),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(
            isUser ? 20 : 5,
          ),
          bottomRight: Radius.circular(
            isUser ? 5 : 20,
          ),
        ),
        border: Border.all(
          color: borderColor,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.glow.withValues(alpha: 0.08),
            blurRadius: 14,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          if (imageBytes != null) ...[
            const SizedBox(height: 8),
            _buildImage(),
          ],
          if (safeText.isNotEmpty) ...[
            if (imageBytes != null)
              const SizedBox(height: 8),
            _buildText(safeText),
          ],
          if (isLoading) ...[
            const SizedBox(height: 8),
            _buildLoadingIndicator(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final name = isUser
        ? (userName.trim().isEmpty
            ? 'صاحبي'
            : userName.trim())
        : aiName.trim().isEmpty
            ? 'خلصانة AI'
            : aiName.trim();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isUser
              ? Icons.person_outline_rounded
              : Icons.auto_awesome_rounded,
          size: 13,
          color: isUser
              ? theme.primary
              : theme.secondary,
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildText(String value) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Text(
        value,
        textAlign: TextAlign.start,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          height: 1.55,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  Widget _buildImage() {
    final bytes = imageBytes;

    if (bytes == null || bytes.isEmpty) {
      return const SizedBox.shrink();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.memory(
        bytes,
        width: double.infinity,
        height: 210,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (
          context,
          error,
          stackTrace,
        ) {
          return Container(
            height: 120,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.broken_image_outlined,
              color: Colors.white.withValues(alpha: 0.6),
              size: 34,
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 15,
          height: 15,
          child: CircularProgressIndicator(
            strokeWidth: 1.8,
            valueColor: AlwaysStoppedAnimation<Color>(
              theme.secondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'جاري التفكير...',
          textDirection: TextDirection.rtl,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.62),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

/// صورة المستخدم داخل فقاعة الرسالة.
class _UserAvatar extends StatelessWidget {
  final double size;
  final Uint8List? photoBytes;
  final String name;

  const _UserAvatar({
    required this.size,
    required this.photoBytes,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    final bytes = photoBytes;

    if (bytes != null && bytes.isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.16),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 10,
            ),
          ],
        ),
        child: ClipOval(
          child: Image.memory(
            bytes,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (
              context,
              error,
              stackTrace,
            ) {
              return _fallback();
            },
          ),
        ),
      );
    }

    return _fallback();
  }

  Widget _fallback() {
    final initial = name.trim().isEmpty
        ? 'ص'
        : name.trim().characters.first;

    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF6C63FF),
            Color(0xFF36D1DC),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        textDirection: TextDirection.rtl,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.40,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
