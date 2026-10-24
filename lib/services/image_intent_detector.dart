
/// يميز طلب إنشاء صورة صريحًا عن السؤال النصي العادي.
/// لا يستخدم كلمة "صورة" وحدها لاتخاذ قرار إنشاء صورة.
class ImageIntentDetector {
  ImageIntentDetector._();

  static String _normalize(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  static bool isGenerationRequest(String input) {
    final text = _normalize(input);

    if (text.isEmpty) return false;

    // صياغات واضحة لإنشاء أو رسم صورة.
    const explicitPhrases = <String>[
      'انشئ صوره',
      'انشئلي صوره',
      'اعمل صوره',
      'اعملي صوره',
      'اعمللي صوره',
      'صمم صوره',
      'صمملي صوره',
      'ارسم صوره',
      'ولد صوره',
      'توليد صوره',
      'انشاء صوره',
      'generate an image',
      'generate image',
      'create an image',
      'create image',
      'draw an image',
      'make an image',
      'generate a picture',
      'create a picture',
      'make a picture',
    ];

    if (explicitPhrases.any(text.contains)) {
      return true;
    }

    // أوامر تصميم شائعة بشرط وجود فعل واضح وموضوع التصميم.
    final hasDesignObject = <String>[
      'لوجو',
      'شعار',
      'بوستر',
      'ملصق',
      'خلفيه',
      'تصميم',
      'رسمه',
      'صوره',
      'logo',
      'poster',
      'wallpaper',
      'illustration',
      'image',
      'picture',
    ].any(text.contains);

    final hasCreationVerb = <String>[
      'صمم',
      'صمملي',
      'ارسم',
      'ارسملي',
      'انشئ',
      'انشئلي',
      'ولد',
      'اعمل',
      'اعملي',
      'اعمللي',
      'create',
      'generate',
      'draw',
      'design',
      'make',
    ].any(text.contains);

    return hasDesignObject && hasCreationVerb;
  }
}
