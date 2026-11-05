import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF0F766E);
  static const bg = Color(0xFFF4F4F2);
  static const tileAvailable = Color(0xFFE3EFEC);
  static const tileMuted = Color(0xFFEBEBE9);
  static const text = Color(0xFF1B1F1E);
  static const textMuted = Color(0xFF6B7270);
  static const border = Color(0xFFE2E4E1);
  static const danger = Color(0xFFB42318);
  static const dangerBg = Color(0xFFFCE4E4);

  // ---- สีเพิ่มสำหรับหน้าจอง / รายการของฉัน / ค่าปรับ / แอดมิน (Flutter B) ----
  // ชื่อที่ซ้ำกับของ A ชี้ไปที่ค่าเดียวกัน จะได้เปลี่ยนสีที่เดียวแล้วเปลี่ยนทั้งแอป
  static const teal = primary;
  static const tealDark = Color(0xFF0B5A54);
  static const tealSoft = tileAvailable;
  static const line = border;
  static const muted = textMuted;
  static const red = danger;
  static const redSoft = dangerBg;
  static const redText = Color(0xFF7F1D1D);
  static const greenSoft = Color(0xFFD7F0DD);
  static const greenText = Color(0xFF14532D);
  static const amberSoft = Color(0xFFFDEBC8);
  static const amberText = Color(0xFF7A4A00);
  static const blueSoft = Color(0xFFDCE8FB);
  static const blueText = Color(0xFF1E3A8A);
  static const graySoft = Color(0xFFECEEEB);
  static const grayText = Color(0xFF3F4B48);
}

ThemeData buildTheme() {
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c, width: w),
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
    ),
    scaffoldBackgroundColor: AppColors.bg,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.text,
      ),
    ),
    // ใช้ฟอนต์ของระบบ (ไม่พึ่ง google_fonts เพราะเวอร์ชันของแพ็กเกจชนกับ Flutter ที่ติดตั้ง)
    // บนเว็บ Flutter โหลดฟอนต์ไทยสำรองให้เอง
    textTheme: ThemeData.light()
        .textTheme
        .apply(bodyColor: AppColors.text, displayColor: AppColors.text),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: border(AppColors.border),
      enabledBorder: border(AppColors.border),
      focusedBorder: border(AppColors.primary, 1.5),
      errorBorder: border(AppColors.danger),
      focusedErrorBorder: border(AppColors.danger, 1.5),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
    ),
  );
}
