import 'package:flutter/material.dart';

import '../data/api.dart';
import '../data/models.dart';
import '../theme/eq_tokens.dart';
import 'eq_basicos.dart';

/// Un tiempo de comida (Desayuno, Almuerzo...) con sus alimentos.
/// Mover y eliminar se hacen desde el riel de selección del "+".
class ComidaBloque extends StatelessWidget {
  const ComidaBloque({
    super.key,
    required this.bloque,
    required this.seleccionados,
    required this.onToggle,
    required this.onAgregar,
    required this.onEditar,
    this.editable = true,
  });

  final ComidaIngesta bloque;
  final Set<int> seleccionados;
  final ValueChanged<ItemIngesta> onToggle;
  final VoidCallback onAgregar;
  final ValueChanged<ItemIngesta> onEditar;

  /// false si la dieta está bloqueada por el plan.
  final bool editable;

  @override
  Widget build(BuildContext context) {
    return EqCard(
      padding: const EdgeInsets.fromLTRB(EqSpace.md, EqSpace.xs, EqSpace.xs, EqSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 10, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    bloque.nombre,
                    style: EqText.h4.copyWith(color: EqColors.primary, fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  bloque.items.length == 1 ? '1 alimento' : '${bloque.items.length} alimentos',
                  style: EqText.caption.copyWith(letterSpacing: 0),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Column(
              children: [
                if (bloque.items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text('Sin alimentos todavía', style: EqText.bodySm),
                  ),
                for (final (i, item) in bloque.items.indexed) ...[
                  if (i > 0) const Divider(color: EqColors.borderFaint),
                  _FilaItem(
                    item,
                    seleccionado: seleccionados.contains(item.id),
                    onTap: editable ? () => onToggle(item) : null,
                    onEditar: editable ? () => onEditar(item) : null,
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: editable ? onAgregar : null,
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilaItem extends StatelessWidget {
  const _FilaItem(this.item, {required this.seleccionado, required this.onTap, required this.onEditar});

  final ItemIngesta item;
  final bool seleccionado;
  final VoidCallback? onTap;
  final VoidCallback? onEditar;

  @override
  Widget build(BuildContext context) {
    final esquinas = BorderRadius.circular(EqRadius.base);
    return Material(
      color: seleccionado ? EqColors.primary.withValues(alpha: 0.12) : Colors.transparent,
      borderRadius: esquinas,
      child: InkWell(
        borderRadius: esquinas,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: EqSpace.sm, vertical: EqSpace.sm),
          child: Row(
            children: [
              if (seleccionado) ...[
                const Icon(Icons.check_circle, color: EqColors.primary, size: 18),
                const SizedBox(width: EqSpace.sm),
              ],
              Expanded(
                child: Text(item.nombre, style: EqText.bodySm.copyWith(color: EqColors.onSurface)),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(item.cantidadTexto, style: EqText.label),
                  if (item.unidad != 'gramos')
                    Text('(${fmtNum(item.gramos, 1)} g)', style: EqText.caption.copyWith(letterSpacing: 0)),
                ],
              ),
              const SizedBox(width: EqSpace.xs),
              IconButton(
                onPressed: onEditar,
                tooltip: 'Editar ${item.nombre}',
                icon: const Icon(Icons.edit_outlined, size: 18),
                color: EqColors.primary,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
