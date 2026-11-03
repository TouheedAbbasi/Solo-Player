import 'package:flutter/material.dart';

const String kAppName = 'Solo Player';
const String kStudio = 'Senpai Studio';
const String kVersion = '1.0.0';
const String kTagline = 'Your Media. Your Way.';

class AppColors {
  final Color bg;
  final Color surface;
  final Color surface2;
  final Color text;
  final Color muted;
  final Color border;
  final Color accent;
  final Color onAccent;

  const AppColors({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.text,
    required this.muted,
    required this.border,
    required this.accent,
    required this.onAccent,
  });

  static const AppColors light = AppColors(
    bg: Color(0xFFF8FAFC),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFEEF0F4),
    text: Color(0xFF1F1F1F),
    muted: Color(0xFF6B7280),
    border: Color(0xFFE5E7EB),
    accent: Color(0xFF1F1F1F),
    onAccent: Color(0xFFFFFFFF),
  );

  static const AppColors dark = AppColors(
    bg: Color(0xFF0E0E10),
    surface: Color(0xFF1A1A1D),
    surface2: Color(0xFF26262A),
    text: Color(0xFFFFFFFF),
    muted: Color(0xFF9CA3AF),
    border: Color(0xFF2E2E33),
    accent: Color(0xFFFFFFFF),
    onAccent: Color(0xFF1F1F1F),
  );

  static AppColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

class ThemeController {
  static final ValueNotifier<ThemeMode> mode = ValueNotifier<ThemeMode>(ThemeMode.system);

  static ThemeMode fromInt(int v) =>
      v == 1 ? ThemeMode.light : (v == 2 ? ThemeMode.dark : ThemeMode.system);
}

ThemeData buildTheme(Brightness b) {
  final c = b == Brightness.dark ? AppColors.dark : AppColors.light;
  final scheme = b == Brightness.dark
      ? ColorScheme.dark(
          primary: c.accent,
          onPrimary: c.onAccent,
          secondary: c.accent,
          surface: c.surface,
          onSurface: c.text,
        )
      : ColorScheme.light(
          primary: c.accent,
          onPrimary: c.onAccent,
          secondary: c.accent,
          surface: c.surface,
          onSurface: c.text,
        );
  final base = ThemeData(brightness: b, useMaterial3: true, colorScheme: scheme);
  return base.copyWith(
    scaffoldBackgroundColor: c.bg,
    canvasColor: c.surface,
    dividerColor: c.border,
    textTheme: base.textTheme.apply(bodyColor: c.text, displayColor: c.text),
    appBarTheme: AppBarTheme(
      backgroundColor: c.bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      foregroundColor: c.text,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: c.accent,
      inactiveTrackColor: c.border,
      thumbColor: c.accent,
      overlayColor: c.accent.withOpacity(0.12),
      trackHeight: 3,
    ),
    popupMenuTheme: PopupMenuThemeData(color: c.surface, surfaceTintColor: Colors.transparent),
  );
}
