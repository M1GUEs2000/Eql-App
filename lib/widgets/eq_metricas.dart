import 'package:flutter/material.dart';

import '../theme/eq_tokens.dart';
import 'eq_basicos.dart';

/// Tarjeta de una cifra: icono en cuadro de color, título, valor y unidad.
/// Pensada para ir de a dos en [EqPares], con la misma altura que su vecina.
class EqMetrica extends StatelessWidget {
  const EqMetrica({
    super.key,
    required this.icono,
    required this.titulo,
    required this.valor,
    this.unidad,
    this.color,
    this.onTap,
  });

  final IconData icono;
  final String titulo;
  final String valor;
  final String? unidad;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? EqColors.primary;
    return EqCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(EqRadius.base),
            ),
            child: Icon(icono, size: 19, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            titulo.toUpperCase(),
            style: EqText.caption.copyWith(fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              valor,
              style: EqText.h3.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (unidad != null)
            Text(
              unidad!,
              style: EqText.caption.copyWith(letterSpacing: 0),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}

/// Reparte [hijos] en filas de dos columnas del mismo ancho; en cada fila las
/// dos tarjetas miden lo mismo de alto. Si sobra una, ocupa la mitad.
class EqPares extends StatelessWidget {
  const EqPares({super.key, required this.hijos, this.espacio = 12});

  final List<Widget> hijos;
  final double espacio;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < hijos.length; i += 2) ...[
          if (i > 0) SizedBox(height: espacio),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: hijos[i]),
                SizedBox(width: espacio),
                Expanded(
                  child: i + 1 < hijos.length ? hijos[i + 1] : const SizedBox(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Título de sección con un hilo verde corto a la izquierda.
class EqSeccion extends StatelessWidget {
  const EqSeccion(this.texto, {super.key, this.detalle});

  final String texto;
  final String? detalle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: EqColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            texto,
            style: EqText.h4.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        if (detalle != null) Text(detalle!, style: EqText.bodySm),
      ],
    );
  }
}
