import 'package:flutter/material.dart';

import '../theme/eq_tokens.dart';
import 'user_menu.dart';

/// Barra superior verde oscuro con el filo de luz de la .site-header.
/// Sin [titulo] muestra la marca; con [titulo] se usa en pantallas secundarias.
class EqTopBar extends StatelessWidget implements PreferredSizeWidget {
  const EqTopBar({super.key, this.titulo, this.acciones = const []});

  final String? titulo;
  final List<Widget> acciones;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 3);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: titulo == null ? const _Marca() : Text(titulo!),
      actions: [
        ...acciones,
        const UserMenu(),
        const SizedBox(width: EqSpace.sm),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(3),
        child: DecoratedBox(
          decoration: BoxDecoration(gradient: EqGradients.filo),
          child: SizedBox(height: 3, width: double.infinity),
        ),
      ),
    );
  }
}

class _Marca extends StatelessWidget {
  const _Marca();

  @override
  Widget build(BuildContext context) {
    final estilo = EqText.h3.copyWith(color: Colors.white, fontWeight: FontWeight.w700);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('assets/images/logo_25.png', width: 25, height: 25),
        const SizedBox(width: EqSpace.sm),
        Text.rich(
          TextSpan(
            style: estilo,
            children: const [
              TextSpan(text: 'Equi'),
              TextSpan(
                text: 'libra',
                style: TextStyle(color: EqColors.primarySoft),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
