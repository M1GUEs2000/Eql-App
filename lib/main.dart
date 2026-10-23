import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/api.dart';
import 'data/apariencia.dart';
import 'data/sesion.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'theme/eq_theme.dart';
import 'theme/eq_tokens.dart';

final _navegador = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Token vencido o revocado (p. ej. "cerrar todas las sesiones" desde la web).
  Api.alPerderSesion = () async {
    await Sesion.expirar();
    _navegador.currentState?.pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  };
  await Apariencia.cargar();
  runApp(const EquilibraApp());
}

class EquilibraApp extends StatefulWidget {
  const EquilibraApp({super.key});

  @override
  State<EquilibraApp> createState() => _EquilibraAppState();
}

class _EquilibraAppState extends State<EquilibraApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Apariencia.modo.addListener(_aplicar);
    EqColors.oscuro = _quiereOscuro();
  }

  @override
  void dispose() {
    Apariencia.modo.removeListener(_aplicar);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() => _aplicar();

  bool _quiereOscuro() => switch (Apariencia.modo.value) {
    ThemeMode.dark => true,
    ThemeMode.light => false,
    ThemeMode.system =>
      PlatformDispatcher.instance.platformBrightness == Brightness.dark,
  };

  void _aplicar() {
    final oscuro = _quiereOscuro();
    if (oscuro == EqColors.oscuro) return;
    EqColors.oscuro = oscuro;
    setState(() {});
    // Las pantallas leen EqColors directamente, sin Theme.of, así que no se
    // enteran del cambio: se marcan todas para que vuelvan a construirse.
    void marcar(Element e) {
      e.markNeedsBuild();
      e.visitChildren(marcar);
    }

    (context as Element).visitChildren(marcar);
  }

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
