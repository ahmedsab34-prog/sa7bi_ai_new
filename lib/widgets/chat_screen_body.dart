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
/// مسؤول عن تركيب واجهة المحادثة فقط.
/// منطق الذكاء الاصطناعي والوسائط والحفظ موجود
/// في ChatScreen والخدمات الخاصة به.
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
                // ==================================================
                // HEADER
                // ==================================================

                ChatStatusHeader(
                  theme: theme,
                  title: title,
                  topic: safeTopic,
                  isLoading: chatController.isLoading,
                  canClear:
                      messages.isNotEmpty &&
                      !chatController.isLoading,
                  onClear:
                      chatController.isLoading
                          ? null
                          : onClear,
                ),

                // ==================================================
                // CREDITS
                // ==================================================

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
                          // CreditsStatus يعيد قراءة الرصيد
                          // عند إعادة بناء الواجهة.
                        },
                      ),
                    ],
                  ),
                ),

                // ==================================================
                // MESSAGES
                // ==================================================

                Expanded(
                  child: messages.isEmpty
                      ? ChatEmptyState(
                          theme: theme,
                          title: aiName,
                          subtitle:
                              chatController.isKhalasana
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
                          isLoading:
                              chatController.isLoading,
                          controller: scrollController,
                        ),
                ),

                // ==================================================
                // CHAT COMPOSER
                // ==================================================

                ChatComposer(
                  controller: textController,
                  focusNode: focusNode,
                  isLoading:
                      !enabled ||
                      chatController.isLoading,
                  isListening: isListening,
                  isGeneratingImage: isGeneratingImage,

                  // إرسال النص
                  onSend: onSend,

                  // الكاميرا
                  onCamera:
                      !enabled
                          ? null
                          : onCamera,

                  // الصور والمعرض
                  onGallery:
                      !enabled
                          ? null
                          : onGallery,

                  // الفيديو
                  onVideo:
                      !enabled
                          ? null
                          : onVideo,

                  // قراءة آخر رد AI بالصوت
                  onVoice:
                      !enabled
                          ? null
                          : onVoice,

                  // فتح لوحة الكتابة
                  onText:
                      !enabled
                          ? null
                          : onText,

                  // تحويل الكلام إلى نص
                  onSpeechToText:
                      !enabled
                          ? null
                          : onSpeechToText,

                  // توليد صورة بالذكاء الاصطناعي
                  onImageGeneration:
                      !enabled
                          ? null
                          : onImageGeneration,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
