import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cyber Retro Theme System for AgentsCouncil
/// Features: Vaporwave aesthetics, neon glows, glassmorphism, comfortable readability

// ============================================================================
// THEME VARIANTS
// ============================================================================

enum CyberThemeVariant { midnight, neon, sunset }

// ============================================================================
// COLOR PALETTE
// ============================================================================

class CyberColors {
  // Primary Neon Colors
  static const Color neonCyan = Color(0xFF00F5FF);
  static const Color electricPink = Color(0xFFFF2D95);
  static const Color holoPurple = Color(0xFFBD00FF);
  static const Color neonGreen = Color(0xFF05FFA1);
  static const Color warningAmber = Color(0xFFFFB800);
  static const Color errorRed = Color(0xFFFF3B5C);
  static const Color successGreen = Color(0xFF00D68F);
  static const Color neonBlue = neonCyan; // Alias for compatibility

  // Background Colors (Midnight Theme)
  static const Color midnightBg = Color(0xFF0A0A12);
  static const Color midnightSurface = Color(0xFF12121F);
  static const Color midnightCard = Color(0xFF1A1A2E);
  static const Color midnightBorder = Color(0xFF2A2A45);

  // Background Colors (Neon Theme)
  static const Color neonBg = Color(0xFF0D0D1A);
  static const Color neonSurface = Color(0xFF151528);
  static const Color neonCard = Color(0xFF1E1E38);
  static const Color neonBorder = Color(0xFF3D3D6B);

  // Background Colors (Sunset Theme)
  static const Color sunsetBg = Color(0xFF120A18);
  static const Color sunsetSurface = Color(0xFF1A1020);
  static const Color sunsetCard = Color(0xFF251830);
  static const Color sunsetBorder = Color(0xFF3D2850);

  // Text Colors
  static const Color textPrimary = Color(0xFFF0F0F5);
  static const Color textSecondary = Color(0xFFB8B8CC);
  static const Color textMuted = Color(0xFF6B6B85);

  // Provider Colors
  static const Color openaiGreen = Color(0xFF10A37F);
  static const Color anthropicOrange = Color(0xFFD4A574);
  static const Color geminiBlue = Color(0xFF4285F4);
  static const Color ollamaYellow = Color(0xFFF4D03F);
  
  // Compat Aliases
  static const Color surfaceDb = midnightSurface;
  static const Color glassBorder = midnightBorder;
}

// ============================================================================
// GLOW EFFECTS
// ============================================================================

class CyberGlow {
  static List<BoxShadow> soft(Color color) => [
    BoxShadow(color: color.withOpacity(0.3), blurRadius: 12, spreadRadius: 0),
    BoxShadow(color: color.withOpacity(0.1), blurRadius: 24, spreadRadius: 0),
  ];

  static List<BoxShadow> medium(Color color) => [
    BoxShadow(color: color.withOpacity(0.4), blurRadius: 16, spreadRadius: 2),
    BoxShadow(color: color.withOpacity(0.2), blurRadius: 32, spreadRadius: 0),
  ];

  static List<BoxShadow> intense(Color color) => [
    BoxShadow(color: color.withOpacity(0.6), blurRadius: 20, spreadRadius: 4),
    BoxShadow(color: color.withOpacity(0.3), blurRadius: 40, spreadRadius: 0),
  ];

  static List<Shadow> text(Color color) => [
    Shadow(color: color.withOpacity(0.8), blurRadius: 8),
    Shadow(color: color.withOpacity(0.4), blurRadius: 16),
  ];
}

// ============================================================================
// GRADIENTS
// ============================================================================

class CyberGradients {
  static const LinearGradient primary = LinearGradient(
    colors: [CyberColors.neonCyan, CyberColors.holoPurple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accent = LinearGradient(
    colors: [CyberColors.electricPink, CyberColors.holoPurple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient success = LinearGradient(
    colors: [CyberColors.neonGreen, CyberColors.neonCyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient glass(Color baseColor) => LinearGradient(
    colors: [
      baseColor.withOpacity(0.15),
      baseColor.withOpacity(0.05),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient scanline = LinearGradient(
    colors: [
      Colors.transparent,
      Color(0x08FFFFFF),
      Colors.transparent,
    ],
    stops: [0.0, 0.5, 1.0],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

// ============================================================================
// THEME DATA
// ============================================================================

class CyberTheme {
  static ThemeData get midnight => _buildTheme(
    bg: CyberColors.midnightBg,
    surface: CyberColors.midnightSurface,
    card: CyberColors.midnightCard,
    border: CyberColors.midnightBorder,
    primary: CyberColors.neonCyan,
    secondary: CyberColors.holoPurple,
  );

  static ThemeData get neon => _buildTheme(
    bg: CyberColors.neonBg,
    surface: CyberColors.neonSurface,
    card: CyberColors.neonCard,
    border: CyberColors.neonBorder,
    primary: CyberColors.electricPink,
    secondary: CyberColors.neonCyan,
  );

  static ThemeData get sunset => _buildTheme(
    bg: CyberColors.sunsetBg,
    surface: CyberColors.sunsetSurface,
    card: CyberColors.sunsetCard,
    border: CyberColors.sunsetBorder,
    primary: CyberColors.electricPink,
    secondary: CyberColors.holoPurple,
  );

  static ThemeData forVariant(CyberThemeVariant variant) {
    switch (variant) {
      case CyberThemeVariant.midnight:
        return midnight;
      case CyberThemeVariant.neon:
        return neon;
      case CyberThemeVariant.sunset:
        return sunset;
    }
  }

  static ThemeData _buildTheme({
    required Color bg,
    required Color surface,
    required Color card,
    required Color border,
    required Color primary,
    required Color secondary,
  }) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: surface,
        error: CyberColors.errorRed,
        onPrimary: CyberColors.textPrimary,
        onSecondary: CyberColors.textPrimary,
        onSurface: CyberColors.textPrimary,
      ),
      textTheme: _buildTextTheme(primary),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border.withOpacity(0.6)),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: bg,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.spaceGrotesk(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          side: BorderSide(color: primary.withOpacity(0.5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.spaceGrotesk(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: CyberColors.errorRed),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        hintStyle: GoogleFonts.dmSans(
          color: CyberColors.textMuted,
          fontSize: 15,
        ),
        labelStyle: GoogleFonts.dmSans(
          color: CyberColors.textSecondary,
          fontSize: 14,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.spaceGrotesk(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: CyberColors.textPrimary,
          letterSpacing: 0.5,
        ),
        iconTheme: IconThemeData(color: primary),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: bg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: primary.withOpacity(0.2),
        labelStyle: GoogleFonts.dmSans(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        side: BorderSide(color: border.withOpacity(0.5)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      dividerTheme: DividerThemeData(
        color: border.withOpacity(0.4),
        thickness: 1,
        space: 24,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primary,
        inactiveTrackColor: border,
        thumbColor: primary,
        overlayColor: primary.withOpacity(0.2),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: border.withOpacity(0.6)),
        ),
        titleTextStyle: GoogleFonts.spaceGrotesk(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: CyberColors.textPrimary,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: card,
        contentTextStyle: GoogleFonts.dmSans(
          color: CyberColors.textPrimary,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        circularTrackColor: border.withOpacity(0.3),
      ),
    );
  }

  static TextTheme _buildTextTheme(Color accent) {
    return TextTheme(
      // Display styles - Space Grotesk for headings
      displayLarge: GoogleFonts.spaceGrotesk(
        fontSize: 40,
        fontWeight: FontWeight.bold,
        color: CyberColors.textPrimary,
        letterSpacing: -1,
        height: 1.2,
      ),
      displayMedium: GoogleFonts.spaceGrotesk(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: CyberColors.textPrimary,
        letterSpacing: -0.5,
        height: 1.2,
      ),
      displaySmall: GoogleFonts.spaceGrotesk(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: CyberColors.textPrimary,
        letterSpacing: -0.25,
        height: 1.3,
      ),
      // Headline styles
      headlineLarge: GoogleFonts.spaceGrotesk(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: CyberColors.textPrimary,
        letterSpacing: 0,
        height: 1.3,
      ),
      headlineMedium: GoogleFonts.spaceGrotesk(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: CyberColors.textPrimary,
        height: 1.4,
      ),
      headlineSmall: GoogleFonts.spaceGrotesk(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: CyberColors.textPrimary,
        height: 1.4,
      ),
      // Title styles
      titleLarge: GoogleFonts.spaceGrotesk(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: CyberColors.textPrimary,
        height: 1.4,
      ),
      titleMedium: GoogleFonts.dmSans(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: CyberColors.textPrimary,
        height: 1.4,
      ),
      titleSmall: GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: CyberColors.textPrimary,
        height: 1.4,
      ),
      // Body styles - DM Sans for readability
      bodyLarge: GoogleFonts.dmSans(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: CyberColors.textPrimary,
        height: 1.6,
        letterSpacing: 0.15,
      ),
      bodyMedium: GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: CyberColors.textSecondary,
        height: 1.6,
        letterSpacing: 0.1,
      ),
      bodySmall: GoogleFonts.dmSans(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: CyberColors.textMuted,
        height: 1.5,
      ),
      // Label styles
      labelLarge: GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: CyberColors.textPrimary,
        letterSpacing: 0.5,
      ),
      labelMedium: GoogleFonts.dmSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: CyberColors.textSecondary,
        letterSpacing: 0.4,
      ),
      labelSmall: GoogleFonts.dmSans(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: CyberColors.textMuted,
        letterSpacing: 0.3,
      ),
    );
  }
}

// ============================================================================
// ANIMATION PRESETS
// ============================================================================

class CyberAnimations {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration emphasis = Duration(milliseconds: 600);

  static const Curve defaultCurve = Curves.easeOutCubic;
  static const Curve bounceCurve = Curves.elasticOut;
  static const Curve smoothCurve = Curves.easeInOutCubic;
}

// ============================================================================
// SPACING & SIZING
// ============================================================================

class CyberSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  static const EdgeInsets pagePadding = EdgeInsets.all(24);
  static const EdgeInsets cardPadding = EdgeInsets.all(20);
  static const EdgeInsets sectionPadding = EdgeInsets.symmetric(vertical: 32);
}

// ============================================================================
// LEGACY SUPPORT - Keep old AppTheme for backward compatibility
// ============================================================================

/// @deprecated Use CyberTheme instead
class AppTheme {
  static Color get primary => CyberColors.neonCyan;
  static Color get secondary => CyberColors.holoPurple;
  static Color get accent => CyberColors.electricPink;
  static Color get success => CyberColors.successGreen;
  static Color get warning => CyberColors.warningAmber;
  static Color get error => CyberColors.errorRed;
  
  static Color get darkBg => CyberColors.midnightBg;
  static Color get darkSurface => CyberColors.midnightSurface;
  static Color get darkCard => CyberColors.midnightCard;
  static Color get darkBorder => CyberColors.midnightBorder;

  static LinearGradient get primaryGradient => CyberGradients.primary;
  static LinearGradient get cardGradient => CyberGradients.glass(CyberColors.neonCyan);

  static ThemeData get darkTheme => CyberTheme.midnight;
}
