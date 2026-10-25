import 'package:flutter/material.dart';

/// アプリ共通のテーマ
///
/// やわらかいセージグリーンを基調に、角丸・枠線中心のフラットな見た目にする。
class AppTheme {
  AppTheme._();

  /// 基調色（セージグリーン）
  static const seed = Color(0xFF4F8A78);

  /// 画面の背景色（少し温かみのあるオフホワイト）
  static const background = Color(0xFFF6F4EF);

  static final ColorScheme _colors = ColorScheme.fromSeed(
    seedColor: seed,
    surface: background,
  );

  static final ThemeData light = ThemeData(
    colorScheme: _colors,
    scaffoldBackgroundColor: background,
    visualDensity: VisualDensity.compact,
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: _colors.onSurface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: _colors.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: _colors.outlineVariant.withValues(alpha: 0.6)),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      side: BorderSide(color: _colors.outlineVariant),
      backgroundColor: Colors.white,
      selectedColor: _colors.primaryContainer,
      showCheckmark: false,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _colors.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _colors.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _colors.primary, width: 1.5),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: _colors.primary,
      foregroundColor: _colors.onPrimary,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 64,
      indicatorColor: _colors.primaryContainer,
      labelTextStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Colors.white,
      indicatorColor: _colors.primaryContainer,
    ),
    dividerTheme: DividerThemeData(
      color: _colors.outlineVariant.withValues(alpha: 0.6),
      space: 1,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: background,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: background,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
