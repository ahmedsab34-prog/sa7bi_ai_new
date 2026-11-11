
/// يميز طلب إنشاء أو تعديل صورة صريحًا عن السؤال النصي العادي.
/// يدعم الصياغات المصرية والعربية والإنجليزية.
///
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
        .replaceAll(
          RegExp(r'[،,.!؟?؛;]+'),
          ' ',
        )
        .replaceAll(
          RegExp(r'\s+'),
          ' ',
        )
        .trim();
  }

  static bool isGenerationRequest(String input) {
    final text = _normalize(input);

    if (text.isEmpty) return false;

    // ----------------------------------------------------------
    // EXPLICIT ARABIC IMAGE CREATION REQUESTS
    // ----------------------------------------------------------

    const explicitArabicPhrases = <String>[
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
      'محتاج اعمل صوره',
      'نفسي في صوره',
      'اريد صوره',
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
      'صوره بالذكاء الاصطناعي',
      'صوره ai',
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
    ];

    if (explicitArabicPhrases.any(text.contains)) {
      return true;
    }

    // ----------------------------------------------------------
    // EXPLICIT ENGLISH IMAGE CREATION REQUESTS
    // ----------------------------------------------------------

    const explicitEnglishPhrases = <String>[
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
      'ai image',
      'ai picture',
    ];

    if (explicitEnglishPhrases.any(text.contains)) {
      return true;
    }

    // ----------------------------------------------------------
    // AVOID MISCLASSIFYING IMAGE ANALYSIS
    // ----------------------------------------------------------

    const analysisPhrases = <String>[
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
      'analyze this image',
      'describe this image',
      'what is in this image',
      'read the text in this image',
      'explain this picture',
    ];

    final isAnalysisOnly =
        analysisPhrases.any(text.contains);

    if (isAnalysisOnly) {
      // التحليل لا يصبح إنشاء إلا لو كتب المستخدم
      // أمر إنشاء صريحًا آخر داخل نفس الرسالة.
      const creationVerbs = <String>[
        'انشئ',
        'اعمل',
        'اعملي',
        'اعمللي',
        'صمم',
        'ارسم',
        'ولد',
        'create',
        'generate',
        'draw',
        'design',
        'make',
      ];

      final alsoRequestsCreation =
          creationVerbs.any(text.contains);

      if (!alsoRequestsCreation) {
        return false;
      }
    }

    // ----------------------------------------------------------
    // GENERAL ARABIC DESIGN INTENT
    // ----------------------------------------------------------

    const arabicDesignObjects = <String>[
      'صوره',
      'صورة',
      'تصميم',
      'لوجو',
      'شعار',
      'بوستر',
      'ملصق',
      'خلفيه',
      'خلفية',
      'غلاف',
      'رسمه',
      'رسمية',
      'ايقونه',
      'أيقونة',
      'بانر',
      'صوره مصغره',
      'صورة مصغرة',
    ];

    const arabicCreationVerbs = <String>[
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
      'عايز',
      'عاوز',
      'محتاج',
      'اريد',
      'نفسي',
      'سوي',
      'سويلي',
      'سوي لي',
    ];

    final hasArabicDesignObject =
        arabicDesignObjects.any(text.contains);

    final hasArabicCreationVerb =
        arabicCreationVerbs.any(text.contains);

    if (hasArabicDesignObject &&
        hasArabicCreationVerb) {
      return true;
    }

    // ----------------------------------------------------------
    // GENERAL ENGLISH DESIGN INTENT
    // ----------------------------------------------------------

    const englishDesignObjects = <String>[
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

    const englishCreationVerbs = <String>[
      'create',
      'generate',
      'draw',
      'design',
      'make',
      'render',
      'illustrate',
      'need',
      'want',
    ];

    final hasEnglishObject =
        englishDesignObjects.any(text.contains);

    final hasEnglishCreationVerb =
        englishCreationVerbs.any(text.contains);

    return hasEnglishObject && hasEnglishCreationVerb;
  }
}
