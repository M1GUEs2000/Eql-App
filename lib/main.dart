import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/api.dart';
import 'data/sesion.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'theme/eq_theme.dart';

final _navegador = GlobalKey<NavigatorState>();

void main() {
  // Token vencido o revocado (p. ej. "cerrar todas las sesiones" desde la web).
  Api.alPerderSesion = () async {
    await Sesion.expirar();
    _navegador.currentState?.pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  };
  runApp(const EquilibraApp());
}

class EquilibraApp extends StatelessWidget {
  const EquilibraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Equilibra',
      navigatorKey: _navegador,
      debugShowCheckedModeBanner: false,
      theme: buildEqTheme(),
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const SplashScreen(),
    );
  }
}
