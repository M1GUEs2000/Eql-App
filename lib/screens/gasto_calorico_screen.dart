import 'package:flutter/material.dart';

import '../data/api.dart';
import '../data/cambios.dart';
import '../data/models.dart';
import '../theme/eq_tokens.dart';
import '../widgets/boton_crear.dart';
import '../widgets/eq_basicos.dart';
import '../widgets/eq_top_bar.dart';
import 'crear_gasto_screen.dart';

/// GET gasto-calorico: plan de actividades de una fecha; el servidor calcula
/// el gasto basal y el de cada actividad.
class GastoCaloricoScreen extends StatefulWidget {
  const GastoCaloricoScreen({super.key});

  @override
  State<GastoCaloricoScreen> createState() => _GastoCaloricoScreenState();
}

class _GastoCaloricoScreenState extends State<GastoCaloricoScreen> {
  PlanGasto? _plan;
  ObjetivosDia? _hoy;
  String? _error;
  var _cargando = true;

  @override
  void initState() {
    super.initState();
    Cambios.version.addListener(_recargar);
    _cargar();
  }

  @override
  void dispose() {
    Cambios.version.removeListener(_recargar);
    super.dispose();
  }

  void _recargar() => _cargar(_plan?.fecha);

  Future<void> _cargar([String? fecha]) async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final [plan, hoy] = await Future.wait([
        Api.get('gasto-calorico', {'fecha': fecha}),
        Api.get('ingesta/objetivos'),
      ]);
      if (!mounted) return;
      setState(() {
        _plan = PlanGasto.desdeJson(plan as Json);
        _hoy = ObjetivosDia.desdeJson(hoy as Json);
      });
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.detalle);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _editar(Actividad actividad) async {
    final plan = _plan!;
    final guardado = await abrirHojaActividad(context, fecha: plan.fecha!, actividad: actividad);
    if (guardado == true) Cambios.avisar();
  }

  Future<void> _quitar(Actividad actividad) async {
    final si = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitar actividad'),
        content: Text('Se quitará "${actividad.nombre}" del plan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Quitar')),
        ],
      ),
    );
    if (si != true) return;
    try {
      await Api.delete('gasto-calorico/actividades', {'fecha': _plan!.fecha, 'actividad': actividad.nombre});
      if (!mounted) return;
      mostrarMensaje(context, Api.ultimoMensaje ?? 'Actividad quitada');
      Cambios.avisar();
    } on ApiError catch (e) {
      if (mounted) mostrarMensaje(context, e.detalle);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    return Scaffold(
      appBar: const EqTopBar(),
      body: ConBotonCrear(
        tooltip: 'Nuevo plan o actividad',
        destino: CrearGastoScreen(fecha: plan?.sinGasto ?? true ? null : plan?.fecha, planes: plan?.planes ?? const []),
        child: RefreshIndicator(onRefresh: () => _cargar(plan?.fecha), child: _contenido()),
      ),
    );
  }

  Widget _contenido() {
    final plan = _plan;
    if (_cargando && plan == null) return const Cargando();
    if (_error != null && plan == null) return ErrorCarga(_error!, onReintentar: _cargar);
    if (plan == null) return const SizedBox.shrink();
    final hoy = _hoy;
    return ListView(
      padding: const EdgeInsets.fromLTRB(EqSpace.md, EqSpace.lg, EqSpace.md, EqSpace.xl),
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 64),
          child: Text('Gasto calórico', style: EqText.h2),
        ),
        const SizedBox(height: EqSpace.xs),
        Text('Tu metabolismo basal más las actividades de tu semana', style: EqText.bodySm),
        const SizedBox(height: EqSpace.md),
        if (_cargando) const LinearProgressIndicator(),
        if (plan.sinGasto)
          EqAviso(plan.mensaje ?? 'Aún no tienes un plan de gasto calórico. Toca + para aplicar un plan predefinido.')
        else ...[
          if (plan.fechas.length > 1) ...[
            EqField(
              etiqueta: 'Plan',
              child: DropdownButtonFormField<String>(
                key: ValueKey(plan.fecha),
                initialValue: plan.fechas.any((f) => f.valor == plan.fecha) ? plan.fecha : null,
                isExpanded: true,
                items: [
                  for (final f in plan.fechas)
                    DropdownMenuItem(
                      value: f.valor,
                      child: Text('${fechaVista(f.valor)} · ${f.texto}', overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (f) => _cargar(f),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (plan.bloqueo != null) ...[EqAviso(plan.bloqueo!, icono: Icons.lock_outline), const SizedBox(height: 12)],
          EqHero(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('GASTO ENERGÉTICO TOTAL', style: EqText.caption.copyWith(color: Colors.white70)),
                const SizedBox(height: EqSpace.xs),
                Text.rich(
                  TextSpan(
                    style: EqText.h1.copyWith(color: Colors.white),
                    children: [
                      TextSpan(text: _miles(plan.totalDiario)),
                      TextSpan(
                        text: ' kcal/día',
                        style: EqText.body.copyWith(color: EqColors.primarySoft),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: EqSpace.xs),
                Text(
                  '${plan.nombre} · ${fechaVista(plan.fecha ?? '')}'
                  '${plan.fechaFin == null ? '' : ' al ${fechaVista(plan.fechaFin!)}'}',
                  style: EqText.bodySm.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Metrica(titulo: 'Metabolismo basal', valor: _miles(plan.gastoBasalDiario), unidad: 'kcal/día'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Metrica(
                  titulo: 'Actividades',
                  valor: _miles(plan.gastoActividadesDiario),
                  unidad: '${fmtNum(plan.horasActividad, 1)} h de 168 a la semana',
                ),
              ),
            ],
          ),
          const SizedBox(height: EqSpace.lg),
          Text('Actividades del plan', style: EqText.h4.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          EqCard(
            padding: const EdgeInsets.symmetric(vertical: EqSpace.xs),
            child: Column(
              children: [
                for (final (i, a) in plan.actividades.indexed) ...[
                  if (i > 0) const Divider(height: 1, color: EqColors.borderFaint),
                  ListTile(
                    onTap: plan.bloqueo == null ? () => _editar(a) : null,
                    title: Text(a.nombre, style: EqText.label),
                    subtitle: Text(
                      '${a.vecesSemana}× por semana · ${fmtNum(a.tiempo)} ${a.unidad}',
                      style: EqText.bodySm.copyWith(fontSize: 13),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${a.gastoDiario.round()} kcal',
                          style: EqText.label.copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (plan.bloqueo == null)
                          IconButton(
                            tooltip: 'Quitar ${a.nombre}',
                            onPressed: () => _quitar(a),
                            icon: const Icon(Icons.delete_outline, size: 20),
                            color: EqColors.textMuted,
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        if (hoy != null && hoy.tieneObjetivo) ...[
          const SizedBox(height: EqSpace.lg),
          Text('Distribución recomendada', style: EqText.h4.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          EqCard(
            child: Column(
              children: [
                _BarraMacro(
                  nombre: 'Proteínas',
                  gramos: hoy.objProteinas,
                  kcalPorGramo: 4,
                  total: hoy.objKcal,
                  color: EqColors.indigo,
                ),
                const SizedBox(height: EqSpace.md),
                _BarraMacro(
                  nombre: 'Carbohidratos',
                  gramos: hoy.objCarbohidratos,
                  kcalPorGramo: 4,
                  total: hoy.objKcal,
                  color: EqColors.warningText,
                ),
                const SizedBox(height: EqSpace.md),
                _BarraMacro(
                  nombre: 'Grasas',
                  gramos: hoy.objGrasa,
                  kcalPorGramo: 9,
                  total: hoy.objKcal,
                  color: EqColors.primary,
                ),
              ],
            ),
          ),
          const SizedBox(height: EqSpace.lg),
          Text('Balance de hoy', style: EqText.h4.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          EqCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _Cifra(titulo: 'Consumido', valor: '${_miles(hoy.kcal)} kcal'),
                    ),
                    Expanded(
                      child: _Cifra(
                        titulo: 'Restante',
                        valor: '${_miles((hoy.objKcal - hoy.kcal).clamp(0, double.infinity))} kcal',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: hoy.avance.clamp(0, 1).toDouble(),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: EqSpace.sm),
                Text(
                  'Vas al ${(hoy.avance * 100).round()} % de tu objetivo de ${_miles(hoy.objKcal)} kcal',
                  style: EqText.bodySm,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// 3101.2 → "3.101"
String _miles(double v) => v.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');

class _Metrica extends StatelessWidget {
  const _Metrica({required this.titulo, required this.valor, required this.unidad});

  final String titulo;
  final String valor;
  final String unidad;

  @override
  Widget build(BuildContext context) {
    return EqCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: EqText.bodySm),
          const SizedBox(height: EqSpace.xs),
          Text(valor, style: EqText.h2),
          Text(unidad, style: EqText.caption.copyWith(letterSpacing: 0)),
        ],
      ),
    );
  }
}

class _BarraMacro extends StatelessWidget {
  const _BarraMacro({
    required this.nombre,
    required this.gramos,
    required this.kcalPorGramo,
    required this.total,
    required this.color,
  });

  final String nombre;
  final double gramos;
  final int kcalPorGramo;
  final double total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final porcentaje = total <= 0 ? 0 : (gramos * kcalPorGramo / total * 100).round();
    return Column(
      children: [
        Row(
          children: [
            Text(nombre, style: EqText.label),
            const Spacer(),
            Text('$porcentaje % · ${gramos.round()} g', style: EqText.bodySm),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: (porcentaje / 100).clamp(0, 1).toDouble(),
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
          color: color,
          backgroundColor: color.withValues(alpha: 0.12),
        ),
      ],
    );
  }
}

class _Cifra extends StatelessWidget {
  const _Cifra({required this.titulo, required this.valor});

  final String titulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: EqText.bodySm),
        Text(valor, style: EqText.h3),
      ],
    );
  }
}
