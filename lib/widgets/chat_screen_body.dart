import 'package:flutter/material.dart';

import '../services/chat_controller.dart';
import '../services/profile_service.dart';
import '../services/chat_theme_service.dart';
import 'chat_composer.dart';
import 'chat_dynamic_background.dart';
import 'chat_empty_state.dart';
import 'chat_message_list.dart';
import 'chat_status_header.dart';

/// جسم شاشة المحادثة.
///
/// يجمع مكونات الشات الجديدة في مكان واحد، بينما يظل
/// منطق الذكاء الاصطناعي والوسائط والصوت داخل الخدمات/الشاشة.
class ChatScreenBody extends StatelessWidget {
  final ChatController chatController;
  final ProfileService profileService;
  final TextEditingController textController;
  final FocusNode? focusNode;
  final ScrollController? scrollController;

  final String title;
  final String? topic;

  final VoidCallback? onSend;
  final VoidCallback? onCamera;
  final VoidCallback? onVideo;
  final VoidCallback? onVoice;
  final VoidCallback? onText;
  final VoidCallback? onSpeechToText;
  final VoidCallback? onImageGeneration;
  final VoidCallback? onClear;

  final bool enabled;
  final bool isListening;
  final bool isGeneratingImage;

  final List<String> suggestions;

  const ChatScreenBody({
    super.key,
    required this.chatController,
    required this.profileService,
    required this.textController,
    required this.title,
    this.focusNode,
    this.scrollController,
    this.topic,
    this.onSend,
    this.onCamera,
    this.onVideo,
    this.onVoice,
    this.onText,
    this.onSpeechToText,
    this.onImageGeneration,
    this.onClear,
    this.enabled = true,
    this.isListening = false,
    this.isGeneratingImage = false,
    this.suggestions = const <String>[],
  });

  ChatThemeData get theme => chatController.theme;

  @override
  Widget build(BuildContext context) {
    return ChatDynamicBackground(
      theme: theme,
      child: SafeArea(
        child: Column(
          children: [
            ChatStatusHeader(
              theme: theme,
              title: title,
              topic: topic,
              isLoading: chatController.isLoading,
              canClear: chatController.messages.isNotEmpty,
              onClear: onClear,
            ),

            Expanded(
              child: chatController.messages.isEmpty
                  ? ChatEmptyState(
                      theme: theme,
                      title: title,
                      subtitle: chatController.isKhalasana
                          ? 'اتكلم مع خلصانة AI براحتك. الموضوع ممكن يتغير، والمظهر هيتفاعل مع كلامك.'
                          : 'اتكلم، اكتب، ابعت صورة أو استخدم الأدوات المتاحة.',
                      suggestions: suggestions,
                      onSuggestionTap: enabled
                          ? (value) {
                              textController.text = value;

                              textController.selection =
                                  TextSelection.fromPosition(
                                TextPosition(
                                  offset:
                                      textController.text.length,
                                ),
                              );

                              focusNode?.requestFocus();
                            }
                          : null,
                    )
                  : ChatMessageList(
                      messages: chatController.messages,
                      theme: theme,
                      userName: profileService.displayName,
                      userPhoto: profileService.photoBytes,
                      aiName: chatController.isKhalasana
                          ? 'خلصانة AI'
                          : 'صاحبي AI',
                      isLoading: chatController.isLoading,
                      controller: scrollController,
                    ),
            ),

            ChatComposer(
              controller: textController,
              focusNode: focusNode,
              enabled:
                  enabled && !chatController.isLoading,
              isListening: isListening,
              isGeneratingImage: isGeneratingImage,
              onSend: onSend,
              onCamera: onCamera,
              onVideo: onVideo,
              onVoice: onVoice,
              onText: onText,
              onSpeechToText: onSpeechToText,
              onImageGeneration: onImageGeneration,
            ),
          ],
        ),
      ),
    );
  }
}
