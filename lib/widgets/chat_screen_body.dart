
import 'package:flutter/material.dart';

import '../services/chat_controller.dart';
import '../services/profile_service.dart';
import 'chat_composer.dart';
import 'chat_dynamic_background.dart';
import 'chat_empty_state.dart';
import 'chat_message_list.dart';
import 'chat_status_header.dart';
import 'credits_status.dart';
import 'rewarded_ad_button.dart';

/// جسم شاشة المحادثة.
/// منطق الذكاء والوسائط والحفظ موجود في ChatScreen والخدمات.
class ChatScreenBody extends StatelessWidget {
  final ChatController chatController;
  final ProfileService profileService;

  final TextEditingController textController;
  final FocusNode focusNode;
  final ScrollController scrollController;

  final String title;
  final String? topic;

  final bool enabled;
  final bool isListening;
  final bool isGeneratingImage;

  final VoidCallback onSend;

  final VoidCallback? onCamera;
  final VoidCallback? onGallery;
  final VoidCallback? onVideo;
  final VoidCallback? onVoice;
  final VoidCallback? onText;
  final VoidCallback? onSpeechToText;
  final VoidCallback? onImageGeneration;

  final VoidCallback onClear;

  const ChatScreenBody({
    super.key,
    required this.chatController,
    required this.profileService,
    required this.textController,
    required this.focusNode,
    required this.scrollController,
    required this.title,
    this.topic,
    this.enabled = true,
    this.isListening = false,
    this.isGeneratingImage = false,
    required this.onSend,
    this.onCamera,
    this.onGallery,
    this.onVideo,
    this.onVoice,
    this.onText,
    this.onSpeechToText,
    this.onImageGeneration,
    required this.onClear,
  });

  Future<void> _showCreditsPanel(
    BuildContext context, {
    required bool showReward,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF101725),
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(22),
        ),
      ),
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                14,
                4,
                14,
                20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'رصيد صاحبي AI',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (!showReward)
                    const CreditsStatus(
                      compact: false,
                      showRewardButton: false,
                    ),
                  if (showReward)
                    const RewardedAdButton(
                      compact: false,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        chatController,
        profileService.changes,
      ]),
      builder: (context, _) {
        final theme = chatController.theme;
        final messages = chatController.messages;

        final userName = profileService.displayName;
        final userPhoto = profileService.photoBytes;

        // الاسم الظاهر داخل المحادثة موحد.
        // serviceKey و serviceTitle يظلان محفوظين داخليًا للذكاء الاصطناعي.
        const aiName = 'صاحبي AI';

        final safeTopic =
            topic?.trim().isNotEmpty == true
                ? topic!.trim()
                : null;

        return ChatDynamicBackground(
          theme: theme,
          animated: true,
          child: SafeArea(
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: ChatStatusHeader(
                        theme: theme,
                        title: title,
                        topic: safeTopic,
                        isLoading: chatController.isLoading,
                        canClear: messages.isNotEmpty &&
                            !chatController.isLoading,
                        onClear: chatController.isLoading
                            ? null
                            : onClear,
                        showTitle: false,
                      ),
                    ),
                    PopupMenuButton<int>(
                      tooltip: 'الرصيد والمكافآت',
                      icon: const Icon(
                        Icons.more_horiz_rounded,
                        color: Color(0xFF9FCBFF),
                        size: 23,
                      ),
                      color: const Color(0xFF17243B),
                      onSelected: (value) {
                        _showCreditsPanel(
                          context,
                          showReward: value == 2,
                        );
                      },
                      itemBuilder: (menuContext) => const [
                        PopupMenuItem<int>(
                          value: 1,
                          child: Row(
                            children: [
                              Icon(
                                Icons.bolt_rounded,
                                color: Color(0xFFFFD76A),
                              ),
                              SizedBox(width: 9),
                              Text(
                                'رصيد النقاط',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem<int>(
                          value: 2,
                          child: Row(
                            children: [
                              Icon(
                                Icons.play_circle_fill_rounded,
                                color: Color(0xFF70E5C7),
                              ),
                              SizedBox(width: 9),
                              Text(
                                'إعلان المكافأة',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 3),
                  ],
                ),

                // مساحة المحادثة أصبحت كاملة، من غير عمود أدوات جانبي.
                Expanded(
                  child: messages.isEmpty
                      ? ChatEmptyState(
                          theme: theme,
                          title: aiName,
                          inlineTagline:
                              chatController.isKhalasana
                                  ? 'أنا معاك..'
                                  : null,
                          showTitle: false,
                          subtitle:
                              chatController.isKhalasana
                                  ? 'قول لي محتاج إيه، '
                                      'ونبدأ مع بعض من غير ما تحتاج تختار مجال.'
                                  : 'اتكلم معايا براحتك، '
                                      'وأنا هساعدك على قد ما أقدر.',
                        )
                      : ChatMessageList(
                          messages: messages,
                          theme: theme,
                          userName: userName,
                          userPhoto: userPhoto,
                          aiName: aiName,
                          isLoading: chatController.isLoading,
                          controller: scrollController,
                        ),
                ),

                ChatComposer(
                  controller: textController,
                  focusNode: focusNode,
                  isLoading: !enabled ||
                      chatController.isLoading,
                  isListening: isListening,
                  isGeneratingImage: isGeneratingImage,
                  onSend: onSend,
                  onCamera: !enabled ? null : onCamera,
                  onGallery: !enabled ? null : onGallery,
                  onVideo: !enabled ? null : onVideo,
                  onVoice: !enabled ? null : onVoice,
                  onText: !enabled ? null : onText,
                  onSpeechToText:
                      !enabled ? null : onSpeechToText,
                  onImageGeneration:
                      !enabled ? null : onImageGeneration,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
