import 'package:flutter/material.dart';

import '../data/api.dart';
import '../data/sesion.dart';
import '../theme/eq_tokens.dart';
import '../widgets/eq_basicos.dart';
import 'shell_screen.dart';

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  // Códigos de tbNutr_paises; la API no tiene un endpoint con el catálogo completo.
  static const _paises = {
    'ECUA': 'Ecuador',
    'ARGE': 'Argentina',
    'USA': 'Estados Unidos',
  };

  // Catálogo del registro web (ServiceLogin.ObtenerFormularioRegistrarse).
  static const _medios = {
    'A': 'Por Google',
    'AA': 'Ya soy cliente de Equilibra',
    'B': 'Otros buscadores de Internet',
    'BB': 'Por referencia de un cliente de Equilibra',
    'C': 'Por referencia de un amigo o familiar',
    'D': 'Por enlace de una página de Internet',
    'E': 'Por referencia de una escuela de nutrición',
    'F': 'Otras (indique cuál)',
  };

  final _formulario = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _correo = TextEditingController();
  final _confirmar = TextEditingController();
  final _otro = TextEditingController();
  String? _pais;
  String? _seEntero;
  var _privacidad = false;
  var _cookies = false;
  var _enviando = false;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    _correo.dispose();
    _confirmar.dispose();
    _otro.dispose();
    super.dispose();
  }

  String? _requerido(String? valor, String mensaje) =>
      (valor == null || valor.trim().isEmpty) ? mensaje : null;

  Future<void> _enviar() async {
    if (!_formulario.currentState!.validate()) return;
    if (!_privacidad || !_cookies) {
      setState(
        () => _error = 'Debe aceptar la política de privacidad y la de cookies',
      );
      return;
    }
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      await Sesion.registrar({
        'nombre': _nombre.text.trim(),
        'usuario': _correo.text.trim(),
        'confirmarUsuario': _confirmar.text.trim(),
        'pais': _pais,
        'comoSeEntero': _seEntero,
        if (_seEntero == 'F') 'comoSeEnteroDetalle': _otro.text.trim(),
        'aceptaPoliticaPrivacidad': _privacidad,
        'aceptaPoliticaCookies': _cookies,
      });
      if (!mounted) return;
      // La API inicia sesión al registrar: se entra directo a la app.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const ShellScreen()),
        (_) => false,
      );
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.detalle);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrarse')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(EqSpace.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formulario,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Crea tu cuenta', style: EqText.h2),
                    const SizedBox(height: EqSpace.xs),
                    Text(
                      'Completa tus datos para empezar a usar Equilibra',
                      style: EqText.bodySm,
                    ),
                    const SizedBox(height: EqSpace.lg),
                    EqField(
                      etiqueta: 'Nombres',
                      child: TextFormField(
                        controller: _nombre,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          hintText: 'Ingrese su nombre completo',
                        ),
                        validator: (v) => _requerido(v, 'Ingrese nombres'),
                      ),
                    ),
                    const SizedBox(height: EqSpace.md),
                    EqField(
                      etiqueta: 'Correo',
                      child: TextFormField(
                        controller: _correo,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          hintText: 'Ingrese su correo',
                        ),
                        validator: (v) => _requerido(v, 'Ingrese un correo'),
                      ),
                    ),
                    const SizedBox(height: EqSpace.md),
                    EqField(
                      etiqueta: 'Confirmar correo',
                      child: TextFormField(
                        controller: _confirmar,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          hintText: 'Vuelva a ingresar su correo',
                        ),
                        validator: (v) =>
                            _requerido(v, 'Confirme su correo') ??
                            (v!.trim() != _correo.text.trim()
                                ? 'Los correos no coinciden'
                                : null),
                      ),
                    ),
                    const SizedBox(height: EqSpace.md),
                    EqField(
                      etiqueta: 'País',
                      child: DropdownButtonFormField<String>(
                        initialValue: _pais,
                        hint: const Text('Seleccione un país'),
                        items: [
                          for (final p in _paises.entries)
                            DropdownMenuItem(
                              value: p.key,
                              child: Text(p.value),
                            ),
                        ],
                        onChanged: (v) => setState(() => _pais = v),
                        validator: (v) =>
                            v == null ? 'Seleccione un país' : null,
                      ),
                    ),
                    const SizedBox(height: EqSpace.md),
                    EqField(
                      etiqueta: '¿Cómo se enteró?',
                      child: DropdownButtonFormField<String>(
                        initialValue: _seEntero,
                        hint: const Text('Seleccione una opción'),
                        isExpanded: true,
                        items: [
                          for (final m in _medios.entries)
                            DropdownMenuItem(
                              value: m.key,
                              child: Text(
                                m.value,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (v) => setState(() => _seEntero = v),
                        validator: (v) =>
                            v == null ? 'Seleccione cómo se enteró' : null,
                      ),
                    ),
                    if (_seEntero == 'F') ...[
                      const SizedBox(height: EqSpace.md),
                      EqField(
                        etiqueta: 'Especifique',
                        child: TextFormField(
                          controller: _otro,
                          decoration: const InputDecoration(
                            hintText: 'Cuéntenos cómo nos conoció',
                          ),
                          validator: (v) =>
                              _requerido(v, 'Indique cómo se enteró'),
                        ),
                      ),
                    ],
                    const SizedBox(height: EqSpace.md),
                    CheckboxListTile(
                      value: _privacidad,
                      onChanged: (v) =>
                          setState(() => _privacidad = v ?? false),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        'Acepto la política de privacidad',
                        style: EqText.bodySm,
                      ),
                    ),
                    CheckboxListTile(
                      value: _cookies,
                      onChanged: (v) => setState(() => _cookies = v ?? false),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        'Acepto la política de cookies',
                        style: EqText.bodySm,
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: EqSpace.sm),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: EqText.bodySm.copyWith(color: EqColors.error),
                      ),
                    ],
                    const SizedBox(height: EqSpace.lg),
                    FilledButton(
                      onPressed: _enviando ? null : _enviar,
                      child: _enviando
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Registrarse'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
