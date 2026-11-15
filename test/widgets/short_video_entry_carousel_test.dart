import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sa7bi_ai/widgets/short_video_entry_carousel.dart';

void main() {
  testWidgets(
    'shows both horizontal video choices and opens each one',
    (tester) async {
      var reelsOpened = false;
      var shortsOpened = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Align(
                alignment: Alignment.topCenter,
                child: ShortVideoEntryCarousel(
                  onReelsTap: () {
                    reelsOpened = true;
                  },
                  onShortsTap: () {
                    shortsOpened = true;
                  },
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('ريلز المجتمع'), findsOneWidget);
      expect(find.text('مقاطع قصيرة'), findsOneWidget);

      await tester.tap(find.text('ريلز المجتمع'));
      await tester.pump();

      expect(reelsOpened, isTrue);
      expect(shortsOpened, isFalse);

      await tester.ensureVisible(find.text('مقاطع قصيرة'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('مقاطع قصيرة'));
      await tester.pump();

      expect(shortsOpened, isTrue);
    },
  );
}
