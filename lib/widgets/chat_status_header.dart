
import 'package:flutter/material.dart';

import '../services/chat_theme_service.dart';
import 'chat_ai_avatar.dart';

/// رأس محادثة صغير يحافظ على الحالة والعنوان وأدوات التحكم.
class ChatStatusHeader extends StatelessWidget {
  final ChatThemeData theme;
  final String title;
  final String? topic;
  final bool isLoading;
  final bool canClear;
  final VoidCallback? onClear;
  final VoidCallback? onTap;
  final bool showTitle;

  const ChatStatusHeader({
    super.key,
    required this.theme,
    required this.title,
    this.topic,
    this.isLoading = false,
    this.canClear = false,
    this.onClear,
    this.onTap,
    this.showTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    final safeTitle = title.trim().isEmpty
        ? 'صاحبي AI'
        : title.trim();
    final safeTopic = topic?.trim() ?? '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          margin: const EdgeInsets.fromLTRB(7, 4, 7, 2),
          padding: const EdgeInsets.symmetric(
            horizontal: 9,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: theme.aiBubble.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: theme.primary.withValues(alpha: 0.16),
            ),
          ),
          child: Row(
            children: [
              ChatAiAvatar(
                theme: theme,
                size: 34,
                animated: !isLoading,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showTitle)
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
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          _OnlineIndicator(
                            active: !isLoading,
                            color: theme.secondary,
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          _OnlineIndicator(
                            active: !isLoading,
                            color: theme.secondary,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              isLoading
                                  ? 'جاري تجهيز الرد'
                                  : 'المساعد جاهز',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                color: theme.secondary,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (showTitle) const SizedBox(height: 2),
                    _buildStatus(safeTopic),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation<Color>(
                theme.secondary,
              ),
            ),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              'بيفكر في الرد...',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                color: theme.secondary.withValues(alpha: 0.85),
                fontSize: 9.5,
              ),
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
            size: 10,
            color: theme.primary,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              'الموضوع: $safeTopic',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.58),
                fontSize: 9.5,
              ),
            ),
          ),
        ],
      );
    }

    return Text(
      'جاهز للكلام معاك',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textDirection: TextDirection.rtl,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.52),
        fontSize: 9.5,
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
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active
            ? color
            : Colors.white.withValues(alpha: 0.25),
        boxShadow: active
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.45),
                  blurRadius: 5,
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
        size: 18,
      ),
      padding: const EdgeInsets.all(3),
      constraints: const BoxConstraints(
        minWidth: 30,
        minHeight: 30,
      ),
    );
  }
}
