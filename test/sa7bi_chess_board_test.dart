import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sa7bi_ai/widgets/sa7bi_chess_board.dart';

void main() {
  const startingFen =
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  testWidgets(
    'renders a playable board and returns tapped square coordinates',
    (tester) async {
      String? moveFrom;
      String? moveTo;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: Sa7biChessBoard(
                  fen: startingFen,
                  bottomSide: Sa7biChessSide.white,
                  enabled: true,
                  onMove: (from, to) async {
                    moveFrom = from;
                    moveTo = to;
                  },
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('chess-square-e2')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('chess-square-e4')),
        findsOneWidget,
      );
      expect(find.text('♙'), findsWidgets);
      expect(find.text('♟'), findsWidgets);

      await tester.tap(
        find.byKey(const ValueKey('chess-square-e2')),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const ValueKey('chess-square-e4')),
      );
      await tester.pumpAndSettle();

      expect(moveFrom, 'e2');
      expect(moveTo, 'e4');
    },
  );

  testWidgets(
    'rotates the board for the black player',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: Sa7biChessBoard(
                  fen: startingFen,
                  bottomSide: Sa7biChessSide.black,
                  enabled: true,
                  onMove: (from, to) async {},
                ),
              ),
            ),
          ),
        ),
      );

      // مع الأسود في الأسفل، المربع a8 يظهر أسفل يمين الرقعة.
      final a8 = tester.getTopLeft(
        find.byKey(const ValueKey('chess-square-a8')),
      );
      final h1 = tester.getTopLeft(
        find.byKey(const ValueKey('chess-square-h1')),
      );

      expect(a8.dy, greaterThan(h1.dy));
      expect(a8.dx, greaterThan(h1.dx));
    },
  );
}
