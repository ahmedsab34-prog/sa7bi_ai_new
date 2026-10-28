
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../services/chat_theme_service.dart';
import 'chat_message_bubble.dart';

/// قائمة رسائل مدمجة، مع الحفاظ على الصور وحالة انتظار الرد.
class ChatMessageList extends StatelessWidget {
  final List<ChatMessage> messages;
  final ChatThemeData theme;
  final String userName;
  final Uint8List? userPhoto;
  final String aiName;
  final bool isLoading;
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
    final itemCount = messages.length + (isLoading ? 1 : 0);

    if (itemCount == 0) {
      return const SizedBox.shrink();
    }

    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.only(
        top: 3,
        bottom: 5,
      ),
      keyboardDismissBehavior:
          ScrollViewKeyboardDismissBehavior.onDrag,
      physics: const BouncingScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index >= messages.length) {
          return ChatMessageBubble(
            text: '',
            isUser: false,
            theme: theme,
            userName: userName,
            userPhoto: userPhoto,
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
          userPhoto: userPhoto,
          imageBytes: message.image,
          aiName: aiName,
        );
      },
    );
  }
}
