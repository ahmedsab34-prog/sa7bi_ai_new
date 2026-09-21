import 'package:flutter/material.dart';

import '../services/chat_theme_service.dart';

/// اقتراحات سريعة تظهر داخل المحادثة.
///
/// الملف مسؤول عن الواجهة فقط.
/// تنفيذ الرسالة نفسها يظل داخل ChatScreen.
class ChatQuickSuggestions extends StatelessWidget {
  final ChatThemeData theme;

  /// الاقتراحات التي سيتم عرضها.
  final List<String> suggestions;

  /// عند اختيار اقتراح.
  final ValueChanged<String>? onSelected;

  /// الحد الأقصى للاقتراحات المعروضة.
  final int maxItems;

  const ChatQuickSuggestions({
    super.key,
    required this.theme,
    this.suggestions = const [],
    this.onSelected,
    this.maxItems = 4,
  });

  @override
  Widget build(BuildContext context) {
    final items = suggestions
        .where(
          (item) => item.trim().isNotEmpty,
        )
        .map((item) => item.trim())
        .take(maxItems)
        .toList();

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        14,
        4,
        14,
        8,
      ),
      child: Align(
        alignment: Alignment.centerRight,
        child: Wrap(
          alignment: WrapAlignment.end,
          textDirection: TextDirection.rtl,
          spacing: 7,
          runSpacing: 7,
          children: items
              .map(
                (item) => _Suggestion(
                  theme: theme,
                  text: item,
                  onTap: onSelected == null
                      ? null
                      : () => onSelected!(item),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _Suggestion extends StatelessWidget {
  final ChatThemeData theme;
  final String text;
  final VoidCallback? onTap;

  const _Suggestion({
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
            maxWidth: 190,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.primary.withValues(
                  alpha: 0.16,
                ),
                theme.secondary.withValues(
                  alpha: 0.08,
                ),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: theme.primary.withValues(
                alpha: 0.22,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            textDirection: TextDirection.rtl,
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 14,
                color: theme.primary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
