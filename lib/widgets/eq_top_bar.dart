import 'package:flutter/material.dart';

import '../theme/eq_tokens.dart';
import 'user_menu.dart';

/// Barra superior sin franja: fondo de la pantalla, la marca y el menú de tres puntos.
/// Sin [titulo] muestra la marca; con [titulo] se usa en pantallas secundarias.
class EqTopBar extends StatelessWidget implements PreferredSizeWidget {
  const EqTopBar({super.key, this.titulo, this.acciones = const []});

  final String? titulo;
  final List<Widget> acciones;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: titulo == null ? const _Marca() : Text(titulo!),
      actions: [
        ...acciones,
        const UserMenu(),
        const SizedBox(width: EqSpace.xs),
      ],
    );
  }
}

class _Marca extends StatelessWidget {
  const _Marca();

  @override
  Widget build(BuildContext context) {
    final estilo = EqText.h3.copyWith(color: EqColors.onSurface, fontWeight: FontWeight.w700);
    return Text.rich(
      TextSpan(
        style: estilo,
        children: [
          const TextSpan(text: 'Equi'),
          TextSpan(text: 'libra', style: TextStyle(color: EqColors.acento)),
        ],
      ),
    );
  }
}
