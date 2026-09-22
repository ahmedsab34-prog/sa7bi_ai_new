import 'package:flutter/material.dart';

import '../services/chat_controller.dart';
import '../services/profile_service.dart';
import '../services/chat_theme_service.dart';
import 'chat_composer.dart';
import 'chat_dynamic_background.dart';
import 'chat_empty_state.dart';
import 'chat_message_list.dart';
import 'chat_status_header.dart';
import 'credits_status.dart';
import 'rewarded_ad_button.dart';

/// جسم شاشة المحادثة.
///
/// المسؤوليات:
/// - عرض حالة الخدمة.
/// - عرض المحادثة.
/// - عرض Credits.
/// - عرض أدوات الشات.
/// - الحفاظ على جميع callbacks القادمة من ChatScreen.
///
/// منطق الذكاء الاصطناعي والوسائط والصوت والإعلانات
/// يظل خارج هذا الملف.
class ChatScreenBody extends StatefulWidget {
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

  @override
  State<ChatScreenBody> createState() =>
      _ChatScreenBodyState();
}

class _ChatScreenBodyState
    extends State<ChatScreenBody> {
  /// نستخدم مفتاحًا لتحديث CreditsStatus بعد الحصول
  /// على مكافأة إعلان حقيقية.
  int _creditsRefreshKey = 0;

  ChatThemeData get theme =>
      widget.chatController.theme;

  void _refreshCredits() {
    if (!mounted) {
      return;
    }

    setState(() {
      _creditsRefreshKey++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChatDynamicBackground(
      theme: theme,
      child: SafeArea(
        child: Column(
          children: [
            // ====================================================
            // STATUS HEADER
            // ====================================================

            ChatStatusHeader(
              theme: theme,
              title: widget.title,
              topic: widget.topic,
              isLoading:
                  widget.chatController.isLoading,
              canClear:
                  widget.chatController.messages.isNotEmpty,
              onClear: widget.onClear,
            ),

            // ====================================================
            // CREDITS
            // ====================================================

            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                10,
                6,
                10,
                4,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: CreditsStatus(
                      key: ValueKey(
                        'credits_status_$_creditsRefreshKey',
                      ),
                      compact: true,
                      showRewardButton: false,
                    ),
                  ),

                  const SizedBox(width: 8),

                  RewardedAdButton(
                    compact: true,
                    onRewarded:
                        _refreshCredits,
                  ),
                ],
              ),
            ),

            // ====================================================
            // MESSAGES
            // ====================================================

            Expanded(
              child: widget.chatController.messages.isEmpty
                  ? ChatEmptyState(
                      theme: theme,
                      title: widget.title,
                      subtitle:
                          widget.chatController.isKhalasana
                              ? 'اتكلم مع خلصانة AI براحتك. الموضوع ممكن يتغير، والمظهر هيتفاعل مع كلامك.'
                              : 'اتكلم، اكتب، ابعت صورة أو استخدم الأدوات المتاحة.',
                      suggestions:
                          widget.suggestions,
                      onSuggestionTap:
                          widget.enabled
                              ? (value) {
                                  widget.textController.text =
                                      value;

                                  widget.textController
                                      .selection =
                                      TextSelection
                                          .fromPosition(
                                    TextPosition(
                                      offset: widget
                                          .textController
                                          .text
                                          .length,
                                    ),
                                  );

                                  widget.focusNode
                                      ?.requestFocus();
                                }
                              : null,
                    )
                  : ChatMessageList(
                      messages:
                          widget.chatController.messages,
                      theme: theme,
                      userName:
                          widget.profileService.displayName,
                      userPhoto:
                          widget.profileService.photoBytes,
                      aiName:
                          widget.chatController.isKhalasana
                              ? 'خلصانة AI'
                              : 'صاحبي AI',
                      isLoading:
                          widget.chatController.isLoading,
                      controller:
                          widget.scrollController,
                    ),
            ),

            // ====================================================
            // COMPOSER
            // ====================================================

            ChatComposer(
              controller:
                  widget.textController,
              focusNode:
                  widget.focusNode,
              enabled:
                  widget.enabled &&
                  !widget.chatController.isLoading,
              isListening:
                  widget.isListening,
              isGeneratingImage:
                  widget.isGeneratingImage,
              onSend:
                  widget.onSend,
              onCamera:
                  widget.onCamera,
              onVideo:
                  widget.onVideo,
              onVoice:
                  widget.onVoice,
              onText:
                  widget.onText,
              onSpeechToText:
                  widget.onSpeechToText,
              onImageGeneration:
                  widget.onImageGeneration,
            ),
          ],
        ),
      ),
    );
  }
}
