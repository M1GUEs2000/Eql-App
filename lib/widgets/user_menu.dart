import 'package:flutter/material.dart';

import '../data/sesion.dart';
import '../screens/citas_screen.dart';
import '../screens/configuracion_screen.dart';
import '../screens/datos_screen.dart';
import '../screens/bienvenida_screen.dart';
import '../theme/eq_tokens.dart';

enum _Opcion { datos, citas, configuracion, salir }

class UserMenu extends StatelessWidget {
  const UserMenu({super.key});

  Future<void> _elegir(BuildContext context, _Opcion opcion) async {
    final navegador = Navigator.of(context);
    switch (opcion) {
      case _Opcion.datos:
        navegador.push(
          MaterialPageRoute<void>(builder: (_) => const DatosScreen()),
        );
      case _Opcion.citas:
        navegador.push(
          MaterialPageRoute<void>(builder: (_) => const CitasScreen()),
        );
      case _Opcion.configuracion:
        navegador.push(
          MaterialPageRoute<void>(builder: (_) => const ConfiguracionScreen()),
        );
      case _Opcion.salir:
        await Sesion.cerrar();
        navegador.pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const BienvenidaScreen()),
          (_) => false,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_Opcion>(
      tooltip: 'Cuenta',
      offset: const Offset(0, 48),
      onSelected: (opcion) => _elegir(context, opcion),
      itemBuilder: (_) => [
        PopupMenuItem<_Opcion>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                Sesion.nombre,
                style: EqText.label.copyWith(fontWeight: FontWeight.w600),
              ),
              if (Sesion.perfil case final p?)
                Text(
                  '${p.usuario} · ${p.rol}',
                  style: EqText.bodySm.copyWith(fontSize: 12),
                ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: _Opcion.datos,
          child: _Item(Icons.badge_outlined, 'Editar datos del usuario'),
        ),
        const PopupMenuItem(
          value: _Opcion.citas,
          child: _Item(Icons.event_available_outlined, 'Agendar cita'),
        ),
        const PopupMenuItem(
          value: _Opcion.configuracion,
          child: _Item(Icons.settings_outlined, 'Configuración'),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: _Opcion.salir,
          child: _Item(Icons.logout, 'Cerrar sesión'),
        ),
      ],
      // Mismo porte que el círculo verde de la derecha, pero solo contorno.
      style: IconButton.styleFrom(
        fixedSize: const Size.square(34),
        minimumSize: const Size.square(34),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: EdgeInsets.zero,
        shape: const CircleBorder(),
        backgroundColor: EqColors.surface,
        side: BorderSide(color: EqColors.primary, width: 1.5),
      ),
      icon: Icon(Icons.person_outline, size: 20, color: EqColors.primary),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item(this.icono, this.texto);

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icono, size: 20, color: EqColors.textMuted),
        const SizedBox(width: 12),
        Text(texto),
      ],
    );
  }
}
