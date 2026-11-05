import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Accent themes the user can pick in Settings. Each has a light and a dark shade.
enum AccentTheme {
  indigo('Indigo', Color(0xFF4F5BD5), Color(0xFF8B93F5)),
  forest('Forest', Color(0xFF2F7D5B), Color(0xFF5CC08E)),
  ember('Ember', Color(0xFFC2541B), Color(0xFFF08A4B)),
  graphite('Graphite', Color(0xFF27272A), Color(0xFFE4E4E7));

  const AccentTheme(this.label, this.light, this.dark);
  final String label;
  final Color light;
  final Color dark;
}

/// Tokens the ColorScheme has no slot for. Read with `AppColors.of(context)`.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.raised,
    required this.ring,
    required this.high,
    required this.medium,
    required this.low,
  });

  final Color raised; // segmented-control track, progress track
  final Color ring; // empty checkbox outline
  final Color high;
  final Color medium;
  final Color low;

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>()!;

  Color priority(String? p) => p == 'High'
      ? high
      : p == 'Medium'
      ? medium
      : low;

  @override
  AppColors copyWith({
    Color? raised,
    Color? ring,
    Color? high,
    Color? medium,
    Color? low,
  }) => AppColors(
    raised: raised ?? this.raised,
    ring: ring ?? this.ring,
    high: high ?? this.high,
    medium: medium ?? this.medium,
    low: low ?? this.low,
  );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      raised: Color.lerp(raised, other.raised, t)!,
      ring: Color.lerp(ring, other.ring, t)!,
      high: Color.lerp(high, other.high, t)!,
      medium: Color.lerp(medium, other.medium, t)!,
      low: Color.lerp(low, other.low, t)!,
    );
  }
}

class AppTheme {
  static ThemeData light(AccentTheme accent) =>
      _build(Brightness.light, accent);
  static ThemeData dark(AccentTheme accent) => _build(Brightness.dark, accent);

  static ThemeData _build(Brightness brightness, AccentTheme accentTheme) {
    final isDark = brightness == Brightness.dark;

    final background = isDark
        ? const Color(0xFF0F0F10)
        : const Color(0xFFF6F6F4);
    final surface = isDark ? const Color(0xFF18181A) : const Color(0xFFFFFFFF);
    final raised = isDark ? const Color(0xFF212124) : const Color(0xFFF0F0EE);
    final text = isDark ? const Color(0xFFF2F2F3) : const Color(0xFF18181B);
    final muted = isDark ? const Color(0xFF9C9CA3) : const Color(0xFF66666C);
    final border = isDark ? const Color(0xFF29292C) : const Color(0xFFE6E6E3);
    final error = isDark ? const Color(0xFFF07171) : const Color(0xFFC93C3C);
    final accent = isDark ? accentTheme.dark : accentTheme.light;
    // Dark-mode accents are light shades, so text on them is dark.
    final onAccent = isDark ? const Color(0xFF0F0F10) : Colors.white;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: onAccent,
      primaryContainer: accent.withValues(alpha: isDark ? 0.16 : 0.10),
      onPrimaryContainer: text,
      secondary: raised,
      onSecondary: text,
      tertiary: muted,
      onTertiary: surface,
      surface: surface,
      onSurface: text,
      onSurfaceVariant: muted,
      surfaceContainerHighest: raised,
      error: error,
      onError: isDark ? const Color(0xFF0F0F10) : Colors.white,
      outline: border,
      outlineVariant: border,
      inverseSurface: text,
      onInverseSurface: surface,
    );

    final base = isDark
        ? ThemeData.dark().textTheme
        : ThemeData.light().textTheme;
    final textTheme = GoogleFonts.interTextTheme(base)
        .copyWith(
          displayLarge: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            letterSpacing: -2,
            fontSize: 64,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          headlineLarge: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
            fontSize: 30,
          ),
          headlineMedium: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
            fontSize: 30,
          ), // screen titles
          headlineSmall: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
            fontSize: 17,
          ),
          titleLarge: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
            fontSize: 17,
          ),
          titleMedium: GoogleFonts.inter(
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
          titleSmall: GoogleFonts.inter(
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
          bodyLarge: GoogleFonts.inter(
            fontWeight: FontWeight.w400,
            fontSize: 16,
          ),
          bodyMedium: GoogleFonts.inter(
            fontWeight: FontWeight.w400,
            fontSize: 15,
          ),
          bodySmall: GoogleFonts.inter(
            fontWeight: FontWeight.w400,
            fontSize: 13,
          ),
          labelLarge: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          labelMedium: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          labelSmall: GoogleFonts.inter(
            fontWeight: FontWeight.w500,
            fontSize: 11,
          ),
        )
        .apply(bodyColor: text, displayColor: text);

    OutlineInputBorder inputBorder(Color c, [double w = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c, width: w),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      extensions: [
        AppColors(
          raised: raised,
          ring: isDark ? const Color(0xFF55555C) : const Color(0xFFB4B4B9),
          high: error,
          medium: isDark ? const Color(0xFFE0A93B) : const Color(0xFF93600A),
          low: muted,
        ),
      ],
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: text,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.headlineMedium,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        showDragHandle: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: text,
        contentTextStyle: GoogleFonts.inter(
          color: surface,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: onAccent,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: accent,
          foregroundColor: onAccent,
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          textStyle: textTheme.labelLarge,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: text,
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        labelStyle: textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? onAccent : muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? accent : raised,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: inputBorder(border),
        enabledBorder: inputBorder(border),
        focusedBorder: inputBorder(accent, 1.5),
        errorBorder: inputBorder(error),
        labelStyle: TextStyle(color: muted),
        hintStyle: TextStyle(color: muted),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: raised,
        circularTrackColor: raised,
      ),
    );
  }
}
