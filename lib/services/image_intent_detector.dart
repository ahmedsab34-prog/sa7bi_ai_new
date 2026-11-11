
/// يميز طلب إنشاء صورة جديدًا عن طلبات وصف الصور أو تعديل صورة مرفقة.
/// يعتمد على أوامر إنشاء واضحة حتى لا يحوّل أسئلة المستخدم العادية إلى توليد مدفوع.
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
        .replaceAll(RegExp(r'[،,.!؟?؛;]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static bool isGenerationRequest(String input) {
    final text = _normalize(input);
    if (text.isEmpty) return false;

    // الأوامر العربية الصريحة لإنشاء صورة أو تصميم جديد.
    const arabicCreationPhrases = <String>[
      'انشئ صوره',
      'انشئلي صوره',
      'انشئ لي صوره',
      'انشاء صوره',
      'اعمل صوره',
      'اعملي صوره',
      'اعمللي صوره',
      'اعمل لي صوره',
      'ممكن تعمل صوره',
      'ممكن تعملي صوره',
      'ممكن تعمللي صوره',
      'ممكن تعمل لي صوره',
      'عايز صوره',
      'عاوز صوره',
      'محتاج صوره',
      'اريد صوره',
      'نفسي في صوره',
      'صمم صوره',
      'صمملي صوره',
      'صمم لي صوره',
      'ارسم صوره',
      'ارسملي صوره',
      'ارسم لي صوره',
      'ولد صوره',
      'ولدلي صوره',
      'توليد صوره',
      'اعمل تصميم',
      'اعملي تصميم',
      'اعمللي تصميم',
      'ممكن تعمل تصميم',
      'محتاج تصميم',
      'عايز تصميم',
      'عاوز تصميم',
      'صمملي',
      'صمم لي',
      'ارسملي',
      'ارسم لي',
      'انشئلي',
      'انشئ لي',
      'اعمل لوجو',
      'اعملي لوجو',
      'صمم لوجو',
      'صمملي لوجو',
      'اعمل شعار',
      'صمم شعار',
      'اعمل بوستر',
      'صمم بوستر',
      'اعمل خلفيه',
      'صمم خلفيه',
      'اعمل غلاف',
      'صمم غلاف',
      'صوره بالذكاء الاصطناعي',
      'صوره ai',
    ];

    const englishCreationPhrases = <String>[
      'generate an image',
      'generate image',
      'create an image',
      'create image',
      'draw an image',
      'make an image',
      'generate a picture',
      'create a picture',
      'make a picture',
      'design an image',
      'create a logo',
      'make a logo',
      'generate a logo',
      'create a poster',
      'make a poster',
      'create a wallpaper',
      'make a wallpaper',
      'generate artwork',
      'create artwork',
      'i need an image of',
      'i want an image of',
      'i need a picture of',
      'i want a picture of',
      'make me an image',
      'draw me a',
    ];

    final hasExplicitCreation =
        arabicCreationPhrases.any(text.contains) ||
            englishCreationPhrases.any(text.contains);

    if (hasExplicitCreation) return true;

    // طلبات الوصف والتحليل والقراءة ليست أوامر لإنشاء صورة جديدة.
    const analysisOrEditingPhrases = <String>[
      'حلل الصوره',
      'حلللي الصوره',
      'اشرح الصوره',
      'اشرحلي الصوره',
      'صف الصوره',
      'اوصف الصوره',
      'اقرا الصوره',
      'اقرا النص في الصوره',
      'الصوره دي فيها ايه',
      'ايه اللي في الصوره',
      'ماذا في الصوره',
      'ما الموجود في الصوره',
      'هل الصوره واضحه',
      'فهمني الصوره',
      'فسر الصوره',
      'عايز اعدل الصوره',
      'عاوز اعدل الصوره',
      'اريد تعديل الصوره',
      'عدل الصوره',
      'تعديل الصوره الموجوده',
      'i need a description of this image',
      'i want a description of this image',
      'describe this image',
      'analyze this image',
      'what is in this image',
      'read the text in this image',
      'explain this picture',
      'edit this image',
      'change this image',
    ];

    if (analysisOrEditingPhrases.any(text.contains)) return false;

    // لا نستخدم "عايز/محتاج/need/want" وحدها كإشارة إنشاء؛
    // يلزم معها فعل إنشاء فعلي أو صيغة إنجليزية واضحة أعلاه.
    const arabicActions = <String>[
      'صمم',
      'صمملي',
      'صمم لي',
      'ارسم',
      'ارسملي',
      'ارسم لي',
      'انشئ',
      'انشئلي',
      'انشئ لي',
      'ولد',
      'ولدلي',
      'اعمل',
      'اعملي',
      'اعمللي',
      'اعمل لي',
      'ممكن تعمل',
      'سوي',
      'سويلي',
      'سوي لي',
    ];

    const arabicObjects = <String>[
      'صوره',
      'تصميم',
      'لوجو',
      'شعار',
      'بوستر',
      'ملصق',
      'خلفيه',
      'غلاف',
      'رسمه',
      'ايقونه',
      'بانر',
      'صوره مصغره',
    ];

    final hasArabicAction = arabicActions.any(text.contains);
    final hasArabicObject = arabicObjects.any(text.contains);

    if (hasArabicAction && hasArabicObject) return true;

    const englishActions = <String>[
      'create',
      'generate',
      'draw',
      'design',
      'make',
      'render',
      'illustrate',
    ];

    const englishObjects = <String>[
      'logo',
      'poster',
      'wallpaper',
      'illustration',
      'image',
      'picture',
      'artwork',
      'banner',
      'cover',
      'thumbnail',
      'avatar',
      'icon',
      'design',
    ];

    return englishActions.any(text.contains) &&
        englishObjects.any(text.contains);
  }
}
