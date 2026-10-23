import 'package:flutter/material.dart';

import '../data/api.dart';
import '../data/models.dart';
import '../theme/eq_tokens.dart';
import 'eq_basicos.dart';

/// Hoja para cambiar cantidad y unidad de un registro de la ingesta
/// (PUT ingesta/alimentos/{id}). Devuelve true si se guardó.
Future<bool?> editarItem(BuildContext context, String fecha, ItemIngesta item) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _EditarItem(fecha, item),
  );
}

class _EditarItem extends StatefulWidget {
  const _EditarItem(this.fecha, this.item);

  final String fecha;
  final ItemIngesta item;

  @override
  State<_EditarItem> createState() => _EditarItemState();
}

class _EditarItemState extends State<_EditarItem> {
  late final _cantidad = TextEditingController(text: fmtNum(widget.item.cantidad));
  late var _unidad = widget.item.unidad;
  var _unidades = <Unidad>[];
  var _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarUnidades();
  }

  @override
  void dispose() {
    _cantidad.dispose();
    super.dispose();
  }

  Future<void> _cargarUnidades() async {
    try {
      final lista = await Api.get('ingesta/alimentos/${Uri.encodeComponent(widget.item.codigo)}/unidades') as List;
      if (mounted) setState(() => _unidades = [for (final u in lista) Unidad.desdeJson(u as Json)]);
    } on ApiError {
      // Sin el listado se puede cambiar igual la cantidad en la unidad actual.
    }
  }

  double? get _valor => double.tryParse(_cantidad.text.trim().replaceAll(',', '.'));

  double? get _gramos {
    final valor = _valor;
    final unidad = _unidades.where((u) => u.nombre == _unidad).firstOrNull;
    return valor == null || unidad == null ? null : valor * unidad.gramos;
  }

  Future<void> _guardar() async {
    final cantidad = _valor;
    if (cantidad == null || cantidad <= 0 || cantidad > 100000) {
      setState(() => _error = 'Ingrese una cantidad mayor a 0');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final cambiaUnidad = _unidad != widget.item.unidad;
      await Api.put('ingesta/alimentos/${widget.item.id}', {
        'fecha': widget.fecha,
        'accion': cambiaUnidad ? 'ActualizarCantidadYUnidad' : 'ActualizarCantidad',
        'cantidad': cantidad,
        if (cambiaUnidad) 'unidad': _unidad,
      });
      if (mounted) Navigator.of(context).pop(true);
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.detalle);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nombres = {widget.item.unidad, for (final u in _unidades) u.nombre};
    final gramos = _gramos;
    return Padding(
      // Sube la hoja por encima del teclado
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(EqSpace.lg, EqSpace.sm, EqSpace.lg, EqSpace.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: EqColors.borderLight, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: EqSpace.md),
              Text('Editar alimento', style: EqText.h3),
              Text(widget.item.nombre, style: EqText.bodySm),
              const SizedBox(height: EqSpace.lg),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: EqField(
                      etiqueta: 'Cantidad',
                      child: TextField(
                        controller: _cantidad,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: EqField(
                      etiqueta: 'Unidad',
                      child: DropdownButtonFormField<String>(
                        initialValue: _unidad,
                        isExpanded: true,
                        items: [
                          for (final n in nombres)
                            DropdownMenuItem(
                              value: n,
                              child: Text(n, overflow: TextOverflow.ellipsis),
                            ),
                        ],
                        onChanged: (u) => setState(() => _unidad = u!),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: EqSpace.sm),
              Text(
                gramos == null
                    ? 'Peso actual: ${fmtNum(widget.item.gramos, 1)} g'
                    : 'Equivale a ${fmtNum(gramos, 1)} g',
                style: EqText.bodySm,
              ),
              if (_error != null) ...[
                const SizedBox(height: EqSpace.sm),
                Text(_error!, style: EqText.bodySm.copyWith(color: EqColors.error)),
              ],
              const SizedBox(height: EqSpace.lg),
              FilledButton.icon(
                onPressed: _guardando ? null : _guardar,
                icon: const Icon(Icons.check),
                label: const Text('Guardar cambios'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
