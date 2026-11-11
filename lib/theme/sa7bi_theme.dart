
import 'package:flutter/material.dart';

/// الهوية البصرية الموحدة لتطبيق صاحبي AI.
/// كحلي وأسود ونبيتي مع أزرق مضيء ولمسات سماوية.
abstract final class Sa7biTheme {
  // ============================================================
  // BASE COLORS
  // ============================================================

  static const Color background = Color(0xFF050812);
  static const Color backgroundRaised = Color(0xFF090F1D);

  static const Color surface = Color(0xFF0D1525);
  static const Color surfaceRaised = Color(0xFF142039);
  static const Color surfaceSoft = Color(0xFF1C2A45);

  static const Color navy = Color(0xFF101C35);
  static const Color navyDeep = Color(0xFF080E1C);
  static const Color black = Color(0xFF03050A);

  // ============================================================
  // BRAND COLORS
  // ============================================================

  static const Color blue = Color(0xFF4B8DFF);
  static const Color blueBright = Color(0xFF67B7FF);
  static const Color cyan = Color(0xFF66D9F2);

  static const Color wine = Color(0xFF8F2147);
  static const Color wineDeep = Color(0xFF52132E);
  static const Color burgundy = Color(0xFF6D1738);

  static const Color violet = Color(0xFF9A83D9);
  static const Color purple = Color(0xFFB39DFF);

  // أسماء التوافق القديمة تظل متاحة.
  static const Color gold = wine;
  static const Color success = Color(0xFF57D6B1);
  static const Color danger = Color(0xFFFF6F83);

  // ============================================================
  // TEXT AND BORDERS
  // ============================================================

  static const Color textPrimary = Color(0xFFF5F7FC);
  static const Color textSecondary = Color(0xFFA7B3C9);
  static const Color textMuted = Color(0xFF73829D);

  static const Color border = Color(0x334D6B9B);
  static const Color borderWine = Color(0x667D2449);

  // ============================================================
  // BRAND GRADIENTS
  // ============================================================

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: <Color>[
      blueBright,
      blue,
      wine,
    ],
  );

  static const LinearGradient premiumGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: <Color>[
      Color(0xFF1C3154),
      Color(0xFF111A31),
      Color(0xFF321326),
      Color(0xFF090D18),
    ],
    stops: <double>[
      0.0,
      0.42,
      0.76,
      1.0,
    ],
  );

  static const LinearGradient darkGlassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFF1C2942),
      Color(0xFF111B2D),
      Color(0xFF090F1C),
    ],
  );

  static const LinearGradient wineGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: <Color>[
      Color(0xFF9D2B54),
      Color(0xFF6F1B3B),
      Color(0xFF321222),
    ],
  );

  static const LinearGradient blueGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: <Color>[
      Color(0xFF5DABFF),
      Color(0xFF2861B7),
      Color(0xFF142C55),
    ],
  );

  // اسم قديم مستخدم في بعض الواجهات.
  static const LinearGradient goldGradient = wineGradient;

  // ============================================================
  // THEME
  // ============================================================

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: blue,
      brightness: Brightness.dark,
    ).copyWith(
      primary: blueBright,
      secondary: wine,
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

      splashColor: blue.withValues(alpha: 0.09),
      highlightColor: cyan.withValues(alpha: 0.035),

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
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: border),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceRaised,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        hintStyle: const TextStyle(
          color: textSecondary,
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
            color: blueBright,
            width: 1.4,
          ),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: blue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: surfaceSoft,
          disabledForegroundColor: textSecondary,
          minimumSize: const Size(0, 42),
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: wine,
          foregroundColor: Colors.white,
          disabledBackgroundColor: surfaceSoft,
          disabledForegroundColor: textSecondary,
          minimumSize: const Size(0, 42),
          elevation: 3,
          shadowColor: wine.withValues(alpha: 0.25),
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: blueBright,
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 9,
          ),
          side: const BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
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
        color: blueBright,
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
          borderRadius: BorderRadius.circular(14),
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
