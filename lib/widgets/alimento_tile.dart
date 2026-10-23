import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme/eq_tokens.dart';
import 'eq_basicos.dart';

class AlimentoTile extends StatelessWidget {
  const AlimentoTile({super.key, required this.alimento, required this.onTap, this.seleccionado, this.onInfo});

  final AlimentoBusqueda alimento;
  final VoidCallback onTap;

  /// null cuando la lista no permite seleccionar.
  final bool? seleccionado;
  final VoidCallback? onInfo;

  @override
  Widget build(BuildContext context) {
    final a = alimento;
    final marcado = seleccionado ?? false;
    return EqCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      sombra: false,
      color: marcado ? EqColors.primary.withValues(alpha: 0.06) : EqColors.surface,
      borde: marcado ? EqColors.primary : EqColors.borderLight,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: a.esPlato ? EqColors.primary : EqColors.indigo),
            child: Text(
              a.descripcion.isEmpty ? '?' : a.descripcion[0],
              style: EqText.label.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.descripcion, style: EqText.label.copyWith(fontSize: 16)),
                Text('${a.nombreTipo} · ${a.kcal.round()} kcal', style: EqText.bodySm.copyWith(fontSize: 13)),
              ],
            ),
          ),
          if (onInfo != null)
            IconButton(
              onPressed: onInfo,
              icon: const Icon(Icons.info_outline),
              color: EqColors.textMuted,
              tooltip: 'Ver detalle',
            ),
          if (seleccionado != null)
            Checkbox(value: marcado, onChanged: (_) => onTap())
          else
            const Icon(Icons.chevron_right, color: EqColors.textFaint),
        ],
      ),
    );
  }
}
