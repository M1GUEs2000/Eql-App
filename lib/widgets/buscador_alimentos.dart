import 'package:flutter/material.dart';

import '../data/api.dart';
import '../data/models.dart';
import '../theme/eq_tokens.dart';
import 'alimento_tile.dart';
import 'eq_basicos.dart';
import 'popup_alimento.dart';

/// Filtros de GET ingesta/alimentos/buscar: tipo vacío, A o P, o soloDespensa.
enum _Pestana {
  todos('Platos y alimentos', ''),
  platos('Platos', 'P'),
  alimentos('Alimentos', 'A'),
  despensa('Mi despensa', '');

  const _Pestana(this.nombre, this.tipo);
  final String nombre;
  final String tipo;
}

typedef _Comparador = int Function(AlimentoBusqueda a, AlimentoBusqueda b);

_Comparador _mayorPrimero(double Function(AlimentoBusqueda) valor) =>
    (a, b) => valor(b).compareTo(valor(a));

final _ordenes = <String, _Comparador>{
  'A-Z': (a, b) => a.descripcion.compareTo(b.descripcion),
  'Z-A': (a, b) => b.descripcion.compareTo(a.descripcion),
  'Calorías': _mayorPrimero((a) => a.kcal),
  'Proteínas': _mayorPrimero((a) => a.proteinas),
  'Carbohidratos': _mayorPrimero((a) => a.carbohidratos),
  'Grasas': _mayorPrimero((a) => a.grasa),
};

/// Buscador, pestañas, orden y resultados. Lo usan la pantalla Buscar alimentos
/// y la hoja "Agregar" de la dieta; esta última pasa [seleccionados] para marcar.
class BuscadorAlimentos extends StatefulWidget {
  const BuscadorAlimentos({super.key, this.seleccionados, this.onToggle});

  final Set<AlimentoBusqueda>? seleccionados;
  final ValueChanged<AlimentoBusqueda>? onToggle;

  @override
  State<BuscadorAlimentos> createState() => _BuscadorAlimentosState();
}

class _BuscadorAlimentosState extends State<BuscadorAlimentos> {
  final _busqueda = TextEditingController();
  var _pestana = _Pestana.todos;
  var _orden = _ordenes.keys.first;
  List<AlimentoBusqueda>? _resultados;
  var _cargando = false;
  String? _error;

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    final termino = _busqueda.text.trim();
    FocusScope.of(context).unfocus();
    if (termino.isEmpty) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final lista = await Api.get('ingesta/alimentos/buscar', {
        'termino': termino,
        'tipo': _pestana.tipo,
        if (_pestana == _Pestana.despensa) 'soloDespensa': true,
      }) as List;
      if (!mounted) return;
      setState(() => _resultados = [for (final a in lista) AlimentoBusqueda.desdeJson(a as Json)]);
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.detalle);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _cambiarPestana(_Pestana p) {
    setState(() => _pestana = p);
    if (_busqueda.text.trim().isNotEmpty) _buscar();
  }

  @override
  Widget build(BuildContext context) {
    final seleccionados = widget.seleccionados;
    final resultados = [...?_resultados]..sort(_ordenes[_orden]);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(EqSpace.md, EqSpace.md, EqSpace.md, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _busqueda,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _buscar(),
                  decoration: const InputDecoration(hintText: 'Buscar alimentos...', prefixIcon: Icon(Icons.search)),
                ),
              ),
              const SizedBox(width: EqSpace.sm),
              FilledButton(onPressed: _cargando ? null : _buscar, child: const Text('Buscar')),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 32,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: EqSpace.md),
            itemCount: _Pestana.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: EqSpace.sm),
            itemBuilder: (_, i) {
              final p = _Pestana.values[i];
              return EqChip(texto: p.nombre, activo: p == _pestana, onTap: () => _cambiarPestana(p));
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(EqSpace.md, EqSpace.xs, EqSpace.md, 0),
          child: Row(
            children: [
              Text('Ordenar por:', style: EqText.bodySm),
              const SizedBox(width: EqSpace.sm),
              DropdownButton<String>(
                value: _orden,
                underline: const SizedBox.shrink(),
                style: EqText.bodySm.copyWith(color: EqColors.primary, fontWeight: FontWeight.w600),
                items: [for (final o in _ordenes.keys) DropdownMenuItem(value: o, child: Text(o))],
                onChanged: (o) => setState(() => _orden = o!),
              ),
              const Spacer(),
              if (_resultados != null)
                Text('${resultados.length} resultados', style: EqText.caption.copyWith(letterSpacing: 0)),
            ],
          ),
        ),
        Expanded(
          child: _cargando
              ? const Cargando()
              : _error != null
              ? ErrorCarga(_error!, onReintentar: _buscar)
              : _resultados == null
              ? Center(child: Text('Escribe un alimento o plato y toca Buscar', style: EqText.bodySm))
              : resultados.isEmpty
              ? Center(child: Text('No se encontraron alimentos', style: EqText.bodySm))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(EqSpace.md, EqSpace.sm, EqSpace.md, EqSpace.lg),
                  itemCount: resultados.length,
                  separatorBuilder: (_, _) => const SizedBox(height: EqSpace.sm),
                  itemBuilder: (context, i) {
                    final a = resultados[i];
                    if (seleccionados == null) {
                      return AlimentoTile(alimento: a, onTap: () => mostrarDetalleAlimento(context, a));
                    }
                    return AlimentoTile(
                      alimento: a,
                      seleccionado: seleccionados.contains(a),
                      onTap: () => widget.onToggle?.call(a),
                      onInfo: () => mostrarDetalleAlimento(context, a, conAgregar: false),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
