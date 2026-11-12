
import 'package:flutter/material.dart';

enum _ComposerAction {
  camera,
  gallery,
  video,
  imageGeneration,
}

class _ComposerActionItem {
  const _ComposerActionItem({
    required this.action,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final _ComposerAction action;
  final IconData icon;
  final String title;
  final String subtitle;
}

class ChatComposer extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;

  final bool isLoading;
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

  const ChatComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isLoading,
    required this.isListening,
    required this.isGeneratingImage,
    required this.onSend,
    this.onCamera,
    this.onGallery,
    this.onVideo,
    this.onVoice,
    this.onText,
    this.onSpeechToText,
    this.onImageGeneration,
  });

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();

    widget.controller.addListener(_onTextChanged);
    _hasText = widget.controller.text.trim().isNotEmpty;
  }

  @override
  void didUpdateWidget(covariant ChatComposer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
      _hasText = widget.controller.text.trim().isNotEmpty;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final value = widget.controller.text.trim().isNotEmpty;

    if (!mounted || value == _hasText) return;

    setState(() {
      _hasText = value;
    });
  }

  void _send() {
    if (widget.isLoading || widget.isGeneratingImage) {
      return;
    }

    if (widget.controller.text.trim().isEmpty) {
      return;
    }

    widget.onSend();
  }

  Future<void> _openToolsMenu(BuildContext context) async {
    final disabled = widget.isLoading ||
        widget.isGeneratingImage ||
        widget.isListening;

    if (disabled) return;

    final items = <_ComposerActionItem>[
      if (widget.onCamera != null)
        const _ComposerActionItem(
          action: _ComposerAction.camera,
          icon: Icons.camera_alt_rounded,
          title: 'التقاط صورة بالكاميرا',
          subtitle: 'تصوير صورة جديدة لتحليلها',
        ),
      if (widget.onGallery != null)
        const _ComposerActionItem(
          action: _ComposerAction.gallery,
          icon: Icons.photo_library_rounded,
          title: 'اختيار صورة من المعرض',
          subtitle: 'إرسال صورة محفوظة على الجهاز',
        ),
      if (widget.onVideo != null)
        const _ComposerActionItem(
          action: _ComposerAction.video,
          icon: Icons.videocam_rounded,
          title: 'اختيار فيديو',
          subtitle: 'إرسال فيديو لتحليل محتواه',
        ),
      if (widget.onImageGeneration != null)
        const _ComposerActionItem(
          action: _ComposerAction.imageGeneration,
          icon: Icons.auto_awesome_rounded,
          title: 'إنشاء صورة',
          subtitle: 'اكتب وصف الصورة التي تريد إنشاءها',
        ),
    ];

    if (items.isEmpty) return;

    final selectedAction =
        await showModalBottomSheet<_ComposerAction>(
      context: context,
      backgroundColor: const Color(0xFF111827),
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
                12,
                4,
                12,
                18,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'أدوات إضافية',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  for (final item in items)
                    ListTile(
                      onTap: () {
                        Navigator.of(sheetContext).pop(
                          item.action,
                        );
                      },
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 8),
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0x2267B7FF),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          item.icon,
                          color: const Color(0xFF83C8FF),
                          size: 21,
                        ),
                      ),
                      title: Text(
                        item.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: Text(
                        item.subtitle,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 10,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.chevron_left_rounded,
                        color: Colors.white38,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (!mounted ||
        selectedAction == null ||
        widget.isLoading ||
        widget.isGeneratingImage ||
        widget.isListening) {
      return;
    }

    switch (selectedAction) {
      case _ComposerAction.camera:
        widget.onCamera?.call();
        break;
      case _ComposerAction.gallery:
        widget.onGallery?.call();
        break;
      case _ComposerAction.video:
        widget.onVideo?.call();
        break;
      case _ComposerAction.imageGeneration:
        widget.onImageGeneration?.call();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.isLoading ||
        widget.isGeneratingImage;

    final hasTools = widget.onCamera != null ||
        widget.onGallery != null ||
        widget.onVideo != null ||
        widget.onImageGeneration != null;

    return SafeArea(
      top: false,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            6,
            5,
            6,
            5,
          ),
          decoration: const BoxDecoration(
            color: Color(0xCC080D18),
            border: Border(
              top: BorderSide(
                color: Color(0x334B6C9D),
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // خانة الكتابة تأخذ أكبر مساحة متاحة.
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  constraints: const BoxConstraints(
                    minHeight: 42,
                    maxHeight: 100,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [
                        Color(0xFF17243B),
                        Color(0xFF0E1728),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: _hasText
                          ? const Color(0xAA67B7FF)
                          : const Color(0x554D6588),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 5,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    enabled: !disabled,
                    minLines: 1,
                    maxLines: 3,
                    textInputAction: TextInputAction.newline,
                    keyboardType: TextInputType.multiline,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    onTap: widget.onText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      height: 1.25,
                    ),
                    cursorColor: const Color(0xFF67B7FF),
                    decoration: InputDecoration(
                      hintText: widget.isListening
                          ? 'جاري الاستماع...'
                          : 'اكتب رسالتك لصاحبي...',
                      hintTextDirection: TextDirection.rtl,
                      hintStyle: const TextStyle(
                        color: Color(0xFF8291A9),
                        fontSize: 11,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: (_) {
                      if (!disabled && _hasText) {
                        _send();
                      }
                    },
                  ),
                ),
              ),

              const SizedBox(width: 3),

              if (hasTools)
                _ComposerIconButton(
                  icon: Icons.add_rounded,
                  tooltip: 'الصور والفيديو وإنشاء الصور',
                  enabled: !disabled && !widget.isListening,
                  color: const Color(0xFF83C8FF),
                  onTap: () => _openToolsMenu(context),
                ),

              if (widget.onSpeechToText != null)
                _ComposerIconButton(
                  icon: widget.isListening
                      ? Icons.stop_circle_rounded
                      : Icons.mic_rounded,
                  tooltip: widget.isListening
                      ? 'إيقاف تحويل الكلام'
                      : 'تحدث واكتب',
                  enabled: !disabled,
                  active: widget.isListening,
                  color: const Color(0xFF70E5C7),
                  onTap: () => widget.onSpeechToText?.call(),
                ),

              if (widget.onVoice != null)
                _ComposerIconButton(
                  icon: Icons.volume_up_rounded,
                  tooltip: 'قراءة آخر رد صوتيًا أو إيقافه',
                  enabled: !disabled,
                  color: const Color(0xFF83C8FF),
                  onTap: () => widget.onVoice?.call(),
                ),

              const SizedBox(width: 3),

              _SendButton(
                enabled: !disabled && _hasText,
                loading:
                    widget.isLoading || widget.isGeneratingImage,
                onTap: _send,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComposerIconButton extends StatelessWidget {
  const _ComposerIconButton({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.color,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final bool enabled;
  final Color color;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(11),
            child: Container(
              width: 34,
              height: 39,
              decoration: BoxDecoration(
                color: active
                    ? color.withValues(alpha: 0.18)
                    : const Color(0x221D3555),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: active
                      ? color.withValues(alpha: 0.8)
                      : const Color(0x334B6C9D),
                ),
              ),
              child: Icon(
                icon,
                size: 18,
                color: !enabled
                    ? const Color(0xFF536174)
                    : color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.enabled,
    required this.loading,
    required this.onTap,
  });

  final bool enabled;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 40,
          height: 39,
          decoration: BoxDecoration(
            gradient: enabled
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF67B7FF),
                      Color(0xFF397CD1),
                    ],
                  )
                : null,
            color: enabled
                ? null
                : const Color(0xFF1A263A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: enabled
                  ? const Color(0xFF83C8FF)
                  : const Color(0x444B6C9D),
            ),
            boxShadow: enabled
                ? const [
                    BoxShadow(
                      color: Color(0x33397CD1),
                      blurRadius: 7,
                      offset: Offset(0, 2),
                    ),
                  ]
                : const <BoxShadow>[],
          ),
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    Icons.arrow_upward_rounded,
                    color: enabled
                        ? const Color(0xFF061326)
                        : const Color(0xFF65748D),
                    size: 21,
                  ),
          ),
        ),
      ),
    );
  }
}
