import 'package:flutter/material.dart';

import '../data/api.dart';
import '../data/sesion.dart';
import '../theme/eq_tokens.dart';
import '../widgets/eq_basicos.dart';
import 'registro_screen.dart';
import 'shell_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usuario = TextEditingController();
  final _clave = TextEditingController();
  var _verClave = false;
  var _enviando = false;
  String? _error;

  @override
  void dispose() {
    _usuario.dispose();
    _clave.dispose();
    super.dispose();
  }

  Future<void> _ingresar() async {
    final usuario = _usuario.text.trim();
    if (usuario.isEmpty) {
      setState(() => _error = 'Ingrese su usuario');
      return;
    }
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      await Sesion.iniciar(usuario, _clave.text);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => const ShellScreen()));
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.detalle);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _recuperar() async {
    final usuario = _usuario.text.trim();
    if (usuario.isEmpty) {
      setState(() => _error = 'Escriba su usuario (correo) para recuperar la contraseña');
      return;
    }
    try {
      await Api.post('auth/recuperar-clave', {'usuario': usuario});
      if (mounted) mostrarMensaje(context, Api.ultimoMensaje ?? 'Revise su correo para recuperar la contraseña.');
    } on ApiError catch (e) {
      if (mounted) mostrarMensaje(context, e.detalle);
    }
  }

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
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOut,
                    builder: (context, v, child) => Opacity(
                      opacity: v,
                      child: Transform.translate(offset: Offset(0, 40 * (1 - v)), child: child),
                    ),
                    child: Center(child: Image.asset('assets/images/logo_100.png', width: 100, height: 100)),
                  ),
                  const SizedBox(height: EqSpace.lg),
                  Text(
                    'Bienvenido a Equilibra',
                    textAlign: TextAlign.center,
                    style: EqText.h2.copyWith(color: EqColors.primaryDark),
                  ),
                  const SizedBox(height: EqSpace.xs),
                  Text('Ingresa con tu usuario para continuar', textAlign: TextAlign.center, style: EqText.bodySm),
                  const SizedBox(height: EqSpace.lg),
                  EqField(
                    etiqueta: 'Usuario',
                    child: TextField(
                      controller: _usuario,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) {
                        if (_error != null) setState(() => _error = null);
                      },
                      decoration: const InputDecoration(
                        hintText: 'Correo o usuario',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                  ),
                  const SizedBox(height: EqSpace.md),
                  EqField(
                    etiqueta: 'Contraseña',
                    child: TextField(
                      controller: _clave,
                      obscureText: !_verClave,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _ingresar(),
                      decoration: InputDecoration(
                        hintText: 'Déjela vacía si su cuenta no tiene',
                        errorText: _error,
                        errorMaxLines: 4,
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _verClave ? 'Ocultar contraseña' : 'Ver contraseña',
                          onPressed: () => setState(() => _verClave = !_verClave),
                          icon: Icon(_verClave ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(onPressed: _recuperar, child: const Text('¿Olvidó su contraseña?')),
                  ),
                  const SizedBox(height: EqSpace.sm),
                  FilledButton(
                    onPressed: _enviando ? null : _ingresar,
                    child: _enviando
                        ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Ingresar'),
                  ),
                  const SizedBox(height: EqSpace.md),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text('¿Desea registrar un nuevo usuario?', style: EqText.bodySm),
                      TextButton(
                        onPressed: () =>
                            Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const RegistroScreen())),
                        child: const Text('Registrarse'),
                      ),
                    ],
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
