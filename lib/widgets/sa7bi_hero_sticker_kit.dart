
import 'package:flutter/material.dart';

import '../models/sa7bi_hero_chat_sticker.dart';
import '../models/social_sticker.dart';
import 'social_sticker_kit.dart';

/// اختيار ملصقات HERO المتحركة والثابتة.
/// لا يفتح أي عارض GLB أو WebView.
class Sa7biHeroStickerPicker {
  Sa7biHeroStickerPicker._();

  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF101827),
      barrierColor: Colors.black54,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(22),
        ),
      ),
      builder: (_) => const _Sa7biHeroStickerPickerSheet(),
    );
  }
}

class _Sa7biHeroStickerPickerSheet extends StatelessWidget {
  const _Sa7biHeroStickerPickerSheet();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.78,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 13, 16, 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.emoji_emotions_rounded,
                    color: Color(0xFFFFD76A),
                    size: 24,
                  ),
                  const SizedBox(width: 9),
                  const Expanded(
                    child: Text(
                      'ملصقات صاحبي AI',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
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
            const TabBar(
              isScrollable: false,
              labelColor: Color(0xFFFFD76A),
              unselectedLabelColor: Colors.white60,
              indicatorColor: Color(0xFFFFD76A),
              tabs: [
                Tab(text: 'HERO متحرك 2.5D'),
                Tab(text: 'ملصقات ثابتة'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _HeroMotionGrid(
                    stickers: Sa7biHeroChatStickerCatalog.animatedGifs,
                  ),
                  const _ClassicStickerGrid(),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Text(
                'شخصية HERO واحدة بنفس الوجه والدرع وشعار صاحبي AI.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroMotionGrid extends StatelessWidget {
  const _HeroMotionGrid({
    required this.stickers,
  });

  final List<Sa7biHeroChatSticker> stickers;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.83,
      ),
      itemCount: stickers.length,
      itemBuilder: (context, index) {
        final sticker = stickers[index];

        return Material(
          color: const Color(0xFF19263A),
          borderRadius: BorderRadius.circular(15),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              Navigator.pop(context, sticker.toMessageText());
            },
            child: Padding(
              padding: const EdgeInsets.all(7),
              child: Column(
                children: [
                  Expanded(
                    child: Image.asset(
                      sticker.assetPath,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                      errorBuilder: (_, __, ___) {
                        return const Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white38,
                          size: 28,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    sticker.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ClassicStickerGrid extends StatelessWidget {
  const _ClassicStickerGrid();

  @override
  Widget build(BuildContext context) {
    final stickers = Sa7biStickerCatalog.all;

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.94,
      ),
      itemCount: stickers.length,
      itemBuilder: (context, index) {
        final sticker = stickers[index];

        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.pop(context, sticker.toMessageText());
          },
          child: Sa7biStickerArt(
            sticker: sticker,
            showBrand: true,
          ),
        );
      },
    );
  }
}

/// عرض ملصقات HERO القديمة والجديدة داخل الرسائل.
/// رموز 3D القديمة تظل قابلة للعرض كـGIF فقط، بلا فتح مجسم.
class Sa7biHeroChatStickerMessageView extends StatelessWidget {
  const Sa7biHeroChatStickerMessageView({
    super.key,
    required this.messageText,
  });

  final String messageText;

  @override
  Widget build(BuildContext context) {
    final oldSticker = Sa7biSticker.tryParse(messageText);

    if (oldSticker != null) {
      return Sa7biStickerMessageView(sticker: oldSticker);
    }

    final sticker = Sa7biHeroChatSticker.tryParse(messageText);

    if (sticker == null) {
      return SelectableText(
        messageText,
        style: const TextStyle(
          color: Colors.white,
          height: 1.45,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.asset(
            sticker.assetPath,
            width: 148,
            height: 148,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) {
              return const SizedBox(
                width: 148,
                height: 148,
                child: Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white38,
                  size: 32,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 3),
        Text(
          sticker.title,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
