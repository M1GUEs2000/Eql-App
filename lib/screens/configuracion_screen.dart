import 'package:flutter/material.dart';

import '../data/apariencia.dart';
import '../data/sesion.dart';
import '../theme/eq_tokens.dart';
import '../widgets/eq_basicos.dart';
import '../widgets/eq_top_bar.dart';

class ConfiguracionScreen extends StatelessWidget {
  const ConfiguracionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const EqTopBar(titulo: 'Configuración'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          EqSpace.md,
          EqSpace.lg,
          EqSpace.md,
          EqSpace.xl,
        ),
        children: [
          const _Seccion('Apariencia'),
          const _SelectorApariencia(),
          const SizedBox(height: EqSpace.xl),
          const _Seccion('Cuenta'),
          _Cuenta(),
          const SizedBox(height: 12),
          const _EliminarCuenta(),
        ],
      ),
    );
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        texto.toUpperCase(),
        style: EqText.caption.copyWith(color: EqColors.acento),
      ),
    );
  }
}

class _SelectorApariencia extends StatelessWidget {
  const _SelectorApariencia();

  static const _opciones = [
    (ThemeMode.light, 'Claro', 'La app se ve clara siempre.'),
    (ThemeMode.dark, 'Oscuro', 'La app se ve oscura siempre.'),
    (
      ThemeMode.system,
      'Automático',
      'Usa el modo claro u oscuro que tenga tu dispositivo.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Apariencia.modo,
      builder: (context, actual, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, (modo, nombre, _)) in _opciones.indexed) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(
                  child: _OpcionModo(
                    modo: modo,
                    nombre: nombre,
                    elegido: modo == actual,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _opciones.firstWhere((o) => o.$1 == actual).$3,
            style: EqText.bodySm,
          ),
        ],
      ),
    );
  }
}

class _OpcionModo extends StatelessWidget {
  const _OpcionModo({
    required this.modo,
    required this.nombre,
    required this.elegido,
  });

  final ThemeMode modo;
  final String nombre;
  final bool elegido;

  @override
  Widget build(BuildContext context) {
    final miniatura = switch (modo) {
      ThemeMode.light => const _Miniatura(_Paleta.claro),
      ThemeMode.dark => const _Miniatura(_Paleta.oscuro),
      // Mitad clara y mitad oscura, cortadas en diagonal.
      ThemeMode.system => const Stack(
        fit: StackFit.expand,
        children: [
          _Miniatura(_Paleta.claro),
          ClipPath(clipper: _Diagonal(), child: _Miniatura(_Paleta.oscuro)),
        ],
      ),
    };
    return Semantics(
      button: true,
      selected: elegido,
      label: 'Modo $nombre',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => Apariencia.elegir(modo),
        borderRadius: BorderRadius.circular(EqRadius.md + 2),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(EqRadius.md),
                  border: Border.all(
                    color: elegido ? EqColors.primary : EqColors.borderLight,
                    width: 2,
                  ),
                ),
                child: AspectRatio(
                  aspectRatio: 0.72,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(EqRadius.base),
                    child: miniatura,
                  ),
                ),
              ),
              const SizedBox(height: EqSpace.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      elegido
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      key: ValueKey(elegido),
                      size: 18,
                      color: elegido ? EqColors.primary : EqColors.textFaint,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      nombre,
                      overflow: TextOverflow.ellipsis,
                      style: EqText.label.copyWith(
                        fontWeight: elegido ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Colores fijos de cada miniatura: muestran el modo aunque la app esté en el otro.
/// Son los mismos valores de EqColors en claro y en oscuro.
class _Paleta {
  const _Paleta(this.fondo, this.tarjeta, this.borde, this.linea, this.chip);

  final Color fondo;
  final Color tarjeta;
  final Color borde;
  final Color linea;
  final Color chip;

  static const claro = _Paleta(
    Color(0xFFF8FAFC),
    Color(0xFFFFFFFF),
    Color(0xFFE2E8F0),
    Color(0xFFCBD5E1),
    Color(0xFFC1EEC3),
  );
  static const oscuro = _Paleta(
    Color(0xFF0E1411),
    Color(0xFF151C18),
    Color(0xFF2A3530),
    Color(0xFF3D4A3F),
    Color(0xFF1D3D2D),
  );
}

/// La app en pequeño: barra verde, dos tarjetas y la barra de navegación.
class _Miniatura extends StatelessWidget {
  const _Miniatura(this.p);

  final _Paleta p;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: p.fondo,
      child: Column(
        children: [
          Container(
            height: 22,
            padding: const EdgeInsets.symmetric(horizontal: 7),
            decoration: const BoxDecoration(gradient: EqGradients.hero),
            child: Row(
              children: [
                Container(
                  width: 18,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Spacer(),
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                children: [
                  _tarjeta(0.75),
                  const SizedBox(height: 5),
                  _tarjeta(0.5),
                ],
              ),
            ),
          ),
          Container(
            height: 14,
            decoration: BoxDecoration(
              color: p.tarjeta,
              border: Border(top: BorderSide(color: p.borde)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var i = 0; i < 4; i++)
                  Container(
                    width: 8,
                    height: 4,
                    decoration: BoxDecoration(
                      color: i == 0 ? p.chip : p.linea,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjeta(double largo) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: p.tarjeta,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: p.borde),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: p.chip,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: largo,
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: p.linea,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Diagonal extends CustomClipper<Path> {
  const _Diagonal();

  @override
  Path getClip(Size s) => Path()
    ..moveTo(s.width, 0)
    ..lineTo(s.width, s.height)
    ..lineTo(0, s.height)
    ..close();

  @override
  bool shouldReclip(_Diagonal oldClipper) => false;
}

class _Cuenta extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final perfil = Sesion.perfil;
    final nombre = Sesion.nombre;
    return EqCard(
      sombra: false,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: EqColors.acentoFondo,
              shape: BoxShape.circle,
            ),
            child: Text(
              nombre.isEmpty ? '?' : nombre.characters.first.toUpperCase(),
              style: EqText.h4.copyWith(
                color: EqColors.acento,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: EqSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  style: EqText.h4.copyWith(fontWeight: FontWeight.w600),
                ),
                if (perfil != null)
                  Text('${perfil.usuario} · ${perfil.rol}', style: EqText.bodySm),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// La API v1 no permite eliminar la cuenta; la opción queda visible pero
/// deshabilitada hasta que exista el endpoint.
class _EliminarCuenta extends StatelessWidget {
  const _EliminarCuenta();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      enabled: false,
      child: EqCard(
        sombra: false,
        color: EqColors.surfaceLow,
        borde: EqColors.borderFaint,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.delete_outline,
              color: EqColors.errorText.withValues(alpha: 0.45),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Eliminar cuenta',
                    style: EqText.label.copyWith(
                      color: EqColors.textFaint,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Todavía no está disponible en la app. Puedes eliminarla '
                    'desde Equilibra en la web, en Configuración.',
                    style: EqText.bodySm,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
