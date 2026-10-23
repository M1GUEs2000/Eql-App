import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Tokens de design-system/equilibra-design-system.css (v1.1.0).
// Si cambia el CSS, este archivo es el único que hay que tocar.

abstract final class EqColors {
  static const primary = Color(0xFF006D43);
  static const primaryHover = Color(0xFF005A38);
  static const primaryDark = Color(0xFF003D28);
  static const primaryContainer = Color(0xFF4A9E70);
  static const primaryLight = Color(0xFF61B988);
  static const primarySoft = Color(0xFFC1EEC3);
  static const indigo = Color(0xFF4B51C9);
  static const indigoContainer = Color(0xFFA2A7FF);

  static const bg = Color(0xFFF8FAFC);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceLow = Color(0xFFEFF5EB);
  static const surfaceContainer = Color(0xFFE9F0E6);
  static const surfaceHigh = Color(0xFFE4EAE0);

  static const onSurface = Color(0xFF171D17);
  static const onSurfaceVar = Color(0xFF3E4A3E);
  static const outline = Color(0xFF6E7A6D);
  static const outlineVar = Color(0xFFBDCABB);

  static const success = Color(0xFF22C55E);
  static const successBg = Color(0x1522C55E);
  static const successText = Color(0xFF16A34A);
  static const warning = Color(0xFFEAB308);
  static const warningBg = Color(0x15EAB308);
  static const warningText = Color(0xFFCA8A04);
  static const error = Color(0xFFEF4444);
  static const errorBg = Color(0x15EF4444);
  static const errorText = Color(0xFFDC2626);
  static const info = Color(0xFF0EA5E9);

  static const borderLight = Color(0xFFE2E8F0);
  static const borderFaint = Color(0xFFF1F5F9);
  static const textMuted = Color(0xFF475569);
  static const textFaint = Color(0xFF94A3B8);
}

abstract final class EqSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

abstract final class EqRadius {
  static const sm = 4.0;
  static const base = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
}

abstract final class EqShadow {
  static const sm = [BoxShadow(color: Color(0x0A006D43), offset: Offset(0, 1), blurRadius: 3)];
  static const base = [BoxShadow(color: Color(0x0F006D43), offset: Offset(0, 2), blurRadius: 6)];
  static const md = [BoxShadow(color: Color(0x17006D43), offset: Offset(0, 4), blurRadius: 16)];
  static const lg = [BoxShadow(color: Color(0x1F006D43), offset: Offset(0, 8), blurRadius: 32)];
}

abstract final class EqGradients {
  // .page-hero: linear-gradient(160deg, primary-dark, #06573a 55%, primary)
  static const hero = LinearGradient(
    begin: Alignment(-0.36, -1),
    end: Alignment(0.36, 1),
    colors: [EqColors.primaryDark, Color(0xFF06573A), EqColors.primary],
    stops: [0, 0.55, 1],
  );

  // Filo de luz de 3px bajo la .site-header
  static const filo = LinearGradient(
    colors: [Color(0x00C1EEC3), Color(0x59C1EEC3), EqColors.primarySoft, Color(0x59C1EEC3), Color(0x00C1EEC3)],
    stops: [0, 0.2, 0.5, 0.8, 1],
  );
}

// Escala tipográfica: Plus Jakarta Sans para títulos, Inter para el cuerpo.
// .eq-caption va en mayúsculas: quien lo use pasa el texto con toUpperCase().
abstract final class EqText {
  static TextStyle _display(double size, FontWeight weight, double height) =>
      GoogleFonts.plusJakartaSans(fontSize: size, fontWeight: weight, height: height, color: EqColors.onSurface);

  static TextStyle _body(double size, FontWeight weight, double height, Color color) =>
      GoogleFonts.inter(fontSize: size, fontWeight: weight, height: height, color: color);

  static TextStyle get display => _display(40, FontWeight.w700, 1.15);
  static TextStyle get h1 => _display(32, FontWeight.w700, 1.2);
  static TextStyle get h2 => _display(24, FontWeight.w600, 1.25);
  static TextStyle get h3 => _display(20, FontWeight.w600, 1.3);
  static TextStyle get h4 => _display(16, FontWeight.w500, 1.35);

  static TextStyle get bodyLg => _body(18, FontWeight.w400, 1.6, EqColors.onSurfaceVar);
  static TextStyle get body => _body(16, FontWeight.w400, 1.6, EqColors.onSurfaceVar);
  static TextStyle get bodySm => _body(14, FontWeight.w400, 1.5, EqColors.textMuted);
  static TextStyle get caption => _body(12, FontWeight.w500, 1.4, EqColors.textMuted).copyWith(letterSpacing: 0.48);
  static TextStyle get label => _body(14, FontWeight.w500, 1.4, EqColors.onSurface);
  static TextStyle get button => _body(16, FontWeight.w600, 1.2, EqColors.surface);
}
