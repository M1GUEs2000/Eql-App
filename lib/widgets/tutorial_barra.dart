import 'package:flutter/material.dart';

import '../theme/eq_tokens.dart';

/// Un paso del tutorial: qué pestaña de la barra inferior se resalta y qué se dice.
class PasoTutorial {
  const PasoTutorial(this.pestana, this.icono, this.titulo, this.texto);

  final int pestana;
  final IconData icono;
  final String titulo;
  final String texto;
}

/// Capa que oscurece la pantalla y deja ver solo una pestaña de la barra
/// inferior, con una tarjeta que explica para qué sirve.
class TutorialBarra extends StatefulWidget {
  const TutorialBarra({
    super.key,
    required this.barra,
    required this.pestanas,
    required this.pasos,
    required this.onTerminar,
  });

  /// Key de la barra inferior; sus pestañas se reparten el ancho en partes iguales.
  final GlobalKey barra;
  final int pestanas;
  final List<PasoTutorial> pasos;
  final VoidCallback onTerminar;

  @override
  State<TutorialBarra> createState() => _TutorialBarraState();
}

class _TutorialBarraState extends State<TutorialBarra> {
  var _i = 0;

  // La capa ocupa toda la pantalla desde (0, 0): coordenadas globales = locales.
  Rect? _hueco() {
    final caja = widget.barra.currentContext?.findRenderObject() as RenderBox?;
    if (caja == null || !caja.hasSize) return null;
    final origen = caja.localToGlobal(Offset.zero);
    final ancho = caja.size.width / widget.pestanas;
    final centro = Offset(
      origen.dx + ancho * (widget.pasos[_i].pestana + 0.5),
      origen.dy + caja.size.height / 2,
    );
    return Rect.fromCircle(center: centro, radius: 30);
  }

  void _siguiente() {
    if (_i + 1 >= widget.pasos.length) {
      widget.onTerminar();
    } else {
      setState(() => _i++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hueco = _hueco();
    if (hueco == null) return const SizedBox.shrink();
    final paso = widget.pasos[_i];
    final ultimo = _i == widget.pasos.length - 1;
    final alto = MediaQuery.sizeOf(context).height;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Tocar en cualquier parte equivale a "Siguiente"; la app de
          // debajo no recibe toques mientras dura el tutorial.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _siguiente,
              child: TweenAnimationBuilder<Rect?>(
                tween: RectTween(begin: hueco, end: hueco),
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOut,
                builder: (context, rect, _) {
                  final r = rect ?? hueco;
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(painter: _Sombra(r)),
                      ),
                      // La pestaña resaltada, encendida sobre la sombra.
                      Positioned.fromRect(
                        rect: r,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: EqColors.surface,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.6),
                                blurRadius: 18,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Icon(
                            paso.icono,
                            color: EqColors.primary,
                            size: 28,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          Positioned(
            left: EqSpace.lg,
            right: EqSpace.lg,
            bottom: alto - hueco.top + EqSpace.md,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Container(
                key: ValueKey(_i),
                padding: const EdgeInsets.all(EqSpace.md),
                decoration: BoxDecoration(
                  color: EqColors.surface,
                  borderRadius: BorderRadius.circular(EqRadius.lg),
                  boxShadow: EqShadow.lg,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_i + 1} de ${widget.pasos.length}',
                      style: EqText.caption.copyWith(color: EqColors.primary),
                    ),
                    const SizedBox(height: EqSpace.xs),
                    Text(paso.titulo, style: EqText.h3),
                    const SizedBox(height: EqSpace.xs),
                    Text(paso.texto, style: EqText.bodySm),
                    const SizedBox(height: EqSpace.md),
                    Row(
                      children: [
                        if (!ultimo)
                          TextButton(
                            onPressed: widget.onTerminar,
                            child: const Text('Saltar'),
                          ),
                        const Spacer(),
                        FilledButton(
                          onPressed: _siguiente,
                          child: Text(ultimo ? 'Entendido' : 'Siguiente'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fondo oscuro con un círculo recortado donde va la pestaña resaltada.
class _Sombra extends CustomPainter {
  const _Sombra(this.hueco);

  final Rect hueco;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.black.withValues(alpha: 0.75),
    );
    canvas.drawOval(hueco, Paint()..blendMode = BlendMode.clear);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Sombra anterior) => anterior.hueco != hueco;
}
