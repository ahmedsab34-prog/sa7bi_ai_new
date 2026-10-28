
import 'package:flutter/material.dart';

import '../services/chat_theme_service.dart';
import 'chat_ai_avatar.dart';

/// واجهة بداية المحادثة بتصميم مدمج ومساحة أوسع.
class ChatEmptyState extends StatelessWidget {
  final ChatThemeData theme;
  final String title;
  final String? subtitle;
  final ValueChanged<String>? onSuggestionTap;
  final List<String> suggestions;
  final bool showTitle;

  const ChatEmptyState({
    super.key,
    required this.theme,
    this.title = 'صاحبي AI',
    this.subtitle,
    this.onSuggestionTap,
    this.suggestions = const [],
    this.showTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    final safeTitle =
        title.trim().isEmpty ? 'صاحبي AI' : title.trim();

    final safeSubtitle =
        subtitle?.trim().isNotEmpty == true
            ? subtitle!.trim()
            : 'اتكلم معايا براحتك، وأنا هساعدك على قد ما أقدر';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 18, 12, 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      theme.primary.withValues(alpha: 0.15),
                      theme.secondary.withValues(alpha: 0.08),
                    ],
                  ),
                  border: Border.all(
                    color: theme.primary.withValues(alpha: 0.16),
                  ),
                ),
                child: ChatAiAvatar(
                  theme: theme,
                  size: 66,
                  animated: true,
                ),
              ),
              if (showTitle) ...[
                const SizedBox(height: 12),
                Text(
                  safeTitle,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 390),
                child: Text(
                  safeSubtitle,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.66),
                    fontSize: 12,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (suggestions.isNotEmpty) ...[
                const SizedBox(height: 18),
                _Suggestions(
                  theme: theme,
                  suggestions: suggestions,
                  onTap: onSuggestionTap,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Suggestions extends StatelessWidget {
  final ChatThemeData theme;
  final List<String> suggestions;
  final ValueChanged<String>? onTap;

  const _Suggestions({
    required this.theme,
    required this.suggestions,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final visibleSuggestions = suggestions
        .where((item) => item.trim().isNotEmpty)
        .take(4)
        .toList();

    if (visibleSuggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 7,
      runSpacing: 7,
      children: visibleSuggestions.map((suggestion) {
        return _SuggestionChip(
          theme: theme,
          text: suggestion,
          onTap: onTap == null ? null : () => onTap!(suggestion),
        );
      }).toList(),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final ChatThemeData theme;
  final String text;
  final VoidCallback? onTap;

  const _SuggestionChip({
    required this.theme,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 190),
          padding: const EdgeInsets.symmetric(
            horizontal: 11,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: theme.aiBubble.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: theme.primary.withValues(alpha: 0.20),
            ),
          ),
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ),
      ),
    );
  }
}
