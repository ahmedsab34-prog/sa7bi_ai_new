
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/widgets/chat_image_viewer.dart';

void main() {
  testWidgets(
    'يفتح عارض الصورة بالحجم الكامل ويغلقه',
    (tester) async {
      final imageBytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/m/oAAAAASUVORK5CYII=',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return Center(
                  child: ElevatedButton(
                    key: const ValueKey<String>('open-chat-image'),
                    onPressed: () {
                      showChatImageViewer(context, imageBytes);
                    },
                    child: const Text('افتح الصورة'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(
        find.byKey(
          const ValueKey<String>('open-chat-image'),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey<String>('chat-image-viewer'),
        ),
        findsOneWidget,
      );

      expect(
        find.byTooltip('إغلاق الصورة'),
        findsOneWidget,
      );

      expect(
        find.byTooltip('إعادة ضبط التكبير'),
        findsOneWidget,
      );

      await tester.tap(
        find.byTooltip('إغلاق الصورة'),
      );

      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey<String>('chat-image-viewer'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'لا يفتح العارض عند تمرير صورة فارغة',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return Center(
                  child: ElevatedButton(
                    onPressed: () {
                      showChatImageViewer(
                        context,
                        <int>[].toBytes(),
                      );
                    },
                    child: const Text('اختبار صورة فارغة'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(
        find.text('اختبار صورة فارغة'),
      );

      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey<String>('chat-image-viewer'),
        ),
        findsNothing,
      );
    },
  );
}

extension on List<int> {
  List<int> toBytes() => List<int>.from(this);
}
