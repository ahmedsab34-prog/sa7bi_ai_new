import 'package:flutter/material.dart';

enum Sa7biChessSide { white, black }

/// لوحة شطرنج تفاعلية للمباريات الجماعية ومباريات الذكاء الاصطناعي.
/// الخادم يظل المصدر المعتمد للتحقق من قانونية النقلات.
class Sa7biChessBoard extends StatefulWidget {
  const Sa7biChessBoard({
    super.key,
    required this.fen,
    required this.bottomSide,
    required this.enabled,
    required this.onMove,
  });

  final String fen;
  final Sa7biChessSide bottomSide;
  final bool enabled;
  final Future<void> Function(String from, String to) onMove;

  @override
  State<Sa7biChessBoard> createState() => _Sa7biChessBoardState();
}

class _Sa7biChessBoardState extends State<Sa7biChessBoard> {
  static const List<String> _files = <String>[
    'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h',
  ];

  static const Map<String, String> _symbols = <String, String>{
    'K': '♔',
    'Q': '♕',
    'R': '♖',
    'B': '♗',
    'N': '♘',
    'P': '♙',
    'k': '♚',
    'q': '♛',
    'r': '♜',
    'b': '♝',
    'n': '♞',
    'p': '♟',
  };

  static const Color _lightSquare = Color(0xFFE9DEC8);
  static const Color _darkSquare = Color(0xFF668365);
  static const Color _selectedSquare = Color(0xFFD6AD45);
  static const Color _ink = Color(0xFF192334);

  String? _selectedSquareName;
  bool _submitting = false;

  @override
  void didUpdateWidget(covariant Sa7biChessBoard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.fen != widget.fen ||
        oldWidget.bottomSide != widget.bottomSide ||
        oldWidget.enabled != widget.enabled) {
      _selectedSquareName = null;
      _submitting = false;
    }
  }

  Map<String, String>? _parseFen(String fen) {
    final trimmed = fen.trim();
    if (trimmed.isEmpty) return null;

    final placement = trimmed.split(RegExp(r'\s+')).first;
    final ranks = placement.split('/');

    if (ranks.length != 8) return null;

    final pieces = <String, String>{};

    for (var row = 0; row < 8; row++) {
      var file = 0;

      for (final token in ranks[row].split('')) {
        final emptyCount = int.tryParse(token);

        if (emptyCount != null) {
          if (emptyCount < 1 || emptyCount > 8) return null;
          file += emptyCount;
          continue;
        }

        if (!_symbols.containsKey(token) || file >= 8) {
          return null;
        }

        final square = '${_files[file]}${8 - row}';
        pieces[square] = token;
        file++;
      }

      if (file != 8) return null;
    }

    return pieces;
  }

  bool _isOwnPiece(String piece) {
    final isWhite = piece == piece.toUpperCase();

    return widget.bottomSide == Sa7biChessSide.white
        ? isWhite
        : !isWhite;
  }

  Future<void> _tapSquare(String square, String? piece) async {
    if (!widget.enabled || _submitting) return;

    final selected = _selectedSquareName;

    if (selected == null) {
      if (piece != null && _isOwnPiece(piece)) {
        setState(() => _selectedSquareName = square);
      }
      return;
    }

    if (selected == square) {
      setState(() => _selectedSquareName = null);
      return;
    }

    if (piece != null && _isOwnPiece(piece)) {
      setState(() => _selectedSquareName = square);
      return;
    }

    setState(() => _submitting = true);

    try {
      await widget.onMove(selected, square);
    } finally {
      if (mounted) {
        setState(() {
          _selectedSquareName = null;
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pieces = _parseFen(widget.fen);

    if (pieces == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF172033),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        ),
        child: const Text(
          'تعذر قراءة وضع الشطرنج الحالي من الخادم. حدّث المباراة للمحاولة مرة أخرى.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white70,
            height: 1.5,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color(0xFFFFD76A).withValues(alpha: 0.65),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: GridView.builder(
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 64,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 8,
                  crossAxisSpacing: 0,
                  mainAxisSpacing: 0,
                ),
                itemBuilder: (context, index) {
                  final displayRow = index ~/ 8;
                  final displayColumn = index % 8;

                  final fenRow = widget.bottomSide == Sa7biChessSide.white
                      ? displayRow
                      : 7 - displayRow;

                  final file = widget.bottomSide == Sa7biChessSide.white
                      ? displayColumn
                      : 7 - displayColumn;

                  final square = '${_files[file]}${8 - fenRow}';
                  final piece = pieces[square];

                  // a1 تكون داكنة، والنمط يتناوب على كل المربعات.
                  final isDark = (fenRow + file).isOdd;
                  final isSelected = square == _selectedSquareName;

                  final squareColor = isSelected
                      ? _selectedSquare
                      : isDark
                          ? _darkSquare
                          : _lightSquare;

                  final labelColor = isDark || isSelected
                      ? Colors.white.withValues(alpha: 0.86)
                      : _ink.withValues(alpha: 0.68);

                  return Material(
                    color: squareColor,
                    child: InkWell(
                      key: ValueKey<String>('chess-square-$square'),
                      onTap: widget.enabled && !_submitting
                          ? () => _tapSquare(square, piece)
                          : null,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final pieceSize =
                              (constraints.maxWidth * 0.78)
                                  .clamp(18.0, 46.0)
                                  .toDouble();

                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              if (piece != null)
                                Center(
                                  child: FittedBox(
                                    fit: BoxFit.contain,
                                    child: Text(
                                      _symbols[piece]!,
                                      style: TextStyle(
                                        fontSize: pieceSize,
                                        height: 1,
                                        color: piece == piece.toUpperCase()
                                            ? const Color(0xFFFDFCF8)
                                            : const Color(0xFF101722),
                                        shadows: [
                                          Shadow(
                                            color: piece == piece.toUpperCase()
                                                ? const Color(0xAA182235)
                                                : const Color(0x66FFFFFF),
                                            blurRadius: 1.5,
                                            offset: const Offset(0.5, 1),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              if (displayColumn == 0)
                                Positioned(
                                  top: 1,
                                  left: 3,
                                  child: Text(
                                    square[1],
                                    style: TextStyle(
                                      color: labelColor,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              if (displayRow == 7)
                                Positioned(
                                  right: 3,
                                  bottom: 1,
                                  child: Text(
                                    square[0],
                                    style: TextStyle(
                                      color: labelColor,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              if (isSelected)
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: const Color(0xFFFFE9A6),
                                          width: 2.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 9),
        Text(
          _submitting
              ? 'جارٍ إرسال النقلة...'
              : widget.enabled
                  ? 'اضغط على القطعة التي تريد تحريكها، ثم اضغط على مربع الوصول.'
                  : 'انتظر دورك. ستتفعّل اللوحة عندما يصبح اللعب متاحًا لك.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 11,
            height: 1.4,
          ),
        ),
        if (_submitting) ...[
          const SizedBox(height: 8),
          const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ],
      ],
    );
  }
}
