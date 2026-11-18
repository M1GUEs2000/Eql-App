import 'package:flutter/material.dart';

import '../theme/eq_tokens.dart';
import 'user_menu.dart';

/// Barra superior sin marca: icono de usuario a la izquierda y, a la derecha,
/// los botones de la pantalla ([acciones]: crear, eliminar, optimizar…).
/// Con [titulo] (pantallas secundarias) muestra flecha de volver y el título en lugar del usuario.
class EqTopBar extends StatelessWidget implements PreferredSizeWidget {
  const EqTopBar({
    super.key,
    this.titulo,
    this.acciones = const [],
    this.flotante = false,
  });

  final String? titulo;
  final List<Widget> acciones;

  /// Sin franja de fondo: solo los botones flotan sobre el contenido. La
  /// pantalla debe usar `extendBodyBehindAppBar` y dejar el espacio de la barra
  /// arriba de su contenido (ver [espacioBarra]).
  final bool flotante;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final secundaria = titulo != null;
    return AppBar(
      backgroundColor: flotante ? Colors.transparent : null,
      automaticallyImplyLeading: secundaria,
      // Center: el slot leading fuerza 56×56 y estiraría el círculo de 34.
      leading: secundaria ? null : const Center(child: UserMenu()),
      title: secundaria ? Text(titulo!) : null,
      actions: [
        for (final (i, a) in acciones.indexed) ...[
          if (i > 0) const SizedBox(width: EqSpace.md),
          a,
        ],
        const SizedBox(width: EqSpace.md),
      ],
    );
  }
}

/// Alto que ocupa una [EqTopBar.flotante] (barra + zona del sistema) para
/// empujar el contenido que arranca debajo de ella.
double espacioBarra(BuildContext context) => kToolbarHeight + MediaQuery.paddingOf(context).top;
