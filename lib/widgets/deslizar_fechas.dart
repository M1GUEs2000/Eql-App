import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Contenido que se arrastra de lado para pasar a otra fecha.
///
/// Mientras se arrastra sigue al dedo; al soltar más allá de un cuarto del
/// ancho (o con un gesto rápido) sale por ese lado, se llama a [onCambiar] y,
/// cuando llega el contenido nuevo ([clave] distinta), entra por el lado
/// opuesto. Si [puede] dice que no hay fecha en esa dirección, resiste como un
/// elástico y vuelve. Izquierda = siguiente (paso 1), derecha = anterior (-1).
class DeslizarFechas extends StatefulWidget {
  const DeslizarFechas({
    super.key,
    required this.clave,
    required this.puede,
    required this.onCambiar,
    required this.child,
  });

  /// Identifica lo que se muestra (la fecha); al cambiar se anima la entrada.
  final Object clave;
  final bool Function(int paso) puede;
  final Future<void> Function(int paso) onCambiar;
  final Widget child;

  @override
  State<DeslizarFechas> createState() => _DeslizarFechasState();
}

class _DeslizarFechasState extends State<DeslizarFechas>
    with SingleTickerProviderStateMixin {
  /// Desplazamiento en fracciones del ancho: -1 fuera a la izquierda, 1 a la derecha.
  late final _x = AnimationController.unbounded(vsync: this);
  var _ancho = 1.0;

  /// Paso en curso mientras se espera el contenido nuevo; 0 si no hay cambio.
  var _pendiente = 0;

  bool get _sinAnimar => MediaQuery.disableAnimationsOf(context);

  @override
  void dispose() {
    _x.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(DeslizarFechas old) {
    super.didUpdateWidget(old);
    if (old.clave == widget.clave) return;
    final paso = _pendiente;
    _pendiente = 0;
    if (paso == 0 || _sinAnimar) {
      _x.value = 0;
      return;
    }
    // Lo nuevo entra desde el lado opuesto al que salió lo anterior.
    _x.value = paso.toDouble();
    _x.animateTo(
      0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _arrastrar(DragUpdateDetails d) {
    if (_pendiente != 0) return;
    _x.stop();
    var dx = (d.primaryDelta ?? 0) / _ancho;
    final siguiente = _x.value + dx;
    // Hacia un lado sin fechas el arrastre cuesta más y no pasa de un 12 %.
    if (siguiente != 0 && !widget.puede(siguiente < 0 ? 1 : -1)) {
      dx *= 0.35;
      _x.value = (_x.value + dx).clamp(-0.12, 0.12);
      return;
    }
    _x.value = siguiente;
  }

  Future<void> _soltar(DragEndDetails d) async {
    if (_pendiente != 0) return;
    final v = (d.primaryVelocity ?? 0) / _ancho;
    final x = _x.value;
    // Un gesto rápido decide por su sentido; uno lento, por cuánto se arrastró.
    final paso = v.abs() > 1.2 ? (v < 0 ? 1 : -1) : (x < 0 ? 1 : -1);
    final pasa = (x.abs() > 0.25 || v.abs() > 1.2) && widget.puede(paso);
    if (!pasa) {
      _x.animateTo(
        0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutBack,
      );
      return;
    }
    _pendiente = paso;
    if (!_sinAnimar) {
      await _x.animateTo(
        -paso.toDouble(),
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeIn,
      );
    }
    if (!mounted) return;
    setState(() {}); // muestra el indicador de carga
    try {
      await widget.onCambiar(paso);
    } finally {
      // Si no llegó contenido nuevo (error), lo de antes vuelve a su sitio.
      if (mounted && _pendiente != 0) {
        setState(() => _pendiente = 0);
        _x.animateTo(
          0,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth.isFinite && c.maxWidth > 0) _ancho = c.maxWidth;
        return GestureDetector(
          onHorizontalDragUpdate: _arrastrar,
          onHorizontalDragEnd: _soltar,
          child: Stack(
            children: [
              AnimatedBuilder(
                animation: _x,
                builder: (context, hijo) => Transform.translate(
                  offset: Offset(_x.value * _ancho, 0),
                  child: Opacity(
                    opacity: 1 - math.min(_x.value.abs(), 1) * 0.6,
                    child: hijo,
                  ),
                ),
                child: widget.child,
              ),
              if (_pendiente != 0)
                const Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: SizedBox.square(
                        dimension: 28,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
