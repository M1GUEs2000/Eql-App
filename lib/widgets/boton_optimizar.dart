import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/eq_tokens.dart';

/// Pastilla "Optimizar" con un contorno degradado que da varias vueltas
/// rápidas al aparecer (y al tocarla) y luego se queda latiendo.
class BotonOptimizar extends StatefulWidget {
  const BotonOptimizar({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<BotonOptimizar> createState() => _BotonOptimizarState();
}

class _BotonOptimizarState extends State<BotonOptimizar> with TickerProviderStateMixin {
  static const _vueltas = 3;

  late final _giro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
    ..addStatusListener((estado) {
      if (estado == AnimationStatus.completed) _pulso.repeat(reverse: true);
    });
  late final _angulo = CurvedAnimation(parent: _giro, curve: Curves.easeOutCubic);

  // Latido tras las vueltas: el halo verde crece y el botón se agranda un poco.
  late final _pulso = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  late final _latido = CurvedAnimation(parent: _pulso, curve: Curves.easeInOut);

  var _visible = false;

  // La pestaña vive en un IndexedStack: gira cada vez que se vuelve visible.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = Visibility.of(context);
    if (visible && !_visible) _girar();
    _visible = visible;
  }

  void _girar() {
    _pulso.value = 0;
    if (MediaQuery.disableAnimationsOf(context)) {
      _giro.value = 1;
      _pulso.stop();
    } else {
      _giro.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _latido.dispose();
    _pulso.dispose();
    _angulo.dispose();
    _giro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final forma = BorderRadius.circular(999);
    return AnimatedBuilder(
      animation: Listenable.merge([_angulo, _latido]),
      builder: (context, child) => Transform.scale(
        scale: 1 + 0.05 * _latido.value,
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: forma,
            boxShadow: [
              ...EqShadow.md,
              BoxShadow(
                color: EqColors.primaryLight.withValues(alpha: 0.55 * _latido.value),
                blurRadius: 6 + 14 * _latido.value,
                spreadRadius: 1 + 3 * _latido.value,
              ),
            ],
            gradient: SweepGradient(
              colors: [
                EqColors.primaryDark,
                EqColors.primary,
                EqColors.primarySoft,
                EqColors.primaryLight,
                EqColors.primaryDark,
              ],
              transform: GradientRotation(_angulo.value * _vueltas * 2 * math.pi),
            ),
          ),
          child: child,
        ),
      ),
      child: Material(
        color: EqColors.surface,
        borderRadius: forma,
        child: InkWell(
          borderRadius: forma,
          onTap: () {
            _girar();
            widget.onPressed();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, size: 18, color: EqColors.primary),
                const SizedBox(width: 6),
                Text(
                  'Optimizar',
                  style: EqText.label.copyWith(color: EqColors.primary, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
