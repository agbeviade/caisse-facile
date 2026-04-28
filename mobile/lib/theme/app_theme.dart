import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized theme builder. Uses Inter (Google Fonts) and Material 3.
/// Palette “Clean & Trust”:
///  - Emerald  #2ECC71 → primary (growth, fresh produce, success)
///  - Navy     #2C3E50 → AppBar / strong text (trust, money management)
///  - Off-white #F8F9FA → scaffold background (less aggressive than pure white)
///  - Amber    #F1C40F → stock-low / near-expiry warnings
///  - Red      #E74C3C → critical errors / out of stock
class AppTheme {
  static const seed = Color(0xFF2ECC71);
  static const navy = Color(0xFF2C3E50);
  static const navySoft = Color(0xFF34495E);
  static const offWhite = Color(0xFFF8F9FA);
  static const amber = Color(0xFFF1C40F);
  static const danger = Color(0xFFE74C3C);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      error: danger,
    );
    final base = brightness == Brightness.light
        ? ThemeData.light(useMaterial3: true)
        : ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor:
          brightness == Brightness.light ? offWhite : const Color(0xFF0B0E0C),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        titleLarge: GoogleFonts.inter(
            textStyle: base.textTheme.titleLarge,
            fontWeight: FontWeight.w700),
        titleMedium: GoogleFonts.inter(
            textStyle: base.textTheme.titleMedium,
            fontWeight: FontWeight.w600),
        labelLarge: GoogleFonts.inter(
            textStyle: base.textTheme.labelLarge,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: brightness == Brightness.light
            ? navy
            : const Color(0xFF111418),
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 19,
          fontWeight: FontWeight.w700,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 6,
        shape: const StadiumBorder(),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          textStyle: GoogleFonts.inter(
              fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          textStyle:
              GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.08),
        surfaceTintColor: Colors.transparent,
        color: brightness == Brightness.light
            ? Colors.white
            : const Color(0xFF161A18),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        side: BorderSide(color: scheme.outlineVariant.withOpacity(0.6)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brightness == Brightness.light
            ? Colors.white
            : const Color(0xFF161A18),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: scheme.outlineVariant.withOpacity(0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: scheme.outlineVariant.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: _SharedAxisBuilder(),
        TargetPlatform.iOS: _SharedAxisBuilder(),
      }),
      splashFactory: InkSparkle.splashFactory,
    );
  }
}

/// Adapter that lets us use the official Material `SharedAxisTransition`
/// (from the `animations` package) inside a `PageTransitionsTheme`.
/// The `animations` package itself does not ship such a builder, so we write
/// the thin wrapper here.
class _SharedAxisBuilder extends PageTransitionsBuilder {
  const _SharedAxisBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SharedAxisTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      transitionType: SharedAxisTransitionType.horizontal,
      fillColor: Theme.of(context).scaffoldBackgroundColor,
      child: child,
    );
  }
}

