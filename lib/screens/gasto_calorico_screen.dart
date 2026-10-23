import 'package:flutter/material.dart';

import '../data/api.dart';
import '../data/cambios.dart';
import '../data/models.dart';
import '../theme/eq_tokens.dart';
import '../widgets/boton_crear.dart';
import '../widgets/eq_basicos.dart';
import '../widgets/eq_metricas.dart';
import '../widgets/eq_top_bar.dart';
import '../widgets/hoja_inferior.dart';
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
    final guardado = await abrirHojaActividad(
      context,
      fecha: plan.fecha!,
      actividad: actividad,
    );
    if (guardado == true) Cambios.avisar();
  }

  Future<void> _quitar(Actividad actividad) async {
    final si = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitar actividad'),
        content: Text('Se quitará "${actividad.nombre}" del plan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (si != true) return;
    try {
      await Api.delete('gasto-calorico/actividades', {
        'fecha': _plan!.fecha,
        'actividad': actividad.nombre,
      });
      if (!mounted) return;
      mostrarMensaje(context, Api.ultimoMensaje ?? 'Actividad quitada');
      Cambios.avisar();
    } on ApiError catch (e) {
      if (mounted) mostrarMensaje(context, e.detalle);
    }
  }

  Future<void> _eliminarPlan() async {
    final plan = _plan!;
    final si = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar gasto calórico'),
        content: Text(
          'Se eliminarán todas las actividades del plan del '
          '${fechaVista(plan.fecha ?? '')}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (si != true) return;
    try {
      await Api.delete('gasto-calorico', {'fecha': plan.fecha});
      if (!mounted) return;
      mostrarMensaje(context, Api.ultimoMensaje ?? 'Gasto calórico eliminado');
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
        acciones: [
          AccionMenu(
            icono: Icons.add,
            etiqueta: 'Crear plan o actividad',
            onTap: () => abrirHoja<void>(
              context,
              CrearGastoScreen(
                fecha: plan?.sinGasto ?? true ? null : plan?.fecha,
                planes: plan?.planes ?? const [],
              ),
            ),
          ),
          AccionMenu(
            icono: Icons.delete_outline,
            etiqueta: 'Eliminar gasto calórico',
            color: EqColors.error,
            habilitada:
                plan != null &&
                !plan.sinGasto &&
                plan.bloqueo == null &&
                plan.actividades.isNotEmpty,
            onTap: _eliminarPlan,
          ),
        ],
        child: RefreshIndicator(
          onRefresh: () => _cargar(plan?.fecha),
          child: _contenido(),
        ),
      ),
    );
  }

  Widget _contenido() {
    final plan = _plan;
    if (_cargando && plan == null) return const Cargando();
    if (_error != null && plan == null) {
      return ErrorCarga(_error!, onReintentar: _cargar);
    }
    if (plan == null) return const SizedBox.shrink();
    final hoy = _hoy;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        EqSpace.md,
        EqSpace.lg,
        EqSpace.md,
        EqSpace.xl,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 64),
          child: Text('Gasto calórico', style: EqText.h2),
        ),
        const SizedBox(height: EqSpace.xs),
        Padding(
          padding: const EdgeInsets.only(right: 64),
          child: Text(
            'Tu metabolismo basal más las actividades de tu semana',
            style: EqText.bodySm,
          ),
        ),
        const SizedBox(height: EqSpace.md),
        if (_cargando) const LinearProgressIndicator(),
        if (plan.sinGasto)
          EqAviso(
            plan.mensaje ??
                'Aún no tienes un plan de gasto calórico. '
                    'Abre el menú para aplicar un plan predefinido.',
          )
        else ...[
          if (plan.fechas.length > 1) ...[
            EqField(
              etiqueta: 'Plan',
              child: DropdownButtonFormField<String>(
                key: ValueKey(plan.fecha),
                initialValue: plan.fechas.any((f) => f.valor == plan.fecha)
                    ? plan.fecha
                    : null,
                isExpanded: true,
                items: [
                  for (final f in plan.fechas)
                    DropdownMenuItem(
                      value: f.valor,
                      child: Text(
                        '${fechaVista(f.valor)} · ${f.texto}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (f) => _cargar(f),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (plan.bloqueo != null) ...[
            EqAviso(plan.bloqueo!, icono: Icons.lock_outline),
            const SizedBox(height: 12),
          ],
          _HeroGasto(plan),
          const SizedBox(height: 12),
          EqPares(
            hijos: [
              EqMetrica(
                icono: Icons.bolt_outlined,
                titulo: 'Metabolismo basal',
                valor: _miles(plan.gastoBasalDiario),
                unidad: 'kcal por día en reposo',
                color: EqColors.indigo,
              ),
              EqMetrica(
                icono: Icons.directions_run,
                titulo: 'Actividades',
                valor: _miles(plan.gastoActividadesDiario),
                unidad:
                    'kcal por día · ${fmtNum(plan.horasActividad, 1)} h '
                    'a la semana',
              ),
            ],
          ),
          const SizedBox(height: EqSpace.lg),
          EqSeccion(
            'Actividades del plan',
            detalle: '${plan.actividades.length}',
          ),
          const SizedBox(height: 12),
          EqPares(
            hijos: [
              for (final a in plan.actividades)
                _TarjetaActividad(
                  a,
                  onEditar: plan.bloqueo == null ? () => _editar(a) : null,
                  onQuitar: plan.bloqueo == null ? () => _quitar(a) : null,
                ),
            ],
          ),
        ],
        if (hoy != null && hoy.tieneObjetivo) ...[
          const SizedBox(height: EqSpace.lg),
          const EqSeccion('Distribución recomendada'),
          const SizedBox(height: 12),
          EqCard(
            child: Row(
              children: [
                Expanded(
                  child: _AnilloMacro(
                    nombre: 'Proteínas',
                    gramos: hoy.objProteinas,
                    kcalPorGramo: 4,
                    total: hoy.objKcal,
                    color: EqColors.indigo,
                  ),
                ),
                Expanded(
                  child: _AnilloMacro(
                    nombre: 'Carbohidratos',
                    gramos: hoy.objCarbohidratos,
                    kcalPorGramo: 4,
                    total: hoy.objKcal,
                    color: EqColors.warningText,
                  ),
                ),
                Expanded(
                  child: _AnilloMacro(
                    nombre: 'Grasas',
                    gramos: hoy.objGrasa,
                    kcalPorGramo: 9,
                    total: hoy.objKcal,
                    color: EqColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: EqSpace.lg),
          const EqSeccion('Balance de hoy'),
          const SizedBox(height: 12),
          EqPares(
            hijos: [
              EqMetrica(
                icono: Icons.restaurant,
                titulo: 'Consumido',
                valor: _miles(hoy.kcal),
                unidad: 'kcal',
              ),
              EqMetrica(
                icono: Icons.hourglass_bottom,
                titulo: 'Restante',
                valor: _miles(
                  (hoy.objKcal - hoy.kcal).clamp(0, double.infinity),
                ),
                unidad: 'kcal',
                color: EqColors.warningText,
              ),
            ],
          ),
          const SizedBox(height: 12),
          EqCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  value: hoy.avance.clamp(0, 1).toDouble(),
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(5),
                ),
                const SizedBox(height: EqSpace.sm),
                Text(
                  'Vas al ${(hoy.avance * 100).round()} % de tu objetivo de '
                  '${_miles(hoy.objKcal)} kcal',
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
String _miles(double v) => v.round().toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
  (_) => '.',
);

/// Total diario y, debajo, cómo se reparte entre reposo y movimiento.
class _HeroGasto extends StatelessWidget {
  const _HeroGasto(this.plan);

  final PlanGasto plan;

  @override
  Widget build(BuildContext context) {
    final total = plan.totalDiario <= 0 ? 1 : plan.totalDiario;
    final basal = (plan.gastoBasalDiario / total).clamp(0.0, 1.0);
    final rango =
        '${fechaVista(plan.fecha ?? '')}'
        '${plan.fechaFin == null ? '' : ' al ${fechaVista(plan.fechaFin!)}'}';
    return EqHero(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'GASTO ENERGÉTICO TOTAL',
                  style: EqText.caption.copyWith(color: Colors.white70),
                ),
              ),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    plan.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: EqText.caption.copyWith(
                      color: Colors.white,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: EqSpace.xs),
          Text.rich(
            TextSpan(
              style: EqText.display.copyWith(color: Colors.white),
              children: [
                TextSpan(text: _miles(plan.totalDiario)),
                TextSpan(
                  text: ' kcal/día',
                  style: EqText.body.copyWith(color: EqColors.primarySoft),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(rango, style: EqText.bodySm.copyWith(color: Colors.white70)),
          const SizedBox(height: EqSpace.md),
          // Reposo (claro) y movimiento (verde vivo) a escala del total
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  Expanded(
                    flex: (basal * 1000).round().clamp(1, 999),
                    child: const ColoredBox(color: EqColors.primarySoft),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    flex: ((1 - basal) * 1000).round().clamp(1, 999),
                    child: const ColoredBox(color: EqColors.primaryLight),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _Leyenda(
                EqColors.primarySoft,
                'Reposo ${(basal * 100).round()} %',
              ),
              const SizedBox(width: EqSpace.md),
              _Leyenda(
                EqColors.primaryLight,
                'Actividad ${((1 - basal) * 100).round()} %',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Leyenda extends StatelessWidget {
  const _Leyenda(this.color, this.texto);

  final Color color;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          texto,
          style: EqText.caption.copyWith(color: Colors.white, letterSpacing: 0),
        ),
      ],
    );
  }
}

class _TarjetaActividad extends StatelessWidget {
  const _TarjetaActividad(this.a, {this.onEditar, this.onQuitar});

  final Actividad a;
  final VoidCallback? onEditar;
  final VoidCallback? onQuitar;

  @override
  Widget build(BuildContext context) {
    return EqCard(
      onTap: onEditar,
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    a.nombre,
                    style: EqText.label.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (onQuitar != null)
                IconButton(
                  tooltip: 'Quitar ${a.nombre}',
                  onPressed: onQuitar,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: EqColors.textMuted,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              '${a.vecesSemana}× por semana · ${fmtNum(a.tiempo)} ${a.unidad}',
              style: EqText.bodySm.copyWith(fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Spacer(),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              style: EqText.h3.copyWith(
                fontWeight: FontWeight.w700,
                color: EqColors.primary,
              ),
              children: [
                TextSpan(text: '${a.gastoDiario.round()}'),
                TextSpan(
                  text: ' kcal',
                  style: EqText.caption.copyWith(letterSpacing: 0),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnilloMacro extends StatelessWidget {
  const _AnilloMacro({
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
    final porcentaje = total <= 0 ? 0 : (gramos * kcalPorGramo / total * 100);
    return Column(
      children: [
        SizedBox(
          width: 72,
          height: 72,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: (porcentaje / 100).clamp(0, 1).toDouble(),
                  strokeWidth: 7,
                  strokeCap: StrokeCap.round,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.12),
                ),
              ),
              Text(
                '${porcentaje.round()}%',
                style: EqText.label.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          nombre,
          style: EqText.caption.copyWith(letterSpacing: 0),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          '${gramos.round()} g',
          style: EqText.label.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
