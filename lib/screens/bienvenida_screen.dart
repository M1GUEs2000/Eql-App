import 'package:flutter/material.dart';

import '../theme/eq_tokens.dart';
import 'login_screen.dart';
import 'registro_screen.dart';

/// Primera pantalla sin sesión: elegir entre ingresar o crear una cuenta.
class BienvenidaScreen extends StatelessWidget {
  const BienvenidaScreen({super.key});

  void _abrir(BuildContext context, Widget pantalla) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => pantalla));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(EqSpace.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Image.asset('assets/images/logo_100.png', width: 100, height: 100),
                  ),
                  const SizedBox(height: EqSpace.lg),
                  Text(
                    'Bienvenido a Equilibra',
                    textAlign: TextAlign.center,
                    style: EqText.h2.copyWith(color: EqColors.acento),
                  ),
                  const SizedBox(height: EqSpace.xs),
                  Text(
                    '¿Ya tienes una cuenta?',
                    textAlign: TextAlign.center,
                    style: EqText.body,
                  ),
                  const SizedBox(height: EqSpace.xl),
                  FilledButton(
                    onPressed: () => _abrir(context, const LoginScreen()),
                    child: const Text('Ya tengo una cuenta'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => _abrir(context, const RegistroScreen()),
                    child: const Text('Registrarse'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
