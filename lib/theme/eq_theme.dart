import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'eq_tokens.dart';

ThemeData buildEqTheme() {
  // Lee los tokens del modo vigente: se vuelve a construir al cambiar EqColors.oscuro.
  final esquema = ColorScheme.fromSeed(
    seedColor: EqColors.primary,
    brightness: EqColors.oscuro ? Brightness.dark : Brightness.light,
    primary: EqColors.primary,
    onPrimary: Colors.white,
    secondary: EqColors.indigo,
    onSecondary: Colors.white,
    surface: EqColors.surface,
    onSurface: EqColors.onSurface,
    error: EqColors.error,
  );
  // fontFamily en vez de GoogleFonts.interTextTheme: google_fonts 9 trae su TextTheme
  // de material_ui, que no es el mismo tipo que el de flutter/material.dart.
  final base = ThemeData(useMaterial3: true, colorScheme: esquema, fontFamily: GoogleFonts.inter().fontFamily);
  final forma = RoundedRectangleBorder(borderRadius: BorderRadius.circular(EqRadius.base));

  OutlineInputBorder borde(Color color, [double ancho = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(EqRadius.base),
    borderSide: BorderSide(color: color, width: ancho),
  );

  return base.copyWith(
    scaffoldBackgroundColor: EqColors.bg,
    textTheme: base.textTheme.apply(bodyColor: EqColors.onSurface, displayColor: EqColors.onSurface),
    appBarTheme: AppBarTheme(
      backgroundColor: EqColors.primaryDark,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleTextStyle: EqText.h4.copyWith(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: EqColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: EqColors.primary.withValues(alpha: 0.4),
        disabledForegroundColor: Colors.white,
        minimumSize: const Size(64, 48),
        shape: forma,
        textStyle: EqText.button,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: EqColors.primary,
        side: BorderSide(color: EqColors.primary),
        minimumSize: const Size(64, 44),
        shape: forma,
        textStyle: EqText.button.copyWith(fontSize: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: EqColors.primary,
        textStyle: EqText.label.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: EqColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      hintStyle: EqText.bodySm.copyWith(color: EqColors.textFaint),
      prefixIconColor: EqColors.textMuted,
      suffixIconColor: EqColors.textMuted,
      border: borde(EqColors.borderLight),
      enabledBorder: borde(EqColors.borderLight),
      focusedBorder: borde(EqColors.primary, 2),
      errorBorder: borde(EqColors.error),
      focusedErrorBorder: borde(EqColors.error, 2),
      errorStyle: EqText.caption.copyWith(color: EqColors.errorText, letterSpacing: 0),
    ),
    dividerTheme: DividerThemeData(color: EqColors.borderLight, thickness: 1, space: 1),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: EqColors.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: EqColors.acentoFondo,
      elevation: 0,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (estados) => EqText.caption.copyWith(
          letterSpacing: 0,
          fontWeight: estados.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
          color: estados.contains(WidgetState.selected) ? EqColors.acento : EqColors.textMuted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (estados) =>
            IconThemeData(color: estados.contains(WidgetState.selected) ? EqColors.acento : EqColors.textMuted),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: EqColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: forma,
      textStyle: EqText.label,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: EqColors.surface,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(EqRadius.lg))),
    ),
    dialogTheme: DialogThemeData(backgroundColor: EqColors.surface, surfaceTintColor: Colors.transparent),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: EqColors.onSurface,
      shape: forma,
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(EqRadius.sm)),
      side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: EqColors.primary,
      linearTrackColor: EqColors.surfaceContainer,
    ),
  );
}
