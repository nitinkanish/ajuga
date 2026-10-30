import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppColors {
  static const ink = Color(0xFF121826);
  static const muted = Color(0xFF8E95A8);
  static const line = Color(0xFFE6E8EF);
  static const positive = Color(0xFF1AAE6F);
  static const canvas = Color(0xFFF4F6FB);
  static const night = Color(0xFF070B14);
  static const danger = Color(0xFFC34545);
}

const SystemUiOverlayStyle lightStatus = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarBrightness: Brightness.light,
  statusBarIconBrightness: Brightness.dark,
);

const SystemUiOverlayStyle darkStatus = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarBrightness: Brightness.dark,
  statusBarIconBrightness: Brightness.light,
);

ThemeData buildAjugaTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: Colors.white,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF2F6BFF),
      brightness: Brightness.light,
    ),
    fontFamily: '.SF Pro Text',
    fontFamilyFallback: const [
      '.SF Pro Display',
      'Helvetica Neue',
      'Helvetica',
    ],
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
      fontFamily: '.SF Pro Text',
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      systemOverlayStyle: lightStatus,
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      contentTextStyle: TextStyle(color: Colors.white, fontSize: 14),
    ),
  );
}
