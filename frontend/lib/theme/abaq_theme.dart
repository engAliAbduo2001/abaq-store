import 'package:flutter/material.dart';

@immutable
class AbaqPalette extends ThemeExtension<AbaqPalette> {
  const AbaqPalette({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceMuted,
    required this.border,
    required this.text,
    required this.secondaryText,
    required this.accent,
    required this.accentText,
    required this.accentSoft,
    required this.button,
    required this.buttonText,
    required this.inputSurface,
    required this.danger,
    required this.dangerSurface,
    required this.shadow,
  });

  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color surfaceMuted;
  final Color border;
  final Color text;
  final Color secondaryText;
  final Color accent;
  final Color accentText;
  final Color accentSoft;
  final Color button;
  final Color buttonText;
  final Color inputSurface;
  final Color danger;
  final Color dangerSurface;
  final Color shadow;

  static const midnightGold = AbaqPalette(
    background: Color(0xFF0B0B0E),
    surface: Color(0xFF16161C),
    surfaceElevated: Color(0xFF1C1C23),
    surfaceMuted: Color(0xFF222229),
    border: Color(0xFF26262F),
    text: Color(0xFFF5F5F7),
    secondaryText: Color(0xFF9E9EA9),
    accent: Color(0xFFD4AF37),
    accentText: Color(0xFF0B0B0E),
    accentSoft: Color(0xFF2A2516),
    button: Color(0xFFD4AF37),
    buttonText: Color(0xFF0B0B0E),
    inputSurface: Color(0xFF16161C),
    danger: Color(0xFFE58A82),
    dangerSurface: Color(0xFF321D20),
    shadow: Color(0x40000000),
  );

  static const noirIvory = AbaqPalette(
    background: Color(0xFFFAF8F5),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF2EEE7),
    border: Color(0xFFE8E2D8),
    text: Color(0xFF121215),
    secondaryText: Color(0xFF736E65),
    accent: Color(0xFFB8860B),
    accentText: Color(0xFF121215),
    accentSoft: Color(0xFFF4EBD5),
    button: Color(0xFF121215),
    buttonText: Color(0xFFFAF8F5),
    inputSurface: Color(0xFFFFFFFF),
    danger: Color(0xFFA54640),
    dangerSurface: Color(0xFFFCEBE9),
    shadow: Color(0x16000000),
  );

  @override
  AbaqPalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? surfaceMuted,
    Color? border,
    Color? text,
    Color? secondaryText,
    Color? accent,
    Color? accentText,
    Color? accentSoft,
    Color? button,
    Color? buttonText,
    Color? inputSurface,
    Color? danger,
    Color? dangerSurface,
    Color? shadow,
  }) {
    return AbaqPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      border: border ?? this.border,
      text: text ?? this.text,
      secondaryText: secondaryText ?? this.secondaryText,
      accent: accent ?? this.accent,
      accentText: accentText ?? this.accentText,
      accentSoft: accentSoft ?? this.accentSoft,
      button: button ?? this.button,
      buttonText: buttonText ?? this.buttonText,
      inputSurface: inputSurface ?? this.inputSurface,
      danger: danger ?? this.danger,
      dangerSurface: dangerSurface ?? this.dangerSurface,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AbaqPalette lerp(ThemeExtension<AbaqPalette>? other, double t) {
    if (other is! AbaqPalette) return this;
    return AbaqPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      text: Color.lerp(text, other.text, t)!,
      secondaryText: Color.lerp(secondaryText, other.secondaryText, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentText: Color.lerp(accentText, other.accentText, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      button: Color.lerp(button, other.button, t)!,
      buttonText: Color.lerp(buttonText, other.buttonText, t)!,
      inputSurface: Color.lerp(inputSurface, other.inputSurface, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerSurface: Color.lerp(dangerSurface, other.dangerSurface, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

extension AbaqPaletteContext on BuildContext {
  AbaqPalette get abaqPalette =>
      Theme.of(this).extension<AbaqPalette>() ?? AbaqPalette.midnightGold;
}

class AbaqTheme {
  const AbaqTheme._();

  static ThemeData get midnightGold =>
      _buildTheme(AbaqPalette.midnightGold, Brightness.dark);

  static ThemeData get noirIvory =>
      _buildTheme(AbaqPalette.noirIvory, Brightness.light);

  static ThemeData _buildTheme(AbaqPalette palette, Brightness brightness) {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: palette.accent,
          brightness: brightness,
        ).copyWith(
          primary: palette.button,
          onPrimary: palette.buttonText,
          secondary: palette.accent,
          onSecondary: palette.accentText,
          surface: palette.background,
          onSurface: palette.text,
          error: palette.danger,
          onError: palette.background,
          outline: palette.border,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.background,
      extensions: [palette],
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        foregroundColor: palette.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w500,
          letterSpacing: -1,
        ),
        titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
        bodyMedium: TextStyle(height: 1.45),
      ).apply(bodyColor: palette.text, displayColor: palette.text),
      iconTheme: IconThemeData(color: palette.text),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.inputSurface,
        labelStyle: TextStyle(color: palette.secondaryText),
        hintStyle: TextStyle(color: palette.secondaryText),
        prefixIconColor: palette.secondaryText,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: palette.accent, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: palette.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: palette.danger, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.button,
          foregroundColor: palette.buttonText,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.text,
          side: BorderSide(color: palette.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: palette.text),
      ),
      dividerTheme: DividerThemeData(color: palette.border, thickness: 1),
      chipTheme: ChipThemeData(
        backgroundColor: palette.surfaceMuted,
        selectedColor: palette.accentSoft,
        labelStyle: TextStyle(color: palette.text),
        side: BorderSide(color: palette.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.surfaceElevated,
        contentTextStyle: TextStyle(color: palette.text),
        actionTextColor: palette.text,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: palette.accent),
    );
  }
}
