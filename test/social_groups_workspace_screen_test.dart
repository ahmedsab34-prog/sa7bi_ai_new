import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sa7bi_ai/social_groups_workspace_screen.dart';

void main() {
  testWidgets(
    'shows public and private group destinations',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SocialGroupsWorkspaceScreen(),
        ),
      );

      expect(
        find.text('مجموعات صاحبي Connect'),
        findsOneWidget,
      );

      expect(
        find.text('المجموعات العامة'),
        findsOneWidget,
      );

      expect(
        find.text('مجموعاتي الخاصة'),
        findsOneWidget,
      );

      expect(
        find.text('أنت'),
        findsNothing,
      );
    },
  );
}
