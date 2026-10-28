
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/chat_theme_service.dart';
import 'chat_ai_avatar.dart';

/// فقاعة رسائل صغيرة بتصميم مدمج.
/// لا تتعامل مع الشبكة ولا تغيّر منطق إرسال الرسائل.
class ChatMessageBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  final ChatThemeData theme;
  final String userName;
  final Uint8List? userPhoto;
  final Uint8List? imageBytes;
  final String aiName;
  final bool isLoading;
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
    this.avatarSize = 32,
  });

  @override
  Widget build(BuildContext context) {
    final safeText = text.trim();
    final effectiveAvatarSize = avatarSize.clamp(26.0, 36.0);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 3,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            ChatAiAvatar(
              theme: theme,
              size: effectiveAvatarSize,
              animated: !isLoading,
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: _buildBubble(safeText),
          ),
          if (isUser) ...[
            const SizedBox(width: 6),
            _UserAvatar(
              size: effectiveAvatarSize,
              photoBytes: userPhoto,
              name: userName,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBubble(String safeText) {
    final bubbleColor = isUser ? theme.userBubble : theme.aiBubble;

    final borderColor = isUser
        ? theme.primary.withValues(alpha: 0.30)
        : theme.secondary.withValues(alpha: 0.20);

    return Container(
      constraints: const BoxConstraints(
        maxWidth: 340,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: bubbleColor.withValues(alpha: 0.96),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(17),
          topRight: const Radius.circular(17),
          bottomLeft: Radius.circular(isUser ? 17 : 5),
          bottomRight: Radius.circular(isUser ? 5 : 17),
        ),
        border: Border.all(
          color: borderColor,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.glow.withValues(alpha: 0.055),
            blurRadius: 9,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          if (imageBytes != null) ...[
            const SizedBox(height: 6),
            _buildImage(),
          ],
          if (safeText.isNotEmpty) ...[
            if (imageBytes != null) const SizedBox(height: 6),
            _buildText(safeText),
          ],
          if (isLoading) ...[
            const SizedBox(height: 7),
            _buildLoadingIndicator(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final name = isUser
        ? (userName.trim().isEmpty ? 'صاحبي' : userName.trim())
        : (aiName.trim().isEmpty ? 'خلصانة AI' : aiName.trim());

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isUser
              ? Icons.person_outline_rounded
              : Icons.auto_awesome_rounded,
          size: 12,
          color: isUser ? theme.primary : theme.secondary,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: 9.5,
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
          fontSize: 13,
          height: 1.45,
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
      borderRadius: BorderRadius.circular(11),
      child: Image.memory(
        bytes,
        width: double.infinity,
        height: 180,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 100,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              Icons.broken_image_outlined,
              color: Colors.white.withValues(alpha: 0.6),
              size: 30,
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
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 1.7,
            valueColor: AlwaysStoppedAnimation<Color>(theme.secondary),
          ),
        ),
        const SizedBox(width: 7),
        Text(
          'جاري التفكير...',
          textDirection: TextDirection.rtl,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.62),
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

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
          ),
        ),
        child: ClipOval(
          child: Image.memory(
            bytes,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) => _fallback(),
          ),
        ),
      );
    }

    return _fallback();
  }

  Widget _fallback() {
    final trimmedName = name.trim();
    final initial = trimmedName.isEmpty
        ? 'ص'
        : trimmedName.characters.first;

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
