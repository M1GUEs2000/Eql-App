import 'package:flutter/material.dart';

import '../data/sesion.dart';
import '../theme/eq_tokens.dart';
import 'login_screen.dart';
import 'shell_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final _pulso = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _entrar();
  }

  // Mientras se ve el logo se comprueba si el token guardado sigue vigente.
  Future<void> _entrar() async {
    final (conSesion, _) = await (
      Sesion.restaurar(),
      Future<void>.delayed(const Duration(milliseconds: 1500)),
    ).wait;
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => conSesion ? const ShellScreen() : const LoginScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _pulso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(gradient: EqGradients.hero),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(),
              FadeTransition(
                opacity: Tween<double>(begin: 0.5, end: 1).animate(_pulso),
                child: Image.asset(
                  'assets/images/logo_100.png',
                  width: 100,
                  height: 100,
                ),
              ),
              const SizedBox(height: EqSpace.lg),
              Text.rich(
                TextSpan(
                  style: EqText.h1.copyWith(color: Colors.white),
                  children: const [
                    TextSpan(text: 'Equi'),
                    TextSpan(
                      text: 'libra',
                      style: TextStyle(color: EqColors.primarySoft),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                '@GeneralSoftec',
                style: EqText.bodySm.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: EqSpace.xl),
            ],
          ),
        ),
      ),
    );
  }
}
