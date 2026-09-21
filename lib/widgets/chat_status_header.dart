import 'package:flutter/material.dart';

import '../services/chat_theme_service.dart';
import 'chat_ai_avatar.dart';

/// رأس المحادثة الديناميكي.
///
/// يعرض:
/// - أيقونة AI الخاصة بالثيم الحالي.
/// - اسم المحادثة.
/// - الموضوع الحالي إذا تم اكتشافه.
/// - حالة الذكاء الاصطناعي.
/// - زر اختياري لمسح المحادثة.
class ChatStatusHeader extends StatelessWidget {
  final ChatThemeData theme;

  /// اسم الخدمة أو المحادثة.
  final String title;

  /// الموضوع الحالي المكتشف من الرسائل.
  final String? topic;

  /// حالة المعالجة.
  final bool isLoading;

  /// هل يمكن مسح المحادثة؟
  final bool canClear;

  /// عند الضغط على مسح المحادثة.
  final VoidCallback? onClear;

  /// عند الضغط على الرأس نفسه.
  final VoidCallback? onTap;

  const ChatStatusHeader({
    super.key,
    required this.theme,
    required this.title,
    this.topic,
    this.isLoading = false,
    this.canClear = false,
    this.onClear,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final safeTitle =
        title.trim().isEmpty ? 'صاحبي AI' : title.trim();

    final safeTopic = topic?.trim() ?? '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          margin: const EdgeInsets.fromLTRB(
            10,
            8,
            10,
            4,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 11,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            color: theme.aiBubble.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.primary.withValues(alpha: 0.16),
            ),
            boxShadow: [
              BoxShadow(
                color: theme.glow.withValues(alpha: 0.06),
                blurRadius: 15,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            children: [
              ChatAiAvatar(
                theme: theme,
                size: 42,
                animated: !isLoading,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            safeTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textDirection: TextDirection.rtl,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        _OnlineIndicator(
                          active: !isLoading,
                          color: theme.secondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    _buildStatus(
                      safeTopic,
                    ),
                  ],
                ),
              ),
              if (canClear && onClear != null)
                _ClearButton(
                  color: theme.primary,
                  onTap: onClear!,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatus(String safeTopic) {
    if (isLoading) {
      return Row(
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor:
                  AlwaysStoppedAnimation<Color>(
                theme.secondary,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'بيفكر في الرد...',
            textDirection: TextDirection.rtl,
            style: TextStyle(
              color: theme.secondary.withValues(alpha: 0.85),
              fontSize: 10.5,
            ),
          ),
        ],
      );
    }

    if (safeTopic.isNotEmpty) {
      return Row(
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            size: 12,
            color: theme.primary,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              'الموضوع: $safeTopic',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.58),
                fontSize: 10.5,
              ),
            ),
          ),
        ],
      );
    }

    return Text(
      'جاهز للكلام معاك',
      textDirection: TextDirection.rtl,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.52),
        fontSize: 10.5,
      ),
    );
  }
}

class _OnlineIndicator extends StatelessWidget {
  final bool active;
  final Color color;

  const _OnlineIndicator({
    required this.active,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active
            ? color
            : Colors.white.withValues(alpha: 0.25),
        boxShadow: active
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.55),
                  blurRadius: 7,
                ),
              ]
            : null,
      ),
    );
  }
}

class _ClearButton extends StatelessWidget {
  final Color color;
  final VoidCallback onTap;

  const _ClearButton({
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'مسح المحادثة',
      onPressed: onTap,
      icon: Icon(
        Icons.delete_outline_rounded,
        color: color.withValues(alpha: 0.72),
        size: 21,
      ),
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(
        minWidth: 36,
        minHeight: 36,
      ),
    );
  }
}
