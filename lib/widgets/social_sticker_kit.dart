
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/social_sticker.dart';

class Sa7biStickerPicker {
  Sa7biStickerPicker._();

  static Future<Sa7biSticker?> show(BuildContext context) {
    return showModalBottomSheet<Sa7biSticker>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF101827),
      barrierColor: Colors.black54,
      useSafeArea: true,
      builder: (_) => const _Sa7biStickerPickerSheet(),
    );
  }
}

class _Sa7biStickerPickerSheet extends StatefulWidget {
  const _Sa7biStickerPickerSheet();

  @override
  State<_Sa7biStickerPickerSheet> createState() =>
      _Sa7biStickerPickerSheetState();
}

class _Sa7biStickerPickerSheetState
    extends State<_Sa7biStickerPickerSheet> {
  String _selectedPack = 'الكل';

  @override
  Widget build(BuildContext context) {
    final stickers = Sa7biStickerCatalog.forPack(_selectedPack);
    final packs = <String>[
      'الكل',
      ...Sa7biStickerCatalog.packTitles,
    ];

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.78,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Row(
              children: [
                const Icon(
                  Icons.emoji_emotions_rounded,
                  color: Color(0xFFFFD76A),
                  size: 25,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'استيكرات صاحبي',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '${Sa7biStickerCatalog.all.length} استيكر مميز',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'إغلاق',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              scrollDirection: Axis.horizontal,
              itemCount: packs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final pack = packs[index];
                final selected = pack == _selectedPack;

                return ChoiceChip(
                  label: Text(pack),
                  selected: selected,
                  onSelected: (_) {
                    setState(() => _selectedPack = pack);
                  },
                  selectedColor: const Color(0xFFFFD76A),
                  backgroundColor: const Color(0xFF1C293B),
                  labelStyle: TextStyle(
                    color: selected
                        ? const Color(0xFF111827)
                        : Colors.white70,
                    fontWeight: FontWeight.w800,
                  ),
                  side: BorderSide(
                    color: selected
                        ? const Color(0xFFFFD76A)
                        : Colors.white12,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.92,
              ),
              itemCount: stickers.length,
              itemBuilder: (context, index) {
                final sticker = stickers[index];

                return InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => Navigator.pop(context, sticker),
                  child: Sa7biStickerArt(
                    sticker: sticker,
                    showBrand: true,
                  ),
                );
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Text(
              'اختار الاستيكر وهيتبعت مباشرة في المحادثة.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white54,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class Sa7biStickerArt extends StatelessWidget {
  const Sa7biStickerArt({
    super.key,
    required this.sticker,
    this.showBrand = false,
  });

  final Sa7biSticker sticker;
  final bool showBrand;

  @override
  Widget build(BuildContext context) {
    final start = Color(sticker.startColor);
    final end = Color(sticker.endColor);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [start, end],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.55),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: end.withValues(alpha: 0.30),
            blurRadius: 15,
            spreadRadius: 1,
            offset: const Offset(0, 7),
          ),
          const BoxShadow(
            color: Color(0x66000000),
            blurRadius: 9,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              top: -35,
              right: -30,
              child: Container(
                width: 115,
                height: 115,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.30),
                      Colors.white.withValues(alpha: 0.01),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -42,
              left: -34,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.20),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (showBrand)
                    Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.20),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22),
                          ),
                        ),
                        child: const Text(
                          'صاحبي AI',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: Text(
                          sticker.emoji,
                          style: const TextStyle(
                            fontSize: 76,
                            shadows: [
                              Shadow(
                                color: Color(0x99000000),
                                blurRadius: 2,
                                offset: Offset(0, 5),
                              ),
                              Shadow(
                                color: Color(0x55000000),
                                blurRadius: 10,
                                offset: Offset(0, 11),
                              ),
                              Shadow(
                                color: Color(0x88FFFFFF),
                                blurRadius: 2,
                                offset: Offset(-2, -3),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Text(
                    sticker.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sticker.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      shadows: [
                        Shadow(
                          color: Colors.black38,
                          blurRadius: 3,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Sa7biStickerMessageView extends StatelessWidget {
  const Sa7biStickerMessageView({
    super.key,
    required this.sticker,
  });

  final Sa7biSticker sticker;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Sa7biStickerArt(
              sticker: sticker,
              showBrand: true,
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => shareSa7biSticker(context, sticker),
              icon: const Icon(
                Icons.share_rounded,
                size: 15,
              ),
              label: const Text('مشاركة الاستيكر'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white70,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                textStyle: const TextStyle(fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// يحوّل تصميم الاستيكر إلى PNG ويتيح مشاركته من أندرويد.
Future<void> shareSa7biSticker(
  BuildContext context,
  Sa7biSticker sticker,
) async {
  try {
    const size = 512.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final bounds = const Rect.fromLTWH(0, 0, size, size);

    final rounded = RRect.fromRectAndRadius(
      bounds.deflate(8),
      const Radius.circular(58),
    );

    final stickerPath = Path()..addRRect(rounded);

    canvas.drawShadow(
      stickerPath,
      const Color(0xAA000000),
      22,
      true,
    );

    canvas.save();
    canvas.clipRRect(rounded);

    final backgroundPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [
          Color(sticker.startColor),
          Color(sticker.endColor),
        ],
      ).createShader(bounds);

    canvas.drawRRect(rounded, backgroundPaint);

    final shinePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.40),
          Colors.white.withValues(alpha: 0.01),
        ],
      ).createShader(
        const Rect.fromLTWH(15, 15, 330, 260),
      );

    canvas.drawOval(
      const Rect.fromLTWH(15, 15, 330, 260),
      shinePaint,
    );

    final darkGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.black.withValues(alpha: 0.22),
          Colors.transparent,
        ],
      ).createShader(
        const Rect.fromLTWH(180, 250, 360, 300),
      );

    canvas.drawCircle(
      const Offset(430, 440),
      180,
      darkGlow,
    );

    canvas.restore();

    canvas.drawRRect(
      rounded,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..shader = const LinearGradient(
          colors: [
            Color(0xFFFFFFFF),
            Color(0x99FFFFFF),
            Color(0xFFFFD76A),
          ],
        ).createShader(bounds),
    );

    final brandPainter = TextPainter(
      text: const TextSpan(
        text: 'صاحبي AI',
        style: TextStyle(
          color: Colors.white,
          fontSize: 27,
          fontWeight: FontWeight.w900,
          shadows: [
            Shadow(
              color: Colors.black54,
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.center,
    )..layout(maxWidth: 420);

    brandPainter.paint(
      canvas,
      Offset((size - brandPainter.width) / 2, 44),
    );

    final emojiPainter = TextPainter(
      text: TextSpan(
        text: sticker.emoji,
        style: const TextStyle(
          fontSize: 176,
          shadows: [
            Shadow(
              color: Color(0xAA000000),
              blurRadius: 3,
              offset: Offset(0, 9),
            ),
            Shadow(
              color: Color(0x66000000),
              blurRadius: 14,
              offset: Offset(0, 17),
            ),
            Shadow(
              color: Color(0x88FFFFFF),
              blurRadius: 2,
              offset: Offset(-3, -4),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: 420);

    emojiPainter.paint(
      canvas,
      Offset((size - emojiPainter.width) / 2, 115),
    );

    final titlePainter = TextPainter(
      text: TextSpan(
        text: sticker.title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 43,
          fontWeight: FontWeight.w900,
          shadows: [
            Shadow(
              color: Colors.black54,
              blurRadius: 7,
              offset: Offset(0, 3),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.center,
      maxLines: 1,
    )..layout(maxWidth: 440);

    titlePainter.paint(
      canvas,
      Offset((size - titlePainter.width) / 2, 335),
    );

    final captionPainter = TextPainter(
      text: TextSpan(
        text: sticker.caption,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.w700,
          shadows: [
            Shadow(
              color: Colors.black45,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.center,
      maxLines: 2,
    )..layout(maxWidth: 430);

    captionPainter.paint(
      canvas,
      Offset((size - captionPainter.width) / 2, 405),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(512, 512);
    picture.dispose();

    final byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    image.dispose();

    if (byteData == null) {
      throw const FormatException('PNG encoding failed.');
    }

    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/sa7bi-sticker-${sticker.id}.png',
    );

    await file.writeAsBytes(
      byteData.buffer.asUint8List(),
      flush: true,
    );

    await Share.shareXFiles(
      <XFile>[XFile(file.path)],
      text: 'استيكر من صاحبي AI',
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر تجهيز صورة الاستيكر للمشاركة.'),
        ),
      );
    }
  }
}
