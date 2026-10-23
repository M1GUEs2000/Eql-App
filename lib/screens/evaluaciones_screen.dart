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
import 'crear_evaluacion_screen.dart';
import 'datos_screen.dart';

/// GET evaluacion y GET objetivos: la evaluación la calcula el servidor con los
/// datos antropométricos y el plan de gasto calórico.
class EvaluacionesScreen extends StatefulWidget {
  const EvaluacionesScreen({super.key});

  @override
  State<EvaluacionesScreen> createState() => _EvaluacionesScreenState();
}

class _EvaluacionesScreenState extends State<EvaluacionesScreen> {
  VistaEvaluacion? _vista;
  Objetivo? _objetivo;
  String? _fecha;
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

  void _recargar() => _cargar(_fecha);

  Future<void> _cargar([String? fecha]) async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final [vista, objetivos] = await Future.wait([
        Api.get('evaluacion', {'fecha': fecha}),
        Api.get('objetivos', {'fecha': fecha}),
      ]);
      if (!mounted) return;
      setState(() {
        _vista = VistaEvaluacion.desdeJson(vista as Json);
        _objetivo = Objetivo.desdeJson(objetivos as Json);
        _fecha = _vista!.fecha ?? fecha;
      });
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.detalle);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _accion(Future<void> Function() llamada) async {
    try {
      await llamada();
      if (!mounted) return;
      mostrarMensaje(context, Api.ultimoMensaje ?? 'Listo');
      Cambios.avisar();
    } on ApiError catch (e) {
      if (mounted) mostrarMensaje(context, e.detalle);
    }
  }

  Future<void> _eliminar(String fecha) async {
    final si = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar evaluación'),
        content: Text('Se eliminará la evaluación del ${fechaVista(fecha)}.'),
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
    _fecha = null;
    await _accion(() => Api.delete('evaluacion', {'fecha': fecha}));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const EqTopBar(),
      body: ConBotonCrear(
        acciones: [
          AccionMenu(
            icono: Icons.add,
            etiqueta: 'Crear evaluación',
            onTap: () =>
                abrirHoja<void>(context, const CrearEvaluacionScreen()),
          ),
          AccionMenu(
            icono: Icons.delete_outline,
            etiqueta: 'Eliminar evaluación',
            color: EqColors.error,
            habilitada: _fecha != null && _vista?.evaluacion != null,
            onTap: () => _eliminar(_fecha!),
          ),
        ],
        child: RefreshIndicator(
          onRefresh: () => _cargar(_fecha),
          child: _contenido(),
        ),
      ),
    );
  }

  Widget _contenido() {
    final vista = _vista;
    if (_cargando && vista == null) return const Cargando();
    if (_error != null && vista == null) {
      return ErrorCarga(_error!, onReintentar: _cargar);
    }
    final e = vista?.evaluacion;
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
          child: Text('Evaluación nutricional', style: EqText.h2),
        ),
        const SizedBox(height: EqSpace.xs),
        Padding(
          padding: const EdgeInsets.only(right: 64),
          child: Text(
            'Calculada con tus datos y tu plan de gasto calórico',
            style: EqText.bodySm,
          ),
        ),
        const SizedBox(height: EqSpace.md),
        if (_cargando) const LinearProgressIndicator(),
        if (vista == null || e == null)
          EqAviso(
            vista?.tieneGasto ?? false
                ? 'Aún no tienes una evaluación. Abre el menú para generarla desde tu plan de gasto calórico.'
                : 'Para evaluarte, primero completa tus datos antropométricos y crea un plan en la pestaña Gasto calórico.',
            accion: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const DatosScreen()),
              ),
              icon: const Icon(Icons.badge_outlined),
              label: const Text('Ir a mis datos'),
            ),
          )
        else ...[
          if (vista.fechas.length > 1)
            EqField(
              etiqueta: 'Fecha de la evaluación',
              child: DropdownButtonFormField<String>(
                key: ValueKey(_fecha),
                initialValue: vista.fechas.any((f) => f.valor == _fecha)
                    ? _fecha
                    : null,
                items: [
                  for (final f in vista.fechas)
                    DropdownMenuItem(
                      value: f.valor,
                      child: Text(
                        f.texto == f.valor ? fechaVista(f.valor) : f.texto,
                      ),
                    ),
                ],
                onChanged: (f) => _cargar(f),
              ),
            ),
          if (vista.bloqueo != null) ...[
            const SizedBox(height: 12),
            EqAviso(vista.bloqueo!, icono: Icons.lock_outline),
          ],
          const SizedBox(height: 12),
          _HeroEvaluacion(e),
          const SizedBox(height: 12),
          EqPares(
            hijos: [
              EqMetrica(
                icono: Icons.bolt_outlined,
                titulo: 'Gasto basal',
                valor: '${e.gastoBasal.round()}',
                unidad: 'kcal por día',
                color: EqColors.indigo,
              ),
              EqMetrica(
                icono: Icons.flag_outlined,
                titulo: 'Peso ideal',
                valor: '${fmtNum(e.pesoDesde, 1)} – ${fmtNum(e.pesoHasta, 1)}',
                unidad: 'kg',
              ),
              EqMetrica(
                icono: Icons.restaurant,
                titulo: 'Consumir',
                valor: '${e.caloriasConsumir.round()}',
                unidad: 'kcal por día',
              ),
              EqMetrica(
                icono: Icons.local_fire_department_outlined,
                titulo: 'Quemar',
                valor: '${e.caloriasQuemar.round()}',
                unidad: 'kcal por día',
                color: EqColors.warningText,
              ),
              EqMetrica(
                icono: Icons.accessibility_new,
                titulo: 'Sup. corporal',
                valor: fmtNum(e.superficieCorporal),
                unidad: 'm²',
                color: EqColors.indigo,
              ),
              EqMetrica(
                icono: Icons.event_available_outlined,
                titulo: 'Plan ideal',
                valor: '${e.diasPlan}',
                unidad: 'días',
              ),
            ],
          ),
          if (e.determinantes.isNotEmpty || e.factoresRiesgo.isNotEmpty) ...[
            const SizedBox(height: EqSpace.lg),
            EqPares(
              hijos: [
                if (e.determinantes.isNotEmpty)
                  _ListaEvaluacion(
                    titulo: 'Determinantes',
                    icono: Icons.insights_outlined,
                    color: EqColors.indigo,
                    lineas: [for (final d in e.determinantes) _capital(d)],
                  ),
                if (e.factoresRiesgo.isNotEmpty)
                  _ListaEvaluacion(
                    titulo: 'Factores de riesgo',
                    icono: Icons.warning_amber_rounded,
                    color: EqColors.warningText,
                    lineas: [for (final f in e.factoresRiesgo) _capital(f)],
                  ),
              ],
            ),
          ],
          if (_objetivo != null) ...[
            const SizedBox(height: EqSpace.lg),
            EqSeccion(
              'Objetivo diario',
              detalle: _objetivo!.delNutricionista
                  ? 'De tu nutricionista'
                  : 'Calculado por Equilibra',
            ),
            const SizedBox(height: 12),
            EqPares(
              hijos: [
                EqMetrica(
                  icono: Icons.local_fire_department_outlined,
                  titulo: 'Calorías',
                  valor: '${_objetivo!.kcal.round()}',
                  unidad: 'kcal',
                ),
                EqMetrica(
                  icono: Icons.egg_alt_outlined,
                  titulo: 'Proteínas',
                  valor: '${_objetivo!.proteinas.round()}',
                  unidad: 'g',
                  color: EqColors.indigo,
                ),
                EqMetrica(
                  icono: Icons.grain,
                  titulo: 'Carbohidratos',
                  valor: '${_objetivo!.carbohidratos.round()}',
                  unidad: 'g',
                  color: EqColors.warningText,
                ),
                EqMetrica(
                  icono: Icons.water_drop_outlined,
                  titulo: 'Grasas',
                  valor: '${_objetivo!.grasa.round()}',
                  unidad: 'g',
                ),
              ],
            ),
          ],
          if (_objetivo?.estado != 'REFERENCIA') ...[
            const SizedBox(height: EqSpace.md),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _accion(
                  () => Api.post('evaluacion/referencia', {'fecha': _fecha}),
                ),
                icon: const Icon(Icons.push_pin_outlined),
                label: const Text('Usar como referencia'),
              ),
            ),
          ],
        ],
      ],
    );
  }

  static String _capital(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();
}

/// Cabecera: tipo y fecha de la evaluación, y a su lado las dos cifras que la
/// resumen (IMC y grasa corporal), de igual tamaño.
class _HeroEvaluacion extends StatelessWidget {
  const _HeroEvaluacion(this.e);

  final Evaluacion e;

  @override
  Widget build(BuildContext context) {
    final activo = e.estado == 'ACTIVO';
    return EqHero(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  e.tipo.isEmpty
                      ? 'EVALUACIÓN'
                      : 'EVALUACIÓN ${e.tipo.toUpperCase()}',
                  style: EqText.caption.copyWith(color: Colors.white70),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: activo ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  e.estado.isEmpty ? '—' : e.estado,
                  style: EqText.caption.copyWith(
                    color: Colors.white,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              const Icon(Icons.event_outlined, size: 15, color: Colors.white70),
              const SizedBox(width: 6),
              Text(
                fechaVista(e.fecha),
                style: EqText.bodySm.copyWith(color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: EqSpace.md),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _CifraHero(
                    titulo: 'IMC',
                    valor: fmtNum(e.imc, 1),
                    nota: e.contextura,
                  ),
                ),
                Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: EqSpace.md),
                  color: Colors.white24,
                ),
                Expanded(
                  child: _CifraHero(
                    titulo: 'Grasa corporal',
                    valor: fmtNum(e.grasaCorporal, 1),
                    unidad: '%',
                    nota: 'del peso total',
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

class _CifraHero extends StatelessWidget {
  const _CifraHero({
    required this.titulo,
    required this.valor,
    required this.nota,
    this.unidad,
  });

  final String titulo;
  final String valor;
  final String? unidad;
  final String nota;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo.toUpperCase(),
          style: EqText.caption.copyWith(color: Colors.white70, fontSize: 11),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(
              style: EqText.h1.copyWith(color: Colors.white),
              children: [
                TextSpan(text: valor),
                if (unidad != null)
                  TextSpan(
                    text: ' $unidad',
                    style: EqText.body.copyWith(color: EqColors.primarySoft),
                  ),
              ],
            ),
          ),
        ),
        Text(
          nota.isEmpty ? '—' : nota,
          style: EqText.bodySm.copyWith(color: EqColors.primarySoft),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// Tarjeta con una lista corta de líneas (determinantes, factores de riesgo).
class _ListaEvaluacion extends StatelessWidget {
  const _ListaEvaluacion({
    required this.titulo,
    required this.icono,
    required this.color,
    required this.lineas,
  });

  final String titulo;
  final IconData icono;
  final Color color;
  final List<String> lineas;

  @override
  Widget build(BuildContext context) {
    return EqCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(EqRadius.base),
                ),
                child: Icon(icono, size: 19, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  titulo.toUpperCase(),
                  style: EqText.caption.copyWith(fontSize: 11),
                  maxLines: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final l in lineas)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l,
                      style: EqText.bodySm.copyWith(
                        color: EqColors.onSurface,
                        fontSize: 13,
                      ),
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
