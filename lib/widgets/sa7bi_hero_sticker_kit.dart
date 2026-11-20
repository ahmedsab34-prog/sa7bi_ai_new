import 'package:flutter/material.dart';

import '../models/sa7bi_hero_chat_sticker.dart';
import '../models/social_sticker.dart';
import 'sa7bi_hero_3d.dart';
import 'social_sticker_kit.dart';

/// Returns a message token for an animated GIF, a 3D character sticker,
/// or one of the existing 100 classic stickers.
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
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
      length: 3,
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
              tabs: <Widget>[
                Tab(text: 'GIF متحركة'),
                Tab(text: 'مجسم 3D'),
                Tab(text: 'ثابتة'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _HeroMotionGrid(
                    stickers: Sa7biHeroChatStickerCatalog.animatedGifs,
                  ),
                  _HeroMotionGrid(
                    stickers: Sa7biHeroChatStickerCatalog.threeDimensional,
                    threeDimensional: true,
                  ),
                  const _ClassicStickerGrid(),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Text(
                'الملصقات الثلاثية الأبعاد تفتح المجسم عند الضغط عليها داخل الرسالة.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 10),
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
    this.threeDimensional = false,
  });

  final List<Sa7biHeroChatSticker> stickers;
  final bool threeDimensional;

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
            onTap: () => Navigator.pop(context, sticker.toMessageText()),
            child: Padding(
              padding: const EdgeInsets.all(7),
              child: Column(
                children: [
                  Expanded(
                    child: Image.asset(
                      sticker.assetPath,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white38,
                        size: 28,
                      ),
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
                  if (threeDimensional)
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.view_in_ar_rounded,
                        color: Color(0xFFFFD76A),
                        size: 14,
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
          onTap: () => Navigator.pop(context, sticker.toMessageText()),
          child: Sa7biStickerArt(
            sticker: sticker,
            showBrand: true,
          ),
        );
      },
    );
  }
}

/// Displays both old static sticker tokens and the new animated/3D tokens.
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
        style: const TextStyle(color: Colors.white, height: 1.45),
      );
    }

    final preview = ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.asset(
        sticker.assetPath,
        width: 148,
        height: 148,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => const SizedBox(
          width: 148,
          height: 148,
          child: Icon(
            Icons.broken_image_outlined,
            color: Colors.white38,
            size: 32,
          ),
        ),
      ),
    );

    if (!sticker.isThreeDimensional) {
      return preview;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openThreeDimensionalViewer(context, sticker),
          child: Stack(
            alignment: Alignment.center,
            children: [
              preview,
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFFD76A)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.view_in_ar_rounded,
                      color: Color(0xFFFFD76A),
                      size: 17,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'افتح المجسم 3D',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 3),
        Text(
          sticker.title,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ],
    );
  }

  void _openThreeDimensionalViewer(
    BuildContext context,
    Sa7biHeroChatSticker sticker,
  ) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog.fullscreen(
          backgroundColor: const Color(0xFF080B13),
          child: Scaffold(
            backgroundColor: const Color(0xFF080B13),
            appBar: AppBar(
              backgroundColor: const Color(0xFF101827),
              foregroundColor: Colors.white,
              title: const Text(
                'صاحبي AI',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
              ),
              leading: IconButton(
                tooltip: 'إغلاق',
                onPressed: () => Navigator.pop(dialogContext),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
            body: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Sa7biHero3D(
                        animationName: sticker.animationName ?? 'Hero_Idle',
                        cameraControls: true,
                        compact: false,
                        enableFaceAnimations: false,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                    child: Text(
                      sticker.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w800,
                      ),
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
