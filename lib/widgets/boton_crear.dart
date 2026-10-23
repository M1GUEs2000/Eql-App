import 'package:flutter/material.dart';

import '../theme/eq_tokens.dart';

/// Opción del menú de tres rayas.
class AccionMenu {
  const AccionMenu({
    required this.icono,
    required this.etiqueta,
    required this.onTap,
    this.color,
    this.habilitada = true,
  });

  final IconData icono;
  final String etiqueta;
  final VoidCallback onTap;
  final Color? color;
  final bool habilitada;
}

/// Pone un botón verde de tres rayas flotando arriba a la derecha de [child];
/// se queda fijo mientras el contenido hace scroll y despliega el menú con las
/// [acciones] de la pestaña (crear, eliminar…).
class ConBotonCrear extends StatefulWidget {
  const ConBotonCrear({
    super.key,
    required this.acciones,
    required this.child,
    this.encima,
  });

  final List<AccionMenu> acciones;
  final Widget child;

  /// Botón opcional que va justo encima del menú.
  final Widget? encima;

  @override
  State<ConBotonCrear> createState() => _ConBotonCrearState();
}

class _ConBotonCrearState extends State<ConBotonCrear> {
  var _abierto = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: widget.child),
        Positioned(
          top: EqSpace.md,
          right: EqSpace.md,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.encima != null) ...[
                widget.encima!,
                const SizedBox(height: 12),
              ],
              _boton(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _boton() {
    return DecoratedBox(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: EqShadow.lg,
      ),
      child: Material(
        color: EqColors.primary,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: PopupMenuButton<int>(
          tooltip: 'Más opciones',
          style: IconButton.styleFrom(
            fixedSize: const Size(56, 56),
            shape: const CircleBorder(),
          ),
          // Debajo del botón, alineado a su borde derecho
          offset: const Offset(0, 64),
          color: EqColors.surface,
          surfaceTintColor: Colors.transparent,
          shadowColor: EqColors.primaryDark.withValues(alpha: 0.28),
          elevation: 12,
          constraints: const BoxConstraints(minWidth: 232),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(EqRadius.lg),
            side: const BorderSide(color: EqColors.borderLight),
          ),
          popUpAnimationStyle: const AnimationStyle(
            duration: Duration(milliseconds: 220),
            reverseDuration: Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
          ),
          onOpened: () => setState(() => _abierto = true),
          onCanceled: () => setState(() => _abierto = false),
          onSelected: (i) {
            setState(() => _abierto = false);
            widget.acciones[i].onTap();
          },
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (hijo, anim) => RotationTransition(
              turns: Tween(begin: 0.85, end: 1.0).animate(anim),
              child: FadeTransition(opacity: anim, child: hijo),
            ),
            child: Icon(
              _abierto ? Icons.close : Icons.menu,
              key: ValueKey(_abierto),
              color: Colors.white,
              size: 26,
            ),
          ),
          itemBuilder: (_) => [
            for (final (i, a) in widget.acciones.indexed) ...[
              if (i > 0) const PopupMenuDivider(height: 1),
              PopupMenuItem<int>(
                value: i,
                enabled: a.habilitada,
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: EqSpace.md),
                child: _Opcion(a),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Opcion extends StatelessWidget {
  const _Opcion(this.accion);

  final AccionMenu accion;

  @override
  Widget build(BuildContext context) {
    final color = accion.color ?? EqColors.primaryDark;
    final fondo = accion.color == null
        ? EqColors.primarySoft
        : accion.color!.withValues(alpha: 0.12);
    return Opacity(
      opacity: accion.habilitada ? 1 : 0.4,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: fondo,
              borderRadius: BorderRadius.circular(EqRadius.md),
            ),
            child: Icon(accion.icono, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              accion.etiqueta,
              style: EqText.label.copyWith(
                fontWeight: FontWeight.w600,
                color: EqColors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
