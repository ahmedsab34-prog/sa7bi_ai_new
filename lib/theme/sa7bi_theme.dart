import 'package:flutter/material.dart';

/// الهوية البصرية الموحدة لتطبيق صاحبي AI.
///
/// الاتجاه المعتمد:
/// - خلفيات كحلية عميقة.
/// - بنفسجي للعناصر الثانوية.
/// - ذهبي للعناصر المميزة.
/// - سماوي/أزرق للتفاعل والاتصال.
///
/// نحافظ على أسماء الثوابت القديمة حتى لا تنكسر
/// الشاشات الحالية التي تعتمد عليها.
abstract final class Sa7biTheme {
  // ============================================================
  // BACKGROUNDS
  // ============================================================

  static const Color background = Color(0xFF060918);
  static const Color backgroundRaised = Color(0xFF0B1022);

  static const Color surface = Color(0xFF111A30);
  static const Color surfaceRaised = Color(0xFF192541);
  static const Color surfaceSoft = Color(0xFF263555);

  static const Color navy = Color(0xFF111C37);
  static const Color navyDeep = Color(0xFF080D1E);
  static const Color black = Color(0xFF03050B);

  // ============================================================
  // BRAND COLORS
  // ============================================================

  static const Color blue = Color(0xFF5799FF);
  static const Color blueBright = Color(0xFF8BBEFF);
  static const Color cyan = Color(0xFF69E2EE);

  static const Color violet = Color(0xFF8C79E6);
  static const Color purple = Color(0xFFB3A2FF);

  static const Color gold = Color(0xFFD9B469);
  static const Color goldBright = Color(0xFFF0D28F);
  static const Color goldDeep = Color(0xFF92703A);

  // أسماء توافقية قديمة مستخدمة داخل المشروع.
  static const Color wine = Color(0xFF772A55);
  static const Color wineDeep = Color(0xFF4C1C3A);
  static const Color burgundy = Color(0xFF6F234B);

  static const Color success = Color(0xFF57D6B1);
  static const Color danger = Color(0xFFFF7188);

  // ============================================================
  // TEXT AND BORDERS
  // ============================================================

  static const Color textPrimary = Color(0xFFF5F5FA);
  static const Color textSecondary = Color(0xFFB5BED2);
  static const Color textMuted = Color(0xFF7D89A3);

  static const Color border = Color(0x334D6594);
  static const Color borderWine = Color(0x667D315C);
  static const Color borderGold = Color(0x668F7444);

  // ============================================================
  // BRAND GRADIENTS
  // ============================================================

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: <Color>[
      blueBright,
      violet,
      gold,
    ],
  );

  static const LinearGradient premiumGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: <Color>[
      Color(0xFF20284A),
      Color(0xFF17152F),
      Color(0xFF30213D),
      Color(0xFF090D1B),
    ],
    stops: <double>[
      0.0,
      0.38,
      0.72,
      1.0,
    ],
  );

  static const LinearGradient darkGlassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFF202B49),
      Color(0xFF151D35),
      Color(0xFF0B1224),
    ],
  );

  static const LinearGradient violetGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: <Color>[
      Color(0xFFAA96FF),
      Color(0xFF6F5BC3),
      Color(0xFF342A68),
    ],
  );

  static const LinearGradient wineGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: <Color>[
      Color(0xFF9B4778),
      Color(0xFF6F2B58),
      Color(0xFF32182E),
    ],
  );

  static const LinearGradient blueGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: <Color>[
      Color(0xFF82B8FF),
      Color(0xFF3B76C7),
      Color(0xFF1A315A),
    ],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: <Color>[
      goldBright,
      gold,
      goldDeep,
    ],
  );

  // ============================================================
  // THEME
  // ============================================================

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: violet,
      brightness: Brightness.dark,
    ).copyWith(
      primary: blueBright,
      secondary: violet,
      tertiary: cyan,
      surface: surface,
      error: danger,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      fontFamily: 'sans',
      dividerColor: border,
      splashColor: blue.withValues(alpha: 0.10),
      highlightColor: cyan.withValues(alpha: 0.04),

      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          fontFamily: 'sans',
        ),
      ),

      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: border),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceRaised,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 13,
        ),
        hintStyle: const TextStyle(
          color: textMuted,
          fontSize: 13,
        ),
        labelStyle: const TextStyle(
          color: textSecondary,
          fontSize: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: gold,
            width: 1.3,
          ),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: blue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: surfaceSoft,
          disabledForegroundColor: textMuted,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(
            horizontal: 17,
            vertical: 11,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: violet,
          foregroundColor: Colors.white,
          disabledBackgroundColor: surfaceSoft,
          disabledForegroundColor: textMuted,
          minimumSize: const Size(0, 44),
          elevation: 2,
          shadowColor: violet.withValues(alpha: 0.22),
          padding: const EdgeInsets.symmetric(
            horizontal: 17,
            vertical: 11,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: goldBright,
          minimumSize: const Size(0, 42),
          padding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 10,
          ),
          side: const BorderSide(color: borderGold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          textStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: blueBright,
          textStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      iconTheme: const IconThemeData(
        color: textSecondary,
        size: 21,
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: cyan,
        linearTrackColor: surfaceSoft,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceRaised,
        contentTextStyle: const TextStyle(
          color: textPrimary,
          fontSize: 12,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: const BorderSide(color: border),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: border),
        ),
        titleTextStyle: const TextStyle(
          color: textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle: const TextStyle(
          color: textSecondary,
          fontSize: 13,
          height: 1.5,
        ),
      ),
    );
  }
}
