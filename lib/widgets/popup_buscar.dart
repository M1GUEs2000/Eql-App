import 'package:flutter/material.dart';

import '../data/models.dart';
import 'buscador_alimentos.dart';
import 'hoja_inferior.dart';

/// Hoja para elegir varios alimentos y sumarlos a un tiempo de comida.
Future<List<AlimentoBusqueda>?> mostrarBuscadorParaAgregar(BuildContext context, String bloque) =>
    abrirHoja<List<AlimentoBusqueda>>(context, _BuscadorParaAgregar(bloque));

class _BuscadorParaAgregar extends StatefulWidget {
  const _BuscadorParaAgregar(this.bloque);

  final String bloque;

  @override
  State<_BuscadorParaAgregar> createState() => _BuscadorParaAgregarState();
}

class _BuscadorParaAgregarState extends State<_BuscadorParaAgregar> {
  final _seleccionados = <AlimentoBusqueda>{};

  void _toggle(AlimentoBusqueda a) {
    setState(() {
      if (!_seleccionados.remove(a)) _seleccionados.add(a);
    });
  }

  @override
  Widget build(BuildContext context) {
    return HojaInferior(
      titulo: 'Agregar alimentos',
      subtitulo: 'Se agregarán a ${widget.bloque}',
      pie: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: _seleccionados.isEmpty ? null : () => Navigator.of(context).pop(_seleccionados.toList()),
          child: Text('Agregar (${_seleccionados.length})'),
        ),
      ),
      child: BuscadorAlimentos(seleccionados: _seleccionados, onToggle: _toggle),
    );
  }
}
