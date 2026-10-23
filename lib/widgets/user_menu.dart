import 'package:flutter/material.dart';

import '../data/sesion.dart';
import '../screens/configuracion_screen.dart';
import '../screens/datos_screen.dart';
import '../screens/login_screen.dart';
import '../theme/eq_tokens.dart';

enum _Opcion { datos, configuracion, salir }

class UserMenu extends StatelessWidget {
  const UserMenu({super.key});

  Future<void> _elegir(BuildContext context, _Opcion opcion) async {
    final navegador = Navigator.of(context);
    switch (opcion) {
      case _Opcion.datos:
        navegador.push(MaterialPageRoute<void>(builder: (_) => const DatosScreen()));
      case _Opcion.configuracion:
        navegador.push(MaterialPageRoute<void>(builder: (_) => const ConfiguracionScreen()));
      case _Opcion.salir:
        await Sesion.cerrar();
        navegador.pushAndRemoveUntil(MaterialPageRoute<void>(builder: (_) => const LoginScreen()), (_) => false);
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
              Text(Sesion.nombre, style: EqText.label.copyWith(fontWeight: FontWeight.w600)),
              if (Sesion.perfil case final p?)
                Text('${p.usuario} · ${p.rol}', style: EqText.bodySm.copyWith(fontSize: 12)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(value: _Opcion.datos, child: _Item(Icons.badge_outlined, 'Editar datos del usuario')),
        const PopupMenuItem(value: _Opcion.configuracion, child: _Item(Icons.settings_outlined, 'Configuración')),
        const PopupMenuDivider(),
        const PopupMenuItem(value: _Opcion.salir, child: _Item(Icons.logout, 'Cerrar sesión')),
      ],
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        ),
        child: const Icon(Icons.person_outline, color: Colors.white, size: 20),
      ),
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
