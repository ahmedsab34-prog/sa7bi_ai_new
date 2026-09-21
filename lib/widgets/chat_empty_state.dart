import 'package:flutter/material.dart';

import '../services/chat_theme_service.dart';
import 'chat_ai_avatar.dart';

/// واجهة البداية عندما تكون المحادثة فارغة.
///
/// مصممة لتكون خفيفة ولا تحتوي على مجموعة بطاقات أو أزرار كثيرة.
/// يمكن استخدامها مع صاحبي AI أو خلصانة AI أو أي خدمة من خدمات الشات.
class ChatEmptyState extends StatelessWidget {
  final ChatThemeData theme;

  /// اسم المحادثة.
  final String title;

  /// الوصف الاختياري.
  final String? subtitle;

  /// عند اختيار اقتراح سريع.
  final ValueChanged<String>? onSuggestionTap;

  /// الاقتراحات السريعة.
  final List<String> suggestions;

  const ChatEmptyState({
    super.key,
    required this.theme,
    this.title = 'صاحبي AI',
    this.subtitle,
    this.onSuggestionTap,
    this.suggestions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final safeTitle = title.trim().isEmpty
        ? 'صاحبي AI'
        : title.trim();

    final safeSubtitle =
        subtitle?.trim().isNotEmpty == true
            ? subtitle!.trim()
            : 'اتكلم معايا براحتك، وأنا هساعدك على قد ما أقدر';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          20,
          30,
          20,
          24,
        ),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            ChatAiAvatar(
              theme: theme,
              size: 92,
              animated: true,
            ),
            const SizedBox(height: 18),
            Text(
              safeTitle,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 330,
              ),
              child: Text(
                safeSubtitle,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(
                    alpha: 0.62,
                  ),
                  fontSize: 13,
                  height: 1.55,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (suggestions.isNotEmpty) ...[
              const SizedBox(height: 24),
              _Suggestions(
                theme: theme,
                suggestions: suggestions,
                onTap: onSuggestionTap,
              ),
            ],
          ],
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
    final visibleSuggestions =
        suggestions
            .where(
              (item) => item.trim().isNotEmpty,
            )
            .take(4)
            .toList();

    if (visibleSuggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: visibleSuggestions.map(
        (suggestion) {
          return _SuggestionChip(
            theme: theme,
            text: suggestion,
            onTap: onTap == null
                ? null
                : () => onTap!(suggestion),
          );
        },
      ).toList(),
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
        borderRadius: BorderRadius.circular(18),
        child: Container(
          constraints: const BoxConstraints(
            maxWidth: 170,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 13,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            color: theme.aiBubble.withValues(
              alpha: 0.78,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: theme.primary.withValues(
                alpha: 0.20,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: theme.glow.withValues(
                  alpha: 0.05,
                ),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(
                alpha: 0.88,
              ),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ),
      ),
    );
  }
}
