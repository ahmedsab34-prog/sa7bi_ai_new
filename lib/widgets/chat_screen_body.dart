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

  Widget _buildUtilityRail(BuildContext context) {
    return SizedBox(
      width: 42,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(height: 8),

          _UtilityIconButton(
            icon: Icons.bolt_rounded,
            color: const Color(0xFFFFD76A),
            tooltip: 'رصيد Credits',
            onTap: () {
              _showCreditsPanel(
                context,
                showReward: false,
              );
            },
          ),

          const SizedBox(height: 8),

          _UtilityIconButton(
            icon: Icons.play_circle_fill_rounded,
            color: const Color(0xFF70E5C7),
            tooltip: 'إعلان المكافأة',
            onTap: () {
              _showCreditsPanel(
                context,
                showReward: true,
              );
            },
          ),
        ],
      ),
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

                Expanded(
                  child: Row(
                    // نستخدم LTR في هذا الصف فقط حتى تكون
                    // أيقونات الرصيد على يسار منطقة المحادثة.
                    textDirection: TextDirection.ltr,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildUtilityRail(context),

                      const SizedBox(width: 3),

                      Expanded(
                        child: messages.isEmpty
                            ? ChatEmptyState(
                                theme: theme,
                                title: aiName,
                                inlineHeading:
                                    chatController.isKhalasana
                                        ? 'خلصانة'
                                        : null,
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
                                isLoading:
                                    chatController.isLoading,
                                controller: scrollController,
                              ),
                      ),
                    ],
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

class _UtilityIconButton extends StatelessWidget {
  const _UtilityIconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color.withValues(alpha: 0.28),
              ),
            ),
            child: Icon(
              icon,
              color: color,
              size: 19,
            ),
          ),
        ),
      ),
    );
  }
}
