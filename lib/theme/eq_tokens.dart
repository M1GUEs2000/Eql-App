import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Tokens de design-system/equilibra-design-system.css (v1.1.0).
// Si cambia el CSS, este archivo es el único que hay que tocar.

abstract final class EqColors {
  /// Lo fija la raíz de la app según la apariencia elegida (ver data/apariencia.dart).
  /// Los colores de marca y de estado son iguales en ambos modos; cambian los
  /// neutros, el verde de los botones y el acento de textos e íconos.
  static var oscuro = false;

  static Color _m(int claro, int noche) => Color(oscuro ? noche : claro);

  static Color get primary => _m(0xFF006D43, 0xFF24935F);
  static const primaryHover = Color(0xFF005A38);
  static const primaryDark = Color(0xFF003D28);
  static const primaryContainer = Color(0xFF4A9E70);
  static const primaryLight = Color(0xFF61B988);
  static const primarySoft = Color(0xFFC1EEC3);
  static const indigo = Color(0xFF4B51C9);
  static const indigoContainer = Color(0xFFA2A7FF);

  /// Texto e íconos verdes sobre superficies (primaryDark en claro).
  static Color get acento => _m(0xFF003D28, 0xFF8FDDB0);

  /// Fondo verde suave de chips e íconos (primarySoft en claro).
  static Color get acentoFondo => _m(0xFFC1EEC3, 0xFF1D3D2D);

  static Color get bg => _m(0xFFF8FAFC, 0xFF0E1411);
  static Color get surface => _m(0xFFFFFFFF, 0xFF151C18);
  static Color get surfaceLow => _m(0xFFEFF5EB, 0xFF1A231E);
  static Color get surfaceContainer => _m(0xFFE9F0E6, 0xFF1F2924);
  static Color get surfaceHigh => _m(0xFFE4EAE0, 0xFF26312B);

  static Color get onSurface => _m(0xFF171D17, 0xFFE2EAE3);
  static Color get onSurfaceVar => _m(0xFF3E4A3E, 0xFFBAC7BB);
  static Color get outline => _m(0xFF6E7A6D, 0xFF889587);
  static Color get outlineVar => _m(0xFFBDCABB, 0xFF3D4A3F);

  static const success = Color(0xFF22C55E);
  static const successBg = Color(0x1522C55E);
  static const successText = Color(0xFF16A34A);
  static const warning = Color(0xFFEAB308);
  static const warningBg = Color(0x15EAB308);
  static const warningText = Color(0xFFCA8A04);
  static const error = Color(0xFFEF4444);
  static const errorBg = Color(0x15EF4444);
  static Color get errorText => _m(0xFFDC2626, 0xFFF87171);
  static const info = Color(0xFF0EA5E9);

  static Color get borderLight => _m(0xFFE2E8F0, 0xFF2A3530);
  static Color get borderFaint => _m(0xFFF1F5F9, 0xFF1D2621);
  static Color get textMuted => _m(0xFF475569, 0xFFA2AFA6);
  static Color get textFaint => _m(0xFF94A3B8, 0xFF6F7D74);
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
    colors: [EqColors.primaryDark, Color(0xFF06573A), Color(0xFF006D43)],
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
  static TextStyle get button => _body(16, FontWeight.w600, 1.2, Colors.white);
}
