import 'package:flutter/material.dart';

import '../data/api.dart';
import '../data/cambios.dart';
import '../data/models.dart';
import '../theme/eq_tokens.dart';
import 'eq_basicos.dart';
import 'hoja_inferior.dart';

/// Ficha del alimento. Con [conAgregar] permite sumarlo a una comida de la
/// dieta abierta en "Mis dietas" (POST ingesta/alimentos).
Future<void> mostrarDetalleAlimento(BuildContext context, AlimentoBusqueda alimento, {bool conAgregar = true}) =>
    abrirHoja<void>(context, _DetalleAlimento(alimento, conAgregar: conAgregar));

String _gramos(double g) => '${fmtNum(g, 1)} g';

class _DetalleAlimento extends StatefulWidget {
  const _DetalleAlimento(this.alimento, {required this.conAgregar});

  final AlimentoBusqueda alimento;
  final bool conAgregar;

  @override
  State<_DetalleAlimento> createState() => _DetalleAlimentoState();
}

class _DetalleAlimentoState extends State<_DetalleAlimento> {
  final Ingesta? _ingesta = Cambios.ingestaActual.value;
  late String? _comida = _ingesta?.comidas.firstOrNull?.nombre;
  var _agregando = false;
  String? _error;

  bool get _puedeAgregar => _ingesta != null && !_ingesta.vacia && _ingesta.bloqueo == null;

  Future<void> _agregar() async {
    final ingesta = _ingesta!;
    setState(() {
      _agregando = true;
      _error = null;
    });
    try {
      await Api.post('ingesta/alimentos', {
        'codigo': widget.alimento.codigo,
        'tipo': widget.alimento.tipoIngesta,
        'comida': _comida,
        'fecha': ingesta.fecha,
      });
      if (!mounted) return;
      final mensajero = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      mensajero.showSnackBar(SnackBar(content: Text('${widget.alimento.descripcion} agregado a $_comida')));
      Cambios.avisar(fechaIngesta: ingesta.fecha);
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.detalle);
    } finally {
      if (mounted) setState(() => _agregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.alimento;
    final ingesta = _ingesta;
    return HojaInferior(
      titulo: a.descripcion,
      subtitulo: '${a.nombreTipo} · valores por porción',
      pie: !widget.conAgregar
          ? null
          : _puedeAgregar
          ? PieFormulario(texto: 'Agregar a $_comida', onPressed: _agregando ? null : _agregar, error: _error)
          : Text(
              'Para agregarlo, abre o crea una dieta en "Mis dietas".',
              textAlign: TextAlign.center,
              style: EqText.bodySm,
            ),
      child: ListView(
        padding: const EdgeInsets.all(EqSpace.lg),
        children: [
          EqCard(
            sombra: false,
            color: EqColors.primary.withValues(alpha: 0.08),
            borde: EqColors.primary.withValues(alpha: 0.3),
            child: Row(
              children: [
                const Icon(Icons.bolt, color: EqColors.primary),
                const SizedBox(width: EqSpace.sm),
                Text('Energía', style: EqText.label),
                const Spacer(),
                Text('${a.kcal.round()} kcal', style: EqText.h3.copyWith(color: EqColors.primaryDark)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Macro(
                  icono: Icons.egg_alt_outlined,
                  nombre: 'Proteínas',
                  valor: _gramos(a.proteinas),
                  color: EqColors.indigo,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Macro(
                  icono: Icons.bakery_dining_outlined,
                  nombre: 'Carbohidratos',
                  valor: _gramos(a.carbohidratos),
                  color: EqColors.warningText,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Macro(
                  icono: Icons.water_drop_outlined,
                  nombre: 'Grasas',
                  valor: _gramos(a.grasa),
                  color: EqColors.primary,
                ),
              ),
            ],
          ),
          if (widget.conAgregar && _puedeAgregar) ...[
            const SizedBox(height: EqSpace.lg),
            Text(
              'Se agrega a "${ingesta!.nombre.isEmpty ? fechaVista(ingesta.fecha) : ingesta.nombre}"',
              style: EqText.bodySm,
            ),
            const SizedBox(height: EqSpace.sm),
            EqField(
              etiqueta: 'Comida',
              child: DropdownButtonFormField<String>(
                initialValue: _comida,
                items: [for (final c in ingesta.comidas) DropdownMenuItem(value: c.nombre, child: Text(c.nombre))],
                onChanged: (c) => setState(() => _comida = c),
              ),
            ),
            const SizedBox(height: EqSpace.sm),
            Text(
              'Entra con 1 porción de su unidad base; luego puedes cambiar la cantidad desde la dieta.',
              style: EqText.caption.copyWith(letterSpacing: 0, color: EqColors.textFaint),
            ),
          ],
        ],
      ),
    );
  }
}

class _Macro extends StatelessWidget {
  const _Macro({required this.icono, required this.nombre, required this.valor, required this.color});

  final IconData icono;
  final String nombre;
  final String valor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return EqCard(
      sombra: false,
      color: color.withValues(alpha: 0.08),
      borde: color.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: color),
          const SizedBox(height: EqSpace.sm),
          Text(nombre, style: EqText.bodySm, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(valor, style: EqText.h4.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
