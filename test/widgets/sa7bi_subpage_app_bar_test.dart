
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sa7bi_ai/widgets/sa7bi_subpage_app_bar.dart';

void main() {
  for (final viewport in <Size>[
    const Size(360, 640),
    const Size(412, 915),
  ]) {
    testWidgets(
      'subpage app bar fits ${viewport.width}x${viewport.height}',
      (tester) async {
        tester.view.physicalSize = viewport;
        tester.view.devicePixelRatio = 1.0;

        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                appBar: const Sa7biSubpageAppBar(
                  title: 'الألعاب والتواصل',
                  subtitle: 'اختار تجربتك وابدأ مع صاحبي AI',
                  actions: [
                    IconButton(
                      onPressed: null,
                      icon: Icon(Icons.refresh_rounded),
                    ),
                    IconButton(
                      onPressed: null,
                      icon: Icon(Icons.person_outline_rounded),
                    ),
                  ],
                ),
                body: const Center(
                  child: Text('اختبار مساحة الصفحة'),
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        expect(
          find.byType(Sa7biSubpageAppBar),
          findsOneWidget,
        );

        expect(
          tester.getSize(find.byType(AppBar)).height,
          96,
        );

        expect(
          tester.takeException(),
          isNull,
          reason: 'The subpage app bar must not overflow.',
        );
      },
    );
  }
}
