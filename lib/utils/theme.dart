import 'package:flutter/material.dart';

class AppTheme {
  // 펫신드룸 컬러 팔레트 (미니멀리스트)
  static const Color primary = Color(0xFF2E7D5E);      // 딥 민트그린
  static const Color primaryLight = Color(0xFF4CAF82); // 라이트 민트
  static const Color accent = Color(0xFFE8F5EF);       // 민트 배경
  static const Color surface = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF7F9F8);
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color border = Color(0xFFE5E7EB);
  static const Color danger = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.light,
          primary: primary,
          surface: surface,
        ),
        scaffoldBackgroundColor: background,
        appBarTheme: const AppBarTheme(
          backgroundColor: surface,
          foregroundColor: textPrimary,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: border, width: 1),
          ),
          color: surface,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF9FAFB),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: primary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: danger),
          ),
          labelStyle: const TextStyle(color: textSecondary, fontSize: 13),
          hintStyle: const TextStyle(color: textSecondary, fontSize: 13),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: primary,
            side: const BorderSide(color: primary),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: primary,
            textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
        dividerTheme: const DividerThemeData(color: border, thickness: 1, space: 1),
        chipTheme: ChipThemeData(
          backgroundColor: accent,
          labelStyle: const TextStyle(color: primary, fontSize: 12),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      );
}

// 공통 스타일 텍스트
class AppText {
  static const TextStyle heading1 = TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary);
  static const TextStyle heading2 = TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary);
  static const TextStyle heading3 = TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary);
  static const TextStyle body = TextStyle(fontSize: 14, color: AppTheme.textPrimary);
  static const TextStyle bodySmall = TextStyle(fontSize: 12, color: AppTheme.textSecondary);
  static const TextStyle label = TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.textSecondary, letterSpacing: 0.5);
  static const TextStyle price = TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.primary);
}
