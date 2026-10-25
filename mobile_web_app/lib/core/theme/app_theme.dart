import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cafeana Modern Classic color system:
///   Backgrounds → Clean Warm White (#FCFAF8 / #FFFFFF)
///   Primary / Text → Deep Espresso (#2C2420)
///   Accents → Caramel (#C88D5D)
abstract class AppTheme {
  // ── Color Palette ───────────────────────────────────────────────────────────
  static const Color primarySeed = Color(0xFF2C2420); // Deep Espresso
  static const Color accentColor = Color(0xFFC88D5D); // Caramel
  static const Color lightBackground = Color(0xFFFCFAF8); // Clean warm white
  static const Color darkBackground = Color(0xFF120F0D); // Deep dark roast

  // ── Gradient Helpers ────────────────────────────────────────────────────────
  static LinearGradient get primaryGradient => const LinearGradient(
    colors: [Color(0xFF2C2420), Color(0xFF40342E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get accentGradient => const LinearGradient(
    colors: [Color(0xFFC88D5D), Color(0xFFDCA87C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get heroGradientLight => const LinearGradient(
    colors: [Color(0xFFFCFAF8), Color(0xFFF3EBE1), Color(0xFFE8D5C4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get heroGradientDark => const LinearGradient(
    colors: [Color(0xFF120F0D), Color(0xFF241D19), Color(0xFF362B25)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Light Theme ─────────────────────────────────────────────────────────────
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: primarySeed,
      brightness: Brightness.light,
      primary: const Color(0xFF2C2420),          // Deep Espresso
      onPrimary: const Color(0xFFFFFFFF),
      primaryContainer: const Color(0xFFE8D5C4), 
      onPrimaryContainer: const Color(0xFF2C2420),
      secondary: const Color(0xFFC88D5D),        // Caramel
      onSecondary: const Color(0xFFFFFFFF),
      secondaryContainer: const Color(0xFFF3EBE1),
      onSecondaryContainer: const Color(0xFF2C2420),
      tertiary: const Color(0xFFC88D5D),         // Caramel as tertiary/accent
      onTertiary: const Color(0xFFFFFFFF),
      tertiaryContainer: const Color(0xFFE8D5C4),
      onTertiaryContainer: const Color(0xFF2C2420),
      surface: const Color(0xFFFFFFFF),          // Pure white cards/dialogs
      onSurface: const Color(0xFF1F1814),
      surfaceContainerHighest: const Color(0xFFF0EBE6),
      onSurfaceVariant: const Color(0xFF5E544D),
      outline: const Color(0xFFB0A7A0),
      outlineVariant: const Color(0xFFD6CFC9),
      error: const Color(0xFFBA1A1A),
    );
    return _build(
      scheme.copyWith(
        surfaceContainerHighest: const Color(0xFFEBE3DB),
        surfaceContainerHigh:    const Color(0xFFF0EBE6),
        surfaceContainer:        const Color(0xFFF5F1EE),
        surfaceContainerLow:     const Color(0xFFFAF8F5),
        surfaceContainerLowest:  const Color(0xFFFFFFFF),
      ),
      Brightness.light,
    );
  }

  // ── Dark Theme ──────────────────────────────────────────────────────────────
  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: primarySeed,
      brightness: Brightness.dark,
      primary: const Color(0xFFE8D5C4),           // Light caramel/latte for dark mode text
      onPrimary: const Color(0xFF2C2420),
      primaryContainer: const Color(0xFF40342E),
      onPrimaryContainer: const Color(0xFFE8D5C4),
      secondary: const Color(0xFFDCA87C),
      onSecondary: const Color(0xFF361E0A),
      secondaryContainer: const Color(0xFF5C3A1D),
      onSecondaryContainer: const Color(0xFFF5D8C0),
      tertiary: const Color(0xFFDCA87C),
      onTertiary: const Color(0xFF361E0A),
      tertiaryContainer: const Color(0xFF5C3A1D),
      onTertiaryContainer: const Color(0xFFF5D8C0),
      surface: const Color(0xFF1A1614),
      onSurface: const Color(0xFFEBE3DB),
      surfaceContainerHighest: const Color(0xFF3B332E),
      onSurfaceVariant: const Color(0xFFCFC4BC),
      outline: const Color(0xFF8C8077),
      outlineVariant: const Color(0xFF544A44),
      error: const Color(0xFFFFB4AB),
    );
    return _build(
      scheme.copyWith(
        surfaceContainerHighest: const Color(0xFF3B332E),
        surfaceContainerHigh:    const Color(0xFF302A25),
        surfaceContainer:        const Color(0xFF241D19),
        surfaceContainerLow:     const Color(0xFF1A1614),
        surfaceContainerLowest:  const Color(0xFF120F0D),
      ),
      Brightness.dark,
    );
  }

  // ── Shared Builder ──────────────────────────────────────────────────────────
  static ThemeData _build(ColorScheme scheme, Brightness brightness) {
    final baseTextTheme = brightness == Brightness.light
        ? ThemeData.light().textTheme
        : ThemeData.dark().textTheme;

    final textTheme = GoogleFonts.loraTextTheme(baseTextTheme);

    return ThemeData(
      colorScheme: scheme,
      textTheme: textTheme,
      useMaterial3: true,
      scaffoldBackgroundColor: Colors.transparent,

      // ── App Bar
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: brightness == Brightness.light
            ? const Color(0xFF2C2420)   // espresso on light gradient
            : const Color(0xFFEBE3DB),  // warm latte on dark gradient
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        iconTheme: IconThemeData(
          color: brightness == Brightness.light
              ? const Color(0xFF2C2420)
              : const Color(0xFFDCA87C), // caramel icons on dark
          size: 24,
        ),
        actionsIconTheme: IconThemeData(
          color: brightness == Brightness.light
              ? const Color(0xFF2C2420)
              : const Color(0xFFDCA87C),
          size: 24,
        ),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          fontSize: 22,
          letterSpacing: -0.8,
          color: brightness == Brightness.light
              ? const Color(0xFF2C2420)   // deep espresso title
              : const Color(0xFFEBE3DB),  // warm latte title
        ),
        // Subtle caramel bottom border — visually connects header to gradient
        shape: Border(
          bottom: BorderSide(
            color: brightness == Brightness.light
                ? const Color(0xFFC88D5D).withValues(alpha: 0.28)  // caramel line on light
                : const Color(0xFFDCA87C).withValues(alpha: 0.20), // caramel on dark
            width: 1,
          ),
        ),
      ),

      // ── Tab Bar
      tabBarTheme: TabBarThemeData(
        labelColor: brightness == Brightness.light
            ? const Color(0xFF2C2420)    // espresso selected tab
            : const Color(0xFFDCA87C),  // caramel selected tab in dark
        unselectedLabelColor: brightness == Brightness.light
            ? const Color(0xFF5E544D)   // warm muted brown
            : const Color(0xFF8C7B72),  // muted warm grey
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        indicatorColor: brightness == Brightness.light
            ? const Color(0xFFC88D5D)   // caramel indicator line
            : const Color(0xFFDCA87C),
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: brightness == Brightness.light
            ? const Color(0xFFC88D5D).withValues(alpha: 0.20)
            : const Color(0xFFDCA87C).withValues(alpha: 0.15),
      ),


      cardTheme: CardThemeData(
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        color: scheme.surface,
      ),

      // ── Buttons
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,     // Deep Espresso
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(64, 54),
          shape: const StadiumBorder(),
          textStyle: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
          elevation: 0,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary, // Deep Espresso
          minimumSize: const Size(64, 54),
          shape: const StadiumBorder(),
          textStyle: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          side: BorderSide(color: scheme.primary.withValues(alpha: 0.5), width: 1.5),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary, // Deep Espresso
          shape: const StadiumBorder(),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      // ── Inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh.withValues(alpha: 0.7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 2), // Espresso focus ring
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
        prefixIconColor: scheme.onSurfaceVariant.withValues(alpha: 0.7),
      ),

      // ── Navigation Bar (Bottom)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: brightness == Brightness.light
            ? const Color(0xFFC88D5D).withValues(alpha: 0.18)
            : const Color(0xFF2C2420).withValues(alpha: 0.72),
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.18),
        elevation: 0,
        height: 68,
        indicatorColor: brightness == Brightness.light
            ? const Color(0xFF2C2420).withValues(alpha: 0.12)
            : const Color(0xFFDCA87C).withValues(alpha: 0.20),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(
              color: brightness == Brightness.light
                  ? const Color(0xFF2C2420)
                  : const Color(0xFFDCA87C),
              size: 24,
            );
          }
          return IconThemeData(
            color: brightness == Brightness.light
                ? const Color(0xFF5E544D)
                : const Color(0xFFCFC4BC),
            size: 22,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: brightness == Brightness.light
                  ? const Color(0xFF2C2420)
                  : const Color(0xFFDCA87C),
            );
          }
          return textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w500,
            color: brightness == Brightness.light
                ? const Color(0xFF5E544D)
                : const Color(0xFFCFC4BC),
          );
        }),
      ),

      // ── Navigation Rail (Side)
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: brightness == Brightness.light
            ? const Color(0xFFC88D5D).withValues(alpha: 0.10)
            : const Color(0xFF2C2420).withValues(alpha: 0.65),
        elevation: 0,
        indicatorColor: brightness == Brightness.light
            ? const Color(0xFF2C2420).withValues(alpha: 0.10)
            : const Color(0xFFDCA87C).withValues(alpha: 0.18),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        selectedIconTheme: IconThemeData(
          color: brightness == Brightness.light
              ? const Color(0xFF2C2420)
              : const Color(0xFFDCA87C),
          size: 24,
        ),
        unselectedIconTheme: IconThemeData(
          color: brightness == Brightness.light
              ? const Color(0xFF5E544D)
              : const Color(0xFFCFC4BC),
          size: 22,
        ),
        selectedLabelTextStyle: textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: brightness == Brightness.light
              ? const Color(0xFF2C2420)
              : const Color(0xFFDCA87C),
        ),
        unselectedLabelTextStyle: textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w500,
          color: brightness == Brightness.light
              ? const Color(0xFF5E544D)
              : const Color(0xFFCFC4BC),
        ),
        useIndicator: true,
        minWidth: 72,
      ),

      // ── Floating Action Button
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 4,
        shape: const StadiumBorder(),
        backgroundColor: scheme.primary,   // Espresso
        foregroundColor: scheme.onPrimary,
      ),

      // ── Chips
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide.none,
        backgroundColor: scheme.surfaceContainerHighest,
        selectedColor: scheme.secondaryContainer,
        labelStyle: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600, color: scheme.onSurface),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),

      // ── Divider
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.4),
        thickness: 1,
        space: 1,
      ),

      // ── List Tile
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}
