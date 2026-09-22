import 'package:flutter/material.dart';

import '../services/credits_service.dart';
import '../widgets/rewarded_ad_button.dart';
import '../widgets/credits_status.dart';
import 'chat_composer.dart';
import 'chat_dynamic_background.dart';
import 'chat_empty_state.dart';
import 'chat_message_list.dart';
import 'chat_status_header.dart';

class ChatScreenBody extends StatefulWidget {
  final String serviceTitle;
  final String serviceKey;

  final List<dynamic> messages;

  final bool isLoading;
  final bool isListening;
  final bool isGeneratingImage;

  final TextEditingController textController;
  final FocusNode focusNode;

  final VoidCallback onSend;
  final VoidCallback? onCamera;
  final VoidCallback? onGallery;
  final VoidCallback? onVideo;
  final VoidCallback? onVoice;
  final VoidCallback? onText;
  final VoidCallback? onSpeechToText;
  final VoidCallback? onImageGeneration;
  final VoidCallback onClear;

  final String? userName;
  final String? userImagePath;

  const ChatScreenBody({
    super.key,
    required this.serviceTitle,
    required this.serviceKey,
    required this.messages,
    required this.isLoading,
    required this.isListening,
    required this.isGeneratingImage,
    required this.textController,
    required this.focusNode,
    required this.onSend,
    this.onCamera,
    this.onGallery,
    this.onVideo,
    this.onVoice,
    this.onText,
    this.onSpeechToText,
    this.onImageGeneration,
    required this.onClear,
    this.userName,
    this.userImagePath,
  });

  @override
  State<ChatScreenBody> createState() => _ChatScreenBodyState();
}

class _ChatScreenBodyState extends State<ChatScreenBody> {
  int _credits = 0;
  int _remainingRewardedAds = 0;

  @override
  void initState() {
    super.initState();
    _refreshCredits();
  }

  Future<void> _refreshCredits() async {
    try {
      final service = CreditsService.instance;

      await service.initialize();

      if (!mounted) return;

      setState(() {
        _credits = service.balance;
        _remainingRewardedAds = service.remainingRewardedAds;
      });
    } catch (_) {
      // لا نوقف شاشة الشات إذا حصل خطأ في نظام الرصيد.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ChatDynamicBackground(
        serviceKey: widget.serviceKey,
        child: SafeArea(
          child: Column(
            children: [
              ChatStatusHeader(
                title: widget.serviceTitle,
                isLoading: widget.isLoading,
                isListening: widget.isListening,
                isGeneratingImage: widget.isGeneratingImage,
                onClear: widget.onClear,
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: CreditsStatus(
                        compact: true,
                        showRewardButton: false,
                      ),
                    ),
                    const SizedBox(width: 8),
                    RewardedAdButton(
                      compact: true,
                      onRewarded: _refreshCredits,
                    ),
                  ],
                ),
              ),

              Expanded(
                child: widget.messages.isEmpty
                    ? const ChatEmptyState()
                    : ChatMessageList(
                        messages: widget.messages,
                        userName: widget.userName,
                        userImagePath: widget.userImagePath,
                      ),
              ),

              ChatComposer(
                controller: widget.textController,
                focusNode: widget.focusNode,
                isLoading: widget.isLoading,
                isListening: widget.isListening,
                isGeneratingImage: widget.isGeneratingImage,
                onSend: widget.onSend,
                onCamera: widget.onCamera,
                onGallery: widget.onGallery,
                onVideo: widget.onVideo,
                onVoice: widget.onVoice,
                onText: widget.onText,
                onSpeechToText: widget.onSpeechToText,
                onImageGeneration: widget.onImageGeneration,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
