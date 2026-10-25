import 'package:flutter/material.dart';

/// アプリ共通のテーマ
class AppTheme {
  AppTheme._();

  static final ThemeData light = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
  );
}
