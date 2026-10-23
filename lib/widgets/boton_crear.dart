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

/// Acción del riel de selección que cuelga bajo el "+".
class AccionFlotante {
  const AccionFlotante({
    required this.icono,
    required this.etiqueta,
    required this.color,
    required this.onTap,
  });

  final IconData icono;
  final String etiqueta;
  final Color color;
  final VoidCallback onTap;
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
    this.seleccionados = 0,
    this.accionesSeleccion = const [],
  });

  /// Alimentos elegidos; con alguno, bajo el botón se abre el riel de
  /// [accionesSeleccion].
  final int seleccionados;
  final List<AccionFlotante> accionesSeleccion;

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
              _RielSeleccion(
                cantidad: widget.seleccionados,
                acciones: widget.accionesSeleccion,
              ),
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
            side: BorderSide(color: EqColors.borderLight),
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
    final color = accion.color ?? EqColors.acento;
    final fondo = accion.color == null
        ? EqColors.acentoFondo
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

// Ancho del "+": el riel y los botones se centran en esa columna.
const _anchoColumna = 56.0;

/// Hilo verde que baja desde el "+" con el conteo y las acciones colgadas.
/// Se abre en cascada de arriba abajo y se recoge al revés.
class _RielSeleccion extends StatefulWidget {
  const _RielSeleccion({required this.cantidad, required this.acciones});

  final int cantidad;
  final List<AccionFlotante> acciones;

  @override
  State<_RielSeleccion> createState() => _RielSeleccionState();
}

class _RielSeleccionState extends State<_RielSeleccion>
    with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
    reverseDuration: const Duration(milliseconds: 240),
    value: _abierto ? 1 : 0,
  );

  // Se conserva durante el cierre para que el conteo no salte a 0 mientras se recoge.
  late int _cantidadMostrada = widget.cantidad;

  bool get _abierto => widget.cantidad > 0 && widget.acciones.isNotEmpty;

  @override
  void didUpdateWidget(_RielSeleccion anterior) {
    super.didUpdateWidget(anterior);
    if (_abierto) _cantidadMostrada = widget.cantidad;
    if (MediaQuery.disableAnimationsOf(context)) {
      _anim.value = _abierto ? 1 : 0;
    } else if (_abierto) {
      _anim.forward();
    } else {
      _anim.reverse();
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  /// Progreso 0..1 del tramo [inicio, fin] de la animación, con [curva].
  double _tramo(
    double inicio,
    double fin, [
    Curve curva = Curves.easeOutCubic,
  ]) {
    final t = ((_anim.value - inicio) / (fin - inicio)).clamp(0.0, 1.0);
    return curva.transform(t);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        if (_anim.isDismissed) return const SizedBox.shrink();
        final paso = 0.55 / widget.acciones.length;
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Stack(
            children: [
              // El hilo: crece desde el "+" hacia abajo antes que los botones.
              Positioned(
                top: 0,
                bottom: 22,
                right: _anchoColumna / 2 - 1,
                width: 2,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: FractionallySizedBox(
                    heightFactor: _tramo(0, 0.6),
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        color: EqColors.primarySoft,
                        borderRadius: BorderRadius.all(Radius.circular(1)),
                      ),
                    ),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Fila(
                    progreso: _tramo(0, 0.35),
                    etiqueta: _Conteo(_cantidadMostrada),
                    marca: const _Nudo(),
                  ),
                  for (final (i, accion) in widget.acciones.indexed) ...[
                    const SizedBox(height: 10),
                    _Fila(
                      progreso: _tramo(0.2 + i * paso, 0.6 + i * paso),
                      escala: _tramo(
                        0.2 + i * paso,
                        0.6 + i * paso,
                        Curves.easeOutBack,
                      ),
                      etiqueta: _Etiqueta(accion),
                      marca: _BotonAccion(accion),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Una parada del riel: etiqueta a la izquierda, marca centrada sobre el hilo.
class _Fila extends StatelessWidget {
  const _Fila({
    required this.progreso,
    required this.etiqueta,
    required this.marca,
    double? escala,
  }) : escala = escala ?? progreso;

  final double progreso;
  final double escala;
  final Widget etiqueta;
  final Widget marca;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Opacity(
          opacity: progreso,
          child: Transform.translate(
            offset: Offset(18 * (1 - progreso), 0),
            child: etiqueta,
          ),
        ),
        const SizedBox(width: EqSpace.sm),
        SizedBox(
          width: _anchoColumna,
          child: Center(
            child: Transform.scale(scale: escala, child: marca),
          ),
        ),
      ],
    );
  }
}

class _Conteo extends StatelessWidget {
  const _Conteo(this.cantidad);

  final int cantidad;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: EqColors.primaryDark,
        borderRadius: BorderRadius.circular(999),
        boxShadow: EqShadow.base,
      ),
      child: Text(
        cantidad == 1 ? '1 seleccionado' : '$cantidad seleccionados',
        style: EqText.caption.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _Nudo extends StatelessWidget {
  const _Nudo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: EqColors.primary,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: EqShadow.base,
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta(this.accion);

  final AccionFlotante accion;

  @override
  Widget build(BuildContext context) {
    final forma = BorderRadius.circular(999);
    return Material(
      color: EqColors.surface,
      borderRadius: forma,
      elevation: 0,
      child: InkWell(
        borderRadius: forma,
        onTap: accion.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: forma,
            border: Border.all(color: EqColors.borderLight),
            boxShadow: EqShadow.base,
          ),
          child: Text(
            accion.etiqueta,
            style: EqText.label.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _BotonAccion extends StatelessWidget {
  const _BotonAccion(this.accion);

  final AccionFlotante accion;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: accion.etiqueta,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: EqColors.surface,
          border: Border.all(color: accion.color.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: accion.color.withValues(alpha: 0.28),
              offset: const Offset(0, 4),
              blurRadius: 12,
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: accion.onTap,
            child: Icon(accion.icono, color: accion.color, size: 22),
          ),
        ),
      ),
    );
  }
}
