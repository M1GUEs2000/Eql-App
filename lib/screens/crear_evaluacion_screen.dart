import 'package:flutter/material.dart';

import '../data/api.dart';
import '../data/cambios.dart';
import '../data/models.dart';
import '../theme/eq_tokens.dart';
import '../widgets/eq_basicos.dart';
import '../widgets/hoja_inferior.dart';

/// Hoja "Nueva evaluación"; se abre con [abrirHoja]. La evaluación sale de un
/// plan de gasto calórico: vista previa con GET evaluacion/previa-gasto y
/// guardado con POST evaluacion/desde-gasto.
class CrearEvaluacionScreen extends StatefulWidget {
  const CrearEvaluacionScreen({super.key});

  @override
  State<CrearEvaluacionScreen> createState() => _CrearEvaluacionScreenState();
}

class _CrearEvaluacionScreenState extends State<CrearEvaluacionScreen> {
  List<Opcion>? _planes;
  String? _fecha;
  Evaluacion? _previa;
  var _cargandoPrevia = false;
  var _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarPlanes();
  }

  Future<void> _cargarPlanes() async {
    try {
      final plan = PlanGasto.desdeJson(await Api.get('gasto-calorico') as Json);
      if (!mounted) return;
      setState(() => _planes = plan.fechas);
      if (plan.fechas.isNotEmpty) _elegir(plan.fechas.first.valor);
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.detalle);
    }
  }

  Future<void> _elegir(String fecha) async {
    setState(() {
      _fecha = fecha;
      _previa = null;
      _cargandoPrevia = true;
      _error = null;
    });
    try {
      final datos =
          await Api.get('evaluacion/previa-gasto', {'fecha': fecha}) as Json;
      if (!mounted || _fecha != fecha) return;
      final e = datos['evaluacion'];
      setState(
        () => _previa = e == null ? null : Evaluacion.desdeJson(e as Json),
      );
      if (e == null)
        setState(
          () => _error = 'No se pudo calcular la evaluación. Revise sus datos antropométricos.',
        );
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.detalle);
    } finally {
      if (mounted) setState(() => _cargandoPrevia = false);
    }
  }

  Future<void> _guardar() async {
    if (_fecha == null) {
      setState(() => _error = 'Elija el plan de gasto calórico');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await Api.post('evaluacion/desde-gasto', {'fecha': _fecha});
      if (!mounted) return;
      final mensajero = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      mensajero.showSnackBar(
        SnackBar(content: Text(Api.ultimoMensaje ?? 'Evaluación guardada')),
      );
      Cambios.avisar();
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.detalle);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final planes = _planes;
    return HojaInferior(
      titulo: 'Nueva evaluación',
      subtitulo: 'Se calcula con tus datos y un plan de gasto calórico',
      pie: planes == null || planes.isEmpty
          ? null
          : PieFormulario(
              texto: 'Guardar evaluación',
              onPressed: _guardando || _previa == null ? null : _guardar,
              error: _error,
            ),
      child: planes == null
          ? (_error == null
                ? const Cargando()
                : ErrorCarga(_error!, onReintentar: _cargarPlanes))
          : ListView(
              padding: const EdgeInsets.all(EqSpace.lg),
              children: [
                if (planes.isEmpty)
                  const EqAviso(
                    'Todavía no tienes un plan de gasto calórico. Créalo en la pestaña Gasto calórico y vuelve aquí.',
                  )
                else ...[
                  EqField(
                    etiqueta: 'Plan de gasto calórico',
                    child: DropdownButtonFormField<String>(
                      initialValue: _fecha,
                      isExpanded: true,
                      items: [
                        for (final p in planes)
                          DropdownMenuItem(
                            value: p.valor,
                            child: Text(
                              '${fechaVista(p.valor)} · ${p.texto}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (f) => _elegir(f!),
                    ),
                  ),
                  const SizedBox(height: EqSpace.md),
                  if (_cargandoPrevia)
                    const Cargando()
                  else if (_previa != null)
                    _Previa(_previa!),
                ],
              ],
            ),
    );
  }
}

class _Previa extends StatelessWidget {
  const _Previa(this.e);

  final Evaluacion e;

  @override
  Widget build(BuildContext context) {
    final filas = [
      ('IMC', fmtNum(e.imc, 1)),
      ('Contextura', e.contextura),
      ('Grasa corporal', '${fmtNum(e.grasaCorporal, 1)} %'),
      ('Gasto basal', '${e.gastoBasal.round()} kcal'),
      (
        'Peso ideal',
        '${fmtNum(e.pesoDesde, 1)} – ${fmtNum(e.pesoHasta, 1)} kg',
      ),
      ('Calorías a consumir', '${e.caloriasConsumir.round()} kcal/día'),
      ('Plan ideal', '${e.diasPlan} días'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'VISTA PREVIA',
          style: EqText.caption.copyWith(color: EqColors.primary),
        ),
        const SizedBox(height: EqSpace.sm),
        for (final (nombre, valor) in filas)
          Container(
            margin: const EdgeInsets.only(bottom: EqSpace.sm),
            padding: const EdgeInsets.symmetric(
              horizontal: EqSpace.md,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: EqColors.surfaceLow,
              borderRadius: BorderRadius.circular(EqRadius.base),
            ),
            child: Row(
              children: [
                Text(
                  nombre,
                  style: EqText.bodySm.copyWith(color: EqColors.onSurface),
                ),
                const Spacer(),
                Text(
                  valor,
                  style: EqText.label.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        if (e.determinantes.isNotEmpty) ...[
          const SizedBox(height: EqSpace.sm),
          Text(e.determinantes.join(' · '), style: EqText.bodySm),
        ],
      ],
    );
  }
}
