import 'dart:convert';

enum Sa7biHeroChatStickerType {
  animatedGif,
  threeDimensional,
}

/// A compact, versioned message token for stickers made from the original
/// Sa7bi AI character. The actual GLB stays in the app bundle; messages carry
/// only a validated sticker ID, so no GLB upload or Worker route is required.
class Sa7biHeroChatSticker {
  const Sa7biHeroChatSticker({
    required this.id,
    required this.title,
    required this.assetPath,
    required this.type,
    this.animationName,
  });

  final String id;
  final String title;
  final String assetPath;
  final Sa7biHeroChatStickerType type;
  final String? animationName;

  bool get isThreeDimensional =>
      type == Sa7biHeroChatStickerType.threeDimensional;

  static const String messagePrefix = 'SA7BI_HERO_STICKER_V1:';

  String toMessageText() {
    final payload = jsonEncode(<String, dynamic>{
      'version': 1,
      'stickerId': id,
    });
    final encoded = base64Url
        .encode(utf8.encode(payload))
        .replaceAll('=', '');
    return '$messagePrefix$encoded';
  }

  static Sa7biHeroChatSticker? tryParse(String value) {
    if (!value.startsWith(messagePrefix)) return null;

    final encoded = value.substring(messagePrefix.length).trim();
    if (encoded.isEmpty || encoded.length > 512) return null;

    try {
      final decoded = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(encoded))),
      );
      if (decoded is! Map || decoded['version'] != 1) return null;
      final id = decoded['stickerId'];
      if (id is! String) return null;
      return Sa7biHeroChatStickerCatalog.byId[id];
    } catch (_) {
      return null;
    }
  }
}

class Sa7biHeroChatStickerCatalog {
  Sa7biHeroChatStickerCatalog._();

  // The nine GIFs were uploaded to assets/3d. Keep these exact filenames;
  // several have a (3) suffix because GitHub preserved duplicate uploads.
  static const List<Sa7biHeroChatSticker> animatedGifs =
      <Sa7biHeroChatSticker>[
    Sa7biHeroChatSticker(
      id: 'gif_hello',
      title: 'ترحيب',
      assetPath: 'assets/3d/hero_hello(3).gif',
      type: Sa7biHeroChatStickerType.animatedGif,
    ),
    Sa7biHeroChatSticker(
      id: 'gif_power',
      title: 'قوة',
      assetPath: 'assets/3d/hero_power(3).gif',
      type: Sa7biHeroChatStickerType.animatedGif,
    ),
    Sa7biHeroChatSticker(
      id: 'gif_idle',
      title: 'استعداد',
      assetPath: 'assets/3d/hero_idle(3).gif',
      type: Sa7biHeroChatStickerType.animatedGif,
    ),
    Sa7biHeroChatSticker(
      id: 'gif_smile',
      title: 'ابتسامة',
      assetPath: 'assets/3d/hero_smile(3).gif',
      type: Sa7biHeroChatStickerType.animatedGif,
    ),
    Sa7biHeroChatSticker(
      id: 'gif_sad',
      title: 'حزن',
      assetPath: 'assets/3d/hero_sad(3).gif',
      type: Sa7biHeroChatStickerType.animatedGif,
    ),
    Sa7biHeroChatSticker(
      id: 'gif_surprise',
      title: 'دهشة',
      assetPath: 'assets/3d/hero_surprise.gif',
      type: Sa7biHeroChatStickerType.animatedGif,
    ),
    Sa7biHeroChatSticker(
      id: 'gif_angry',
      title: 'غضب',
      assetPath: 'assets/3d/hero_angry(3).gif',
      type: Sa7biHeroChatStickerType.animatedGif,
    ),
    Sa7biHeroChatSticker(
      id: 'gif_wink',
      title: 'غمزة',
      assetPath: 'assets/3d/hero_wink.gif',
      type: Sa7biHeroChatStickerType.animatedGif,
    ),
    Sa7biHeroChatSticker(
      id: 'gif_blink',
      title: 'رمشة',
      assetPath: 'assets/3d/hero_blink.gif',
      type: Sa7biHeroChatStickerType.animatedGif,
    ),
  ];

  /// These IDs open the bundled GLB in an on-demand full-screen viewer.
  /// No second WebView is kept alive in the message list.
  static const List<Sa7biHeroChatSticker> threeDimensional =
      <Sa7biHeroChatSticker>[
    Sa7biHeroChatSticker(
      id: '3d_hello',
      title: 'تحية ثلاثية الأبعاد',
      assetPath: 'assets/3d/hero_hello(3).gif',
      type: Sa7biHeroChatStickerType.threeDimensional,
      animationName: 'Hero_Welcome',
    ),
    Sa7biHeroChatSticker(
      id: '3d_power',
      title: 'وضع القوة ثلاثي الأبعاد',
      assetPath: 'assets/3d/hero_power(3).gif',
      type: Sa7biHeroChatStickerType.threeDimensional,
      animationName: 'Hero_Power',
    ),
    Sa7biHeroChatSticker(
      id: '3d_idle',
      title: 'وضع الاستعداد ثلاثي الأبعاد',
      assetPath: 'assets/3d/hero_idle(3).gif',
      type: Sa7biHeroChatStickerType.threeDimensional,
      animationName: 'Hero_Idle',
    ),
    Sa7biHeroChatSticker(
      id: '3d_smile',
      title: 'ابتسامة ثلاثية الأبعاد',
      assetPath: 'assets/3d/hero_smile(3).gif',
      type: Sa7biHeroChatStickerType.threeDimensional,
      animationName: 'HERO_FACE_SMILE',
    ),
    Sa7biHeroChatSticker(
      id: '3d_sad',
      title: 'حزن ثلاثي الأبعاد',
      assetPath: 'assets/3d/hero_sad(3).gif',
      type: Sa7biHeroChatStickerType.threeDimensional,
      animationName: 'HERO_FACE_SAD',
    ),
    Sa7biHeroChatSticker(
      id: '3d_surprise',
      title: 'دهشة ثلاثية الأبعاد',
      assetPath: 'assets/3d/hero_surprise.gif',
      type: Sa7biHeroChatStickerType.threeDimensional,
      animationName: 'HERO_FACE_SURPRISE',
    ),
    Sa7biHeroChatSticker(
      id: '3d_angry',
      title: 'غضب ثلاثي الأبعاد',
      assetPath: 'assets/3d/hero_angry(3).gif',
      type: Sa7biHeroChatStickerType.threeDimensional,
      animationName: 'HERO_FACE_ANGRY',
    ),
    Sa7biHeroChatSticker(
      id: '3d_wink',
      title: 'غمزة ثلاثية الأبعاد',
      assetPath: 'assets/3d/hero_wink.gif',
      type: Sa7biHeroChatStickerType.threeDimensional,
      animationName: 'HERO_FACE_WINK',
    ),
    Sa7biHeroChatSticker(
      id: '3d_blink',
      title: 'رمشة ثلاثية الأبعاد',
      assetPath: 'assets/3d/hero_blink.gif',
      type: Sa7biHeroChatStickerType.threeDimensional,
      animationName: 'HERO_FACE_BLINK',
    ),
  ];

  static final List<Sa7biHeroChatSticker> all =
      List<Sa7biHeroChatSticker>.unmodifiable(
    <Sa7biHeroChatSticker>[
      ...animatedGifs,
      ...threeDimensional,
    ],
  );

  static final Map<String, Sa7biHeroChatSticker> byId =
      Map<String, Sa7biHeroChatSticker>.unmodifiable(
    <String, Sa7biHeroChatSticker>{
      for (final sticker in all) sticker.id: sticker,
    },
  );
}
