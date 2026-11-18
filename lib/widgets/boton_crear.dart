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
    this.insignia = 0,
  });

  final IconData icono;
  final String etiqueta;
  final Color color;
  final VoidCallback onTap;

  /// Número en la esquina del botón; solo se muestra desde 2.
  final int insignia;
}

/// Deja flotando arriba a la derecha de [child] el botón opcional [encima]
/// (ej. Optimizar) y el riel de selección; se quedan fijos durante el scroll.
/// El menú de tres rayas de la pestaña va en la navbar ([BotonMenu]).
class ConBotonCrear extends StatelessWidget {
  const ConBotonCrear({
    super.key,
    required this.child,
    this.encima,
    this.seleccionados = 0,
    this.accionesSeleccion = const [],
    this.onCancelarSeleccion,
  });

  /// La X junto al conteo: desmarca todo.
  final VoidCallback? onCancelarSeleccion;

  /// Alimentos elegidos; con alguno se abre el riel de [accionesSeleccion].
  final int seleccionados;
  final List<AccionFlotante> accionesSeleccion;

  final Widget child;

  /// Botón opcional que va sobre el riel.
  final Widget? encima;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: child),
        Positioned(
          top: MediaQuery.paddingOf(context).top,
          right: EqSpace.md,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              ?encima,
              _RielSeleccion(
                cantidad: seleccionados,
                acciones: accionesSeleccion,
                onCancelar: onCancelarSeleccion,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Círculo verde de tres rayas que despliega las [acciones] de la pestaña
/// (crear, eliminar…).
class BotonMenu extends StatefulWidget {
  const BotonMenu({
    super.key,
    required this.acciones,
    this.tamano = 34,
    this.icono = Icons.menu,
    this.tooltip = 'Más opciones',
  });

  final List<AccionMenu> acciones;
  final double tamano;

  /// Icono en reposo; abierto muestra una X.
  final IconData icono;
  final String tooltip;

  @override
  State<BotonMenu> createState() => _BotonMenuState();
}

class _BotonMenuState extends State<BotonMenu> {
  var _abierto = false;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: Material(
        color: EqColors.surface,
        shape: CircleBorder(side: BorderSide(color: EqColors.primary, width: 1.5)),
        clipBehavior: Clip.antiAlias,
        child: PopupMenuButton<int>(
          tooltip: widget.tooltip,
          style: IconButton.styleFrom(
            fixedSize: Size.square(widget.tamano),
            minimumSize: Size.square(widget.tamano),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: EdgeInsets.zero,
            shape: const CircleBorder(),
          ),
          // Debajo del botón, alineado a su borde derecho
          offset: Offset(0, widget.tamano + 8),
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
              _abierto ? Icons.close : widget.icono,
              key: ValueKey(_abierto),
              color: EqColors.primary,
              size: 20,
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
  const _RielSeleccion({
    required this.cantidad,
    required this.acciones,
    this.onCancelar,
  });

  final int cantidad;
  final List<AccionFlotante> acciones;
  final VoidCallback? onCancelar;

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

  /// Con letra grande: popup con todas las acciones de la selección.
  Future<void> _abrirOpciones() async {
    final elegida = await showDialog<AccionFlotante>(
      context: context,
      builder: (_) => _DialogoSeleccion(
        cantidad: widget.cantidad,
        acciones: [
          ...widget.acciones,
          if (widget.onCancelar != null)
            AccionFlotante(
              icono: Icons.close,
              etiqueta: 'Cancelar selección',
              color: EqColors.textMuted,
              onTap: widget.onCancelar!,
            ),
        ],
      ),
    );
    elegida?.onTap();
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
        // Desde letra 1.3 el riel no cabe: solo el botón "Opciones" y la X.
        final compacto = MediaQuery.textScalerOf(context).scale(1) >= 1.3;
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Stack(
            children: [
              if (!compacto)
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
                    etiqueta: compacto
                        ? _BotonOpciones(_cantidadMostrada, _abrirOpciones)
                        : _Conteo(_cantidadMostrada),
                    // La X, con la misma forma que los demás botones del riel.
                    marca: widget.onCancelar == null
                        ? const SizedBox.shrink()
                        : _BotonAccion(
                            AccionFlotante(
                              icono: Icons.close,
                              etiqueta: 'Cancelar selección',
                              color: EqColors.textMuted,
                              onTap: widget.onCancelar!,
                            ),
                          ),
                  ),
                  if (!compacto)
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

/// Píldora que reemplaza al conteo con letra grande; abre [_DialogoSeleccion].
class _BotonOpciones extends StatelessWidget {
  const _BotonOpciones(this.cantidad, this.onTap);

  final int cantidad;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final forma = BorderRadius.circular(EqRadius.lg);
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: forma, boxShadow: EqShadow.base),
      child: Material(
        color: EqColors.primaryDark,
        borderRadius: forma,
        child: InkWell(
          borderRadius: forma,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      cantidad == 1
                          ? '1 seleccionado'
                          : '$cantidad seleccionados',
                      style: EqText.caption.copyWith(
                        color: EqColors.primarySoft,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Opciones de\nla selección',
                      style: EqText.label.copyWith(
                        fontSize: 13,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 6),
                const Icon(Icons.expand_more, size: 18, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Popup con el conteo y todas las acciones del riel; devuelve la elegida.
class _DialogoSeleccion extends StatelessWidget {
  const _DialogoSeleccion({required this.cantidad, required this.acciones});

  final int cantidad;
  final List<AccionFlotante> acciones;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: EqColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(EqRadius.lg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: EqSpace.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  EqSpace.md,
                  0,
                  EqSpace.md,
                  EqSpace.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Opciones de la selección',
                      style: EqText.label.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cantidad == 1
                          ? '1 seleccionado'
                          : '$cantidad seleccionados',
                      style: EqText.bodySm,
                    ),
                  ],
                ),
              ),
              for (final a in acciones) _ItemDialogo(a),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemDialogo extends StatelessWidget {
  const _ItemDialogo(this.accion);

  final AccionFlotante accion;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).pop(accion),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: EqSpace.md,
            vertical: 8,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accion.color.withValues(alpha: 0.12),
                ),
                child: Icon(accion.icono, size: 22, color: accion.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  accion.etiqueta,
                  style: EqText.label.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              if (accion.insignia > 1)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: accion.color,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${accion.insignia}',
                    style: EqText.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ),
            ],
          ),
        ),
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
    final insignia = accion.insignia;
    return Semantics(
      button: true,
      label: insignia > 1 ? '${accion.etiqueta} ($insignia)' : accion.etiqueta,
      child: Badge(
        isLabelVisible: insignia > 1,
        label: Text('$insignia'),
        backgroundColor: accion.color,
        textColor: Colors.white,
        offset: const Offset(2, -2),
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
      ),
    );
  }
}

/// Botón redondo de 34 px para la navbar: relleno verde (crear) o solo
/// contorno de [color] (eliminar). Sin [onPressed] se ve atenuado.
class BotonCircular extends StatelessWidget {
  const BotonCircular({
    super.key,
    required this.icono,
    required this.tooltip,
    required this.onPressed,
    this.relleno = true,
    this.color,
    this.tamano = 34,
  });

  final IconData icono;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool relleno;
  final Color? color;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final c = color ?? EqColors.primary;
    return Opacity(
      opacity: onPressed == null ? 0.4 : 1,
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        style: IconButton.styleFrom(
          fixedSize: Size.square(tamano),
          minimumSize: Size.square(tamano),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: EdgeInsets.zero,
          shape: const CircleBorder(),
          // Fondo sólido y borde de color: legible sobre cualquier cosa que
          // pase por detrás de la barra flotante.
          backgroundColor: EqColors.surface,
          disabledBackgroundColor: EqColors.surface,
          side: BorderSide(color: c, width: 1.5),
        ),
        icon: Icon(icono, size: 20, color: c),
      ),
    );
  }
}
