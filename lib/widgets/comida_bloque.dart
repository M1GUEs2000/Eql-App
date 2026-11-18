import 'package:flutter/material.dart';

import '../data/api.dart';
import '../data/models.dart';
import '../theme/eq_tokens.dart';
import 'eq_basicos.dart';

/// Un tiempo de comida (Desayuno, Almuerzo...) con sus alimentos.
/// Deslizar un alimento a la derecha lo edita y a la izquierda lo elimina;
/// también se pueden marcar varios para usar el riel de selección del "+".
class ComidaBloque extends StatelessWidget {
  const ComidaBloque({
    super.key,
    required this.bloque,
    required this.seleccionados,
    required this.onToggle,
    required this.onToggleComida,
    required this.onAgregar,
    this.onEditar,
    this.onEliminar,
    this.editable = true,
    this.marcas = const {},
  });

  /// Alimentos que tocó la última optimización (id → nuevo o intercambio).
  final Map<int, TipoCambio> marcas;

  final ComidaIngesta bloque;
  final Set<int> seleccionados;
  final ValueChanged<ItemIngesta> onToggle;
  final ValueChanged<ItemIngesta>? onEditar;
  final ValueChanged<ItemIngesta>? onEliminar;

  /// Marca o desmarca todos los alimentos de la comida.
  final VoidCallback onToggleComida;
  final VoidCallback onAgregar;

  /// false si la dieta está bloqueada por el plan.
  final bool editable;

  @override
  Widget build(BuildContext context) {
    final todos =
        bloque.items.isNotEmpty &&
        bloque.items.every((i) => seleccionados.contains(i.id));
    final esquinas = BorderRadius.circular(EqRadius.base);
    return EqCard(
      padding: const EdgeInsets.fromLTRB(
        EqSpace.md,
        EqSpace.xs,
        EqSpace.xs,
        EqSpace.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Semantics(
              button: editable && bloque.items.isNotEmpty,
              selected: todos,
              hint: 'Seleccionar todos los alimentos de ${bloque.nombre}',
              child: InkWell(
                borderRadius: esquinas,
                onTap: editable && bloque.items.isNotEmpty
                    ? onToggleComida
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          bloque.nombre,
                          style: EqText.h4.copyWith(
                            color: EqColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        bloque.items.length == 1
                            ? '1 alimento'
                            : '${bloque.items.length} alimentos',
                        style: EqText.caption.copyWith(letterSpacing: 0),
                      ),
                      const SizedBox(width: EqSpace.xs),
                      _Marca(
                        marcado: todos,
                        visible: editable && bloque.items.isNotEmpty,
                      ),
                      // Compensa el padding horizontal de las filas para alinear los círculos.
                      const SizedBox(width: EqSpace.sm),
                    ],
                  ),
                ),
              ),
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
                  if (i > 0) Divider(color: EqColors.borderFaint),
                  _FilaItem(
                    item,
                    seleccionado: seleccionados.contains(item.id),
                    cambio: marcas[item.id],
                    onTap: editable ? () => onToggle(item) : null,
                    onEditar: editable && onEditar != null
                        ? () => onEditar!(item)
                        : null,
                    onEliminar: editable && onEliminar != null
                        ? () => onEliminar!(item)
                        : null,
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
  const _FilaItem(
    this.item, {
    required this.seleccionado,
    required this.onTap,
    this.onEditar,
    this.onEliminar,
    this.cambio,
  });

  final ItemIngesta item;
  final bool seleccionado;
  final VoidCallback? onTap;
  final VoidCallback? onEditar;
  final VoidCallback? onEliminar;

  /// Si la optimización lo agregó o lo intercambió, toda la fila va de su color.
  final TipoCambio? cambio;

  @override
  Widget build(BuildContext context) {
    final c = cambio;
    // Con marca, la esquina de arriba a la izquierda queda recta bajo la pestaña.
    final esquinas = c == null
        ? BorderRadius.circular(EqRadius.base)
        : const BorderRadius.only(
            topRight: Radius.circular(EqRadius.base),
            bottomLeft: Radius.circular(EqRadius.base),
            bottomRight: Radius.circular(EqRadius.base),
          );
    // Color opaco sobre la tarjeta para que al deslizar no se transparente el
    // fondo de Editar / Eliminar detrás del texto del alimento.
    final colorFila = c != null
        ? Color.alphaBlend(
            c.color.withValues(alpha: seleccionado ? 0.32 : 0.20),
            EqColors.surface,
          )
        : seleccionado
        ? Color.alphaBlend(
            EqColors.primary.withValues(alpha: 0.12),
            EqColors.surface,
          )
        : EqColors.surface;
    Widget fila = Material(
      color: colorFila,
      shape: RoundedRectangleBorder(
        borderRadius: esquinas,
        side: c == null
            ? BorderSide.none
            : BorderSide(color: c.color, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: esquinas,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: EqSpace.sm,
            vertical: EqSpace.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  item.nombre,
                  style: EqText.bodySm.copyWith(color: EqColors.onSurface),
                ),
              ),
              const SizedBox(width: EqSpace.sm),
              // Unidades largas ("1 bebida pequeña 16 onzas fluidas") se parten en
              // líneas en vez de quitarle el ancho al nombre.
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 104),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      item.cantidadTexto,
                      style: EqText.label,
                      textAlign: TextAlign.right,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.unidad != 'gramos')
                      Text(
                        '(${fmtNum(item.gramos, 1)} g)',
                        style: EqText.caption.copyWith(letterSpacing: 0),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: EqSpace.xs),
              // Círculo a la derecha: vacío o con check (editar va en el riel).
              _Marca(marcado: seleccionado, visible: onTap != null),
            ],
          ),
        ),
      ),
    );
    if (onEditar != null || onEliminar != null) {
      final direccion = onEditar != null && onEliminar != null
          ? DismissDirection.horizontal
          : onEditar != null
          ? DismissDirection.startToEnd
          : DismissDirection.endToStart;
      fila = Dismissible(
        key: ValueKey('alimento-swipe-${item.id}'),
        direction: direccion,
        confirmDismiss: (dir) async {
          if (dir == DismissDirection.startToEnd) {
            onEditar?.call();
          } else if (dir == DismissDirection.endToStart) {
            onEliminar?.call();
          }
          return false;
        },
        background: _FondoDeslizar(
          alineacion: Alignment.centerLeft,
          color: EqColors.primary,
          icono: Icons.edit_outlined,
          texto: 'Editar',
          esquinas: esquinas,
        ),
        secondaryBackground: _FondoDeslizar(
          alineacion: Alignment.centerRight,
          color: EqColors.error,
          icono: Icons.delete_outline,
          texto: 'Eliminar',
          esquinas: esquinas,
        ),
        child: fila,
      );
    }
    if (c == null) return fila;
    // Pestaña pegada al borde de arriba, como una carpeta.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: _EtiquetaCambio(c),
        ),
        fila,
      ],
    );
  }
}

/// Riel de acción que se descubre al deslizar un alimento:
/// hacia la derecha → Editar (verde), hacia la izquierda → Eliminar (rojo).
class _FondoDeslizar extends StatelessWidget {
  const _FondoDeslizar({
    required this.alineacion,
    required this.color,
    required this.icono,
    required this.texto,
    required this.esquinas,
  });

  final Alignment alineacion;
  final Color color;
  final IconData icono;
  final String texto;
  final BorderRadius esquinas;

  @override
  Widget build(BuildContext context) {
    final izquierda = alineacion == Alignment.centerLeft;
    return Container(
      alignment: alineacion,
      padding: const EdgeInsets.symmetric(horizontal: EqSpace.md),
      decoration: BoxDecoration(
        color: color,
        borderRadius: esquinas,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (izquierda) ...[
            Icon(icono, color: Colors.white, size: 20),
            const SizedBox(width: 6),
          ],
          Text(
            texto,
            style: EqText.label.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (!izquierda) ...[
            const SizedBox(width: 6),
            Icon(icono, color: Colors.white, size: 20),
          ],
        ],
      ),
    );
  }
}

/// Hueco de selección: círculo vacío, o con check si está marcado.
/// Invisible (pero ocupa su sitio) cuando no se puede seleccionar.
class _Marca extends StatelessWidget {
  const _Marca({required this.marcado, required this.visible});

  final bool marcado;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      child: visible
          ? Icon(
              marcado ? Icons.check_circle : Icons.radio_button_unchecked,
              color: marcado ? EqColors.primary : EqColors.textFaint,
              size: 20,
            )
          : null,
    );
  }
}

/// Qué hizo la optimización con un alimento.
enum TipoCambio {
  nuevo('Nuevo', EqColors.successText),
  // Dorado algo más oscuro que warning para que el blanco de la pestaña se lea.
  intercambio('Intercambio', Color(0xFFD9A514));

  const TipoCambio(this.texto, this.color);
  final String texto;
  final Color color;
}

/// Pestaña de carpeta sobre la fila: "Nuevo" (verde) o "Intercambio" (amarillo).
class _EtiquetaCambio extends StatelessWidget {
  const _EtiquetaCambio(this.cambio);

  final TipoCambio cambio;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 3, 14, 3),
      decoration: BoxDecoration(
        color: cambio.color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
      ),
      child: Text(
        cambio.texto,
        style: EqText.caption.copyWith(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
