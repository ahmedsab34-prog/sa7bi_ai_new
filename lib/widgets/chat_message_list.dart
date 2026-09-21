import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../services/chat_theme_service.dart';
import 'chat_message_bubble.dart';

/// قائمة رسائل المحادثة.
///
/// مسؤوليتها عرض الرسائل فقط.
/// الإرسال والحفظ والذكاء الاصطناعي تظل خارج هذا الملف.
class ChatMessageList extends StatelessWidget {
  final List<ChatMessage> messages;
  final ChatThemeData theme;

  /// اسم المستخدم المحفوظ في البروفايل.
  final String userName;

  /// صورة المستخدم المحفوظة.
  final dynamic userPhoto;

  /// اسم الذكاء الاصطناعي.
  final String aiName;

  /// هل يوجد رد قيد المعالجة؟
  final bool isLoading;

  /// ScrollController الخاص بالشاشة.
  final ScrollController? controller;

  const ChatMessageList({
    super.key,
    required this.messages,
    required this.theme,
    this.userName = 'صاحبي',
    this.userPhoto,
    this.aiName = 'خلصانة AI',
    this.isLoading = false,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final itemCount =
        messages.length + (isLoading ? 1 : 0);

    if (itemCount == 0) {
      return const SizedBox.shrink();
    }

    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.only(
        top: 8,
        bottom: 10,
      ),
      keyboardDismissBehavior:
          ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index >= messages.length) {
          return ChatMessageBubble(
            text: '',
            isUser: false,
            theme: theme,
            userName: userName,
            userPhoto: _photoBytes(),
            aiName: aiName,
            isLoading: true,
          );
        }

        final message = messages[index];

        return ChatMessageBubble(
          text: message.text,
          isUser: message.isUser,
          theme: theme,
          userName: userName,
          userPhoto: _photoBytes(),
          imageBytes: message.image,
          aiName: aiName,
        );
      },
    );
  }

  dynamic _photoBytes() {
    return userPhoto;
  }
}
