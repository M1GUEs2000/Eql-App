import 'dart:async';

import 'package:flutter/material.dart';

import '../data/api.dart';
import '../data/cambios.dart';
import '../data/models.dart';
import '../theme/eq_tokens.dart';
import '../widgets/eq_basicos.dart';
import '../widgets/hoja_inferior.dart';

/// Edita veces por semana, tiempo y unidad de una actividad del plan (PUT gasto-calorico/actividades).
/// Devuelve true si se guardó.
Future<bool?> abrirHojaActividad(
  BuildContext context, {
  required String fecha,
  required Actividad actividad,
}) => abrirHoja<bool>(
  context,
  _HojaActividad(fecha: fecha, actividad: actividad),
);

enum _Modo { plan, actividad }

/// Hoja "Nuevo cálculo de gasto"; se abre con [abrirHoja]. Aplica un plan
/// predefinido en una fecha o agrega una actividad al plan de [fecha].
class CrearGastoScreen extends StatefulWidget {
  const CrearGastoScreen({super.key, this.fecha, this.planes = const []});

  /// Fecha del plan abierto; null si todavía no hay plan.
  final String? fecha;
  final List<Opcion> planes;

  @override
  State<CrearGastoScreen> createState() => _CrearGastoScreenState();
}

class _CrearGastoScreenState extends State<CrearGastoScreen> {
  late var _modo = _Modo.plan;
  late var _planes = widget.planes;
  var _fecha = DateTime.now();
  String? _codigoPlan;
  String? _actividad;
  var _guardando = false;
  String? _error;

  final _busqueda = TextEditingController();
  final _veces = TextEditingController(text: '3');
  final _tiempo = TextEditingController(text: '30');
  var _unidad = 'minutos';
  var _resultados = <String>[];
  Timer? _espera;

  @override
  void initState() {
    super.initState();
    if (_planes.isEmpty) _cargarPlanes();
  }

  @override
  void dispose() {
    _espera?.cancel();
    _busqueda.dispose();
    _veces.dispose();
    _tiempo.dispose();
    super.dispose();
  }

  Future<void> _cargarPlanes() async {
    try {
      final plan = PlanGasto.desdeJson(await Api.get('gasto-calorico') as Json);
      if (mounted) setState(() => _planes = plan.planes);
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.detalle);
    }
  }

  void _buscar(String texto) {
    _espera?.cancel();
    if (texto.trim().length < 2) {
      setState(() => _resultados = []);
      return;
    }
    _espera = Timer(const Duration(milliseconds: 400), () async {
      try {
        final lista = await Api.get('gasto-calorico/actividades/buscar', {
          'q': texto.trim(),
        }) as List;
        if (mounted)
          setState(() => _resultados = [for (final a in lista) '$a']);
      } on ApiError catch (e) {
        if (mounted) setState(() => _error = e.detalle);
      }
    });
  }

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(hoy.year - 1),
      lastDate: DateTime(hoy.year + 1),
    );
    if (fecha != null) setState(() => _fecha = fecha);
  }

  Future<void> _guardar() async {
    final Future<dynamic> Function() llamada;
    if (_modo == _Modo.plan) {
      if (_codigoPlan == null) {
        setState(() => _error = 'Elija un plan predefinido');
        return;
      }
      llamada = () => Api.post('gasto-calorico/aplicar-plan', {
        'fecha': fechaApi(_fecha),
        'codigoPlan': _codigoPlan,
        'ajuGascal': 0,
      });
    } else {
      final veces = int.tryParse(_veces.text.trim());
      final tiempo = double.tryParse(_tiempo.text.trim().replaceAll(',', '.'));
      if (_actividad == null || veces == null || tiempo == null) {
        setState(
          () => _error =
              'Elija la actividad e indique veces por semana y duración',
        );
        return;
      }
      llamada = () => Api.post('gasto-calorico/actividades', {
        'fecha': widget.fecha,
        'actividad': _actividad,
        'vecesSemana': veces,
        'tiempo': tiempo,
        'unidad': _unidad,
        'ajuGascal': 0,
        'esNueva': true,
      });
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await llamada();
      if (!mounted) return;
      final mensajero = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      mensajero.showSnackBar(
        SnackBar(content: Text(Api.ultimoMensaje ?? 'Plan guardado')),
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
    return HojaInferior(
      titulo: 'Gasto calórico',
      subtitulo: 'El servidor calcula el gasto con tu peso',
      pie: PieFormulario(
        texto: _modo == _Modo.plan ? 'Aplicar plan' : 'Agregar actividad',
        onPressed: _guardando ? null : _guardar,
        error: _error,
      ),
      child: ListView(
        padding: const EdgeInsets.all(EqSpace.lg),
        children: [
          if (widget.fecha != null) ...[
            SegmentedButton<_Modo>(
              segments: const [
                ButtonSegment(
                  value: _Modo.plan,
                  label: Text('Plan predefinido'),
                ),
                ButtonSegment(
                  value: _Modo.actividad,
                  label: Text('Agregar actividad'),
                ),
              ],
              selected: {_modo},
              onSelectionChanged: (s) => setState(() {
                _modo = s.first;
                _error = null;
              }),
            ),
            const SizedBox(height: EqSpace.lg),
          ],
          if (_modo == _Modo.plan)
            ..._formularioPlan()
          else
            ..._formularioActividad(),
        ],
      ),
    );
  }

  List<Widget> _formularioPlan() => [
    EqField(
      etiqueta: 'Fecha del plan',
      child: InkWell(
        onTap: _elegirFecha,
        child: InputDecorator(
          decoration: const InputDecoration(
            suffixIcon: Icon(Icons.calendar_today_outlined),
          ),
          child: Text(fechaVista(fechaApi(_fecha)), style: EqText.body),
        ),
      ),
    ),
    const SizedBox(height: EqSpace.md),
    EqField(
      etiqueta: 'Plan predefinido',
      child: _planes.isEmpty
          ? const LinearProgressIndicator()
          : DropdownButtonFormField<String>(
              initialValue: _codigoPlan,
              hint: const Text('Elija el que más se parezca a su semana'),
              isExpanded: true,
              items: [
                for (final p in _planes)
                  DropdownMenuItem(
                    value: p.valor,
                    child: Text(p.texto, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (c) => setState(() => _codigoPlan = c),
            ),
    ),
    const SizedBox(height: 12),
    Text(
      'Si ya hay un plan en esa fecha, sus actividades se reemplazan por las del plan elegido.',
      style: EqText.bodySm,
    ),
  ];

  List<Widget> _formularioActividad() => [
    Text(
      'Se agrega al plan del ${fechaVista(widget.fecha!)}',
      style: EqText.bodySm,
    ),
    const SizedBox(height: EqSpace.md),
    EqField(
      etiqueta: 'Actividad',
      child: TextField(
        controller: _busqueda,
        onChanged: _buscar,
        decoration: const InputDecoration(
          hintText: 'Ej. caminar, nadar, bicicleta...',
          prefixIcon: Icon(Icons.search),
        ),
      ),
    ),
    if (_actividad != null) ...[
      const SizedBox(height: EqSpace.sm),
      EqEtiqueta(_actividad!, tono: EqTono.exito),
    ],
    for (final a in _resultados.take(12))
      ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(
          a,
          style: EqText.bodySm.copyWith(color: EqColors.onSurface),
        ),
        trailing: a == _actividad
            ? Icon(Icons.check_circle, color: EqColors.primary)
            : null,
        onTap: () => setState(() => _actividad = a),
      ),
    const SizedBox(height: EqSpace.md),
    _CamposTiempo(
      veces: _veces,
      tiempo: _tiempo,
      unidad: _unidad,
      onUnidad: (u) => setState(() => _unidad = u),
    ),
  ];
}

class _CamposTiempo extends StatelessWidget {
  const _CamposTiempo({
    required this.veces,
    required this.tiempo,
    required this.unidad,
    required this.onUnidad,
  });

  final TextEditingController veces;
  final TextEditingController tiempo;
  final String unidad;
  final ValueChanged<String> onUnidad;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: EqField(
            etiqueta: 'Veces/semana',
            child: TextField(
              controller: veces,
              keyboardType: TextInputType.number,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: EqField(
            etiqueta: 'Duración',
            child: TextField(
              controller: tiempo,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: EqField(
            etiqueta: 'Unidad',
            child: DropdownButtonFormField<String>(
              initialValue: unidad,
              items: const [
                DropdownMenuItem(value: 'minutos', child: Text('min')),
                DropdownMenuItem(value: 'horas', child: Text('horas')),
              ],
              onChanged: (u) => onUnidad(u!),
            ),
          ),
        ),
      ],
    );
  }
}

class _HojaActividad extends StatefulWidget {
  const _HojaActividad({required this.fecha, required this.actividad});

  final String fecha;
  final Actividad actividad;

  @override
  State<_HojaActividad> createState() => _HojaActividadState();
}

class _HojaActividadState extends State<_HojaActividad> {
  late final _veces = TextEditingController(
    text: '${widget.actividad.vecesSemana}',
  );
  late final _tiempo = TextEditingController(
    text: fmtNum(widget.actividad.tiempo),
  );
  late var _unidad = widget.actividad.unidad == 'horas' ? 'horas' : 'minutos';
  var _guardando = false;
  String? _error;

  @override
  void dispose() {
    _veces.dispose();
    _tiempo.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final veces = int.tryParse(_veces.text.trim());
    final tiempo = double.tryParse(_tiempo.text.trim().replaceAll(',', '.'));
    if (veces == null || tiempo == null) {
      setState(() => _error = 'Indique veces por semana y duración');
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await Api.put('gasto-calorico/actividades', {
        'fecha': widget.fecha,
        'actividad': widget.actividad.nombre,
        'vecesSemana': veces,
        'tiempo': tiempo,
        'unidad': _unidad,
        'ajuGascal': 0,
        'esNueva': false,
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
    return HojaInferior(
      titulo: 'Editar actividad',
      subtitulo: widget.actividad.nombre,
      pie: PieFormulario(
        texto: 'Guardar cambios',
        onPressed: _guardando ? null : _guardar,
        error: _error,
      ),
      child: ListView(
        padding: const EdgeInsets.all(EqSpace.lg),
        children: [
          _CamposTiempo(
            veces: _veces,
            tiempo: _tiempo,
            unidad: _unidad,
            onUnidad: (u) => setState(() => _unidad = u),
          ),
        ],
      ),
    );
  }
}
