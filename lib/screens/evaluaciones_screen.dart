import 'package:flutter/material.dart';

import '../data/api.dart';
import '../data/cambios.dart';
import '../data/models.dart';
import '../theme/eq_tokens.dart';
import '../widgets/boton_crear.dart';
import '../widgets/eq_basicos.dart';
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
    if (_error != null && vista == null)
      return ErrorCarga(_error!, onReintentar: _cargar);
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
        Text(
          'Calculada con tus datos y tu plan de gasto calórico',
          style: EqText.bodySm,
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
          _TarjetaEvaluacion(e),
          if (_objetivo != null) ...[
            const SizedBox(height: 12),
            _TarjetaObjetivo(_objetivo!),
          ],
          const SizedBox(height: EqSpace.md),
          Wrap(
            spacing: EqSpace.sm,
            runSpacing: EqSpace.sm,
            children: [
              if (_objetivo?.estado != 'REFERENCIA')
                OutlinedButton.icon(
                  onPressed: () => _accion(
                    () => Api.post('evaluacion/referencia', {'fecha': _fecha}),
                  ),
                  icon: const Icon(Icons.push_pin_outlined),
                  label: const Text('Usar como referencia'),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _TarjetaEvaluacion extends StatelessWidget {
  const _TarjetaEvaluacion(this.e);

  final Evaluacion e;

  @override
  Widget build(BuildContext context) {
    final datos = [
      ('IMC', fmtNum(e.imc, 1)),
      ('Contextura', e.contextura),
      ('Grasa corporal', '${fmtNum(e.grasaCorporal, 1)} %'),
      ('Gasto basal', '${e.gastoBasal.round()} kcal'),
      (
        'Peso ideal',
        '${fmtNum(e.pesoDesde, 1)} – ${fmtNum(e.pesoHasta, 1)} kg',
      ),
      ('Sup. corporal', '${fmtNum(e.superficieCorporal)} m²'),
      ('Consumir', '${e.caloriasConsumir.round()} kcal'),
      ('Quemar', '${e.caloriasQuemar.round()} kcal'),
      ('Plan ideal', '${e.diasPlan} días'),
    ];
    return EqCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  e.tipo.isEmpty
                      ? 'Evaluación'
                      : 'Evaluación ${e.tipo.toLowerCase()}',
                  style: EqText.h4.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              EqEtiqueta(
                e.estado.isEmpty ? '—' : e.estado,
                tono: e.estado == 'ACTIVO' ? EqTono.exito : EqTono.aviso,
              ),
            ],
          ),
          const SizedBox(height: EqSpace.xs),
          Row(
            children: [
              const Icon(
                Icons.event_outlined,
                size: 16,
                color: EqColors.textMuted,
              ),
              const SizedBox(width: 6),
              Text(fechaVista(e.fecha), style: EqText.bodySm),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, c) {
              final ancho = (c.maxWidth - 2 * EqSpace.sm) / 3;
              return Wrap(
                spacing: EqSpace.sm,
                runSpacing: 12,
                children: [
                  for (final (titulo, valor) in datos)
                    SizedBox(width: ancho, child: _Dato(titulo, valor)),
                ],
              );
            },
          ),
          if (e.determinantes.isNotEmpty) ...[
            const SizedBox(height: EqSpace.md),
            Text('DETERMINANTES', style: EqText.caption),
            const SizedBox(height: 6),
            for (final d in e.determinantes)
              Text(
                '• ${_capital(d)}',
                style: EqText.bodySm.copyWith(color: EqColors.onSurface),
              ),
          ],
          if (e.factoresRiesgo.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('FACTORES DE RIESGO', style: EqText.caption),
            const SizedBox(height: 6),
            Wrap(
              spacing: EqSpace.sm,
              runSpacing: EqSpace.sm,
              children: [
                for (final f in e.factoresRiesgo)
                  EqEtiqueta(f, tono: EqTono.aviso),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _capital(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();
}

class _TarjetaObjetivo extends StatelessWidget {
  const _TarjetaObjetivo(this.o);

  final Objetivo o;

  @override
  Widget build(BuildContext context) {
    return EqCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Objetivo diario',
                  style: EqText.h4.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                o.delNutricionista
                    ? 'De tu nutricionista'
                    : 'Calculado por Equilibra',
                style: EqText.bodySm,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _Dato('Calorías', '${o.kcal.round()} kcal')),
              Expanded(child: _Dato('Proteínas', '${o.proteinas.round()} g')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Dato('Carbohidratos', '${o.carbohidratos.round()} g'),
              ),
              Expanded(child: _Dato('Grasas', '${o.grasa.round()} g')),
            ],
          ),
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato(this.titulo, this.valor);

  final String titulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo.toUpperCase(),
          style: EqText.caption.copyWith(fontSize: 11),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          valor,
          style: EqText.label.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}
