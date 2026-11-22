import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sa7bi_ai/owner_profile_screen.dart';

void main() {
  testWidgets('founder profile page shows its owner identity', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));

    await tester.pumpWidget(
      const MaterialApp(
        home: OwnerProfileScreen(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('أحمد سليمان حسين صبرة'), findsOneWidget);
    expect(find.text('مؤسس ومطوّر المشروع'), findsOneWidget);
    expect(find.text('Founder & Developer'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });
}
