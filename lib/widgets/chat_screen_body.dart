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
///
/// مسؤول عن تركيب الواجهة فقط.
/// منطق الذكاء الاصطناعي والوسائط والحفظ موجود في ChatScreen
/// والخدمات المرتبطة به.
class ChatScreenBody extends StatelessWidget {
  final ChatController chatController;
  final ProfileService profileService;

  final TextEditingController textController;
  final FocusNode focusNode;
  final ScrollController scrollController;

  final String title;
  final String? topic;

  /// هل الشاشة تسمح بالتفاعل؟
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

        final aiName = chatController.isKhalasana
            ? 'خلصانة AI'
            : 'صاحبي AI';

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
                // رأس الحالة يحتفظ بالأيقونة والحالة ومسح المحادثة،
                // لكن اسم الشاشة يظهر مرة واحدة فقط في AppBar.
                ChatStatusHeader(
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

                // حالة الرصيد وزر المكافأة.
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    10,
                    3,
                    10,
                    5,
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: CreditsStatus(
                          compact: true,
                          showRewardButton: false,
                        ),
                      ),
                      const SizedBox(width: 8),
                      RewardedAdButton(
                        compact: true,
                        onRewarded: () {
                          // يعاد بناء حالة الرصيد عبر الخدمة
                          // والمكونات المستمعة لها.
                        },
                      ),
                    ],
                  ),
                ),

                // الرسائل أو شاشة البداية من دون تكرار الاسم.
                Expanded(
                  child: messages.isEmpty
                      ? ChatEmptyState(
                          theme: theme,
                          title: aiName,
                          showTitle: false,
                          subtitle: chatController.isKhalasana
                              ? 'اتكلم مع خلصانة براحتك، '
                                  'والمحادثة تتغير حسب الموضوع.'
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

                // أدوات الكتابة والوسائط.
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
