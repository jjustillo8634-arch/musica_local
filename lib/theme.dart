import 'package:flutter/material.dart';

/// Rojo característico de Apple Music.
const kRed = Color(0xFFFA2D48);
const kBg = Color(0xFF0B0B0D);
const kCard = Color(0xFF1C1C1F);
const kCardHi = Color(0xFF2A2A2E);
const kMuted = Color(0xFF9A9AA0);

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: kRed,
      onPrimary: Colors.white,
      secondary: kRed,
      surface: kBg,
      onSurface: Colors.white,
    ),
  );

  return base.copyWith(
    scaffoldBackgroundColor: kBg,
    appBarTheme: AppBarTheme(
      backgroundColor: kBg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: Colors.white,
      inactiveTrackColor: const Color(0x33FFFFFF),
      thumbColor: Colors.white,
      trackHeight: 4,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: kBg,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      height: 64,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? kRed : kMuted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: states.contains(WidgetState.selected) ? kRed : kMuted,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: kCard,
      selectedColor: kRed,
      side: BorderSide.none,
      showCheckmark: false,
      labelStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? kRed : kCardHi,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
  );
}
