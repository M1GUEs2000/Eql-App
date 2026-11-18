import 'package:flutter/material.dart';

import '../data/api.dart';
import '../data/cambios.dart';
import '../data/models.dart';
import '../theme/eq_tokens.dart';
import '../widgets/eq_basicos.dart';
import '../widgets/fecha_libre.dart';
import '../widgets/hoja_inferior.dart';
import '../widgets/progreso_ajuste.dart';

enum _Modo { plan, ajustada }

/// Hoja "Nueva ingesta"; se abre con [abrirHoja]. Crea la dieta desde un plan
/// nutricional (POST ingesta/dietas/desde-plan, como la web) o una ajustada a
/// partir de otra (POST ajuste/dieta-ajustada). Devuelve true si la creó.
class CrearDietaScreen extends StatefulWidget {
  const CrearDietaScreen({super.key});

  @override
  State<CrearDietaScreen> createState() => _CrearDietaScreenState();
}

class _CrearDietaScreenState extends State<CrearDietaScreen> {
  final _nombre = TextEditingController();
  final List<DietaGuardada> _dietas =
      Cambios.ingestaActual.value?.dietas ?? const [];
  final _buscar = TextEditingController();
  var _modo = _Modo.plan;
  List<String>? _planes;
  String? _errorPlanes;
  String? _plan;
  late var _fecha = primerDiaLibre(_dietas.map((d) => d.fecha), DateTime.now());
  String? _origen;
  var _intercambio = true;
  var _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarPlanes();
  }

  @override
  void dispose() {
    _nombre.dispose();
    _buscar.dispose();
    super.dispose();
  }

  Future<void> _cargarPlanes() async {
    setState(() => _errorPlanes = null);
    try {
      final datos = await Api.get('ingesta/planes') as List;
      if (mounted) setState(() => _planes = datos.cast<String>());
    } on ApiError catch (e) {
      if (mounted) setState(() => _errorPlanes = e.detalle);
    }
  }

  /// Como en la web: al elegir el plan, su nombre queda como nombre de la
  /// dieta si el usuario no escribió otro.
  void _elegirPlan(String plan) => setState(() {
    if (_nombre.text.trim().isEmpty || _nombre.text == _plan) {
      _nombre.text = plan;
    }
    _plan = plan;
    _error = null;
  });

  Future<void> _elegirFecha() async {
    final fecha = await elegirFechaLibre(
      context,
      ocupadas: _dietas.map((d) => d.fecha),
      inicial: _fecha,
    );
    if (fecha != null) setState(() => _fecha = fecha);
  }

  Future<void> _crear() async {
    final nombre = _nombre.text.trim();
    final fecha = fechaApi(_fecha);
    final falta = switch (_modo) {
      _Modo.plan when _plan == null => 'Selecciona un plan nutricional',
      _Modo.ajustada when _origen == null => 'Elija la dieta de partida',
      _ when nombre.isEmpty => 'Escriba el nombre de la dieta',
      _ => null,
    };
    if (falta != null) {
      setState(() => _error = falta);
      return;
    }
    if (_dietas.any((d) => d.fecha == fecha)) {
      setState(
        () => _error =
            'Ya existe una dieta el ${fechaVista(fecha)}. Elija otra fecha.',
      );
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      if (_modo == _Modo.plan) {
        await Api.post('ingesta/dietas/desde-plan', {
          'nombrePlan': _plan,
          'nombre': nombre,
          'fecha': fecha,
        });
      } else {
        await Api.post('ajuste/dieta-ajustada', {
          'fechaOriginal': _origen,
          'nuevaFecha': fecha,
          'nombre': nombre,
          'permitirIntercambio': _intercambio,
        });
        if (!mounted) return;
        await esperarAjuste(
          context,
          tipo: TipoAjuste.dietaAjustada,
          fecha: _origen!,
        );
      }
      if (!mounted) return;
      final mensajero = ScaffoldMessenger.of(context);
      Navigator.of(context).pop(true);
      mensajero.showSnackBar(SnackBar(content: Text('Dieta "$nombre" creada')));
      Cambios.avisar(fechaIngesta: fecha);
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.detalle);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return HojaInferior(
      titulo: 'Nueva ingesta',
      subtitulo: 'Una dieta por fecha',
      pie: PieFormulario(
        texto: 'Crear nueva ingesta',
        onPressed: _guardando ? null : _crear,
        error: _error,
      ),
      child: ListView(
        padding: const EdgeInsets.all(EqSpace.lg),
        children: [
          if (_dietas.isNotEmpty) ...[
            SegmentedButton<_Modo>(
              segments: const [
                ButtonSegment(value: _Modo.plan, label: Text('Desde un plan')),
                ButtonSegment(
                  value: _Modo.ajustada,
                  label: Text('Desde otra dieta'),
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
          if (_modo == _Modo.plan) ...[
            _listaPlanes(),
            const SizedBox(height: EqSpace.md),
          ],
          EqField(
            etiqueta: 'Nombre de la dieta',
            child: TextField(
              controller: _nombre,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Ej. Dieta de la semana',
                counterText: '',
              ),
            ),
          ),
          const SizedBox(height: EqSpace.md),
          EqField(
            etiqueta: 'Fecha de la ingesta',
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
          if (_modo == _Modo.ajustada) ...[
            const SizedBox(height: EqSpace.md),
            EqField(
              etiqueta: 'Dieta de partida',
              child: DropdownButtonFormField<String>(
                initialValue: _origen,
                hint: const Text('Elija una dieta guardada'),
                isExpanded: true,
                items: [
                  for (final d in _dietas)
                    DropdownMenuItem(
                      value: d.fecha,
                      child: Text(d.etiqueta, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (f) => setState(() => _origen = f),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _intercambio,
              onChanged: (v) => setState(() => _intercambio = v),
              title: Text(
                'Permitir reemplazar alimentos',
                style: EqText.bodySm.copyWith(color: EqColors.onSurface),
              ),
              subtitle: Text(
                'Si no, solo se ajustan las cantidades',
                style: EqText.caption.copyWith(letterSpacing: 0),
              ),
            ),
            Text(
              'Equilibra copia la dieta y la ajusta a tus objetivos. Usa el cupo de ajuste automático de tu plan.',
              style: EqText.bodySm,
            ),
          ] else ...[
            const SizedBox(height: 12),
            Text(
              'Usa el cupo diario de dietas de tu plan.',
              style: EqText.bodySm,
            ),
          ],
        ],
      ),
    );
  }

  /// Buscador y lista de planes nutricionales (como «Nueva Ingesta» en la web).
  Widget _listaPlanes() {
    final planes = _planes;
    final error = _errorPlanes;
    if (error != null) {
      return SizedBox(
        height: 160,
        child: ErrorCarga(error, onReintentar: _cargarPlanes),
      );
    }
    if (planes == null) return const SizedBox(height: 160, child: Cargando());
    final termino = _buscar.text.trim().toLowerCase();
    final visibles = [
      for (final p in planes)
        if (termino.isEmpty || p.toLowerCase().contains(termino)) p,
    ];
    return EqField(
      etiqueta: 'Plan nutricional',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _buscar,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Buscar plan...',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: EqSpace.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: visibles.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(EqSpace.md),
                    child: Text(
                      'No hay planes que coincidan',
                      style: EqText.bodySm,
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: visibles.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: EqSpace.xs),
                    itemBuilder: (_, i) => _itemPlan(visibles[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _itemPlan(String plan) {
    final elegido = plan == _plan;
    final borde = BorderRadius.circular(EqRadius.md);
    return Material(
      color: elegido
          ? EqColors.primary.withValues(alpha: 0.08)
          : EqColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: borde,
        side: BorderSide(
          color: elegido ? EqColors.primary : EqColors.borderLight,
          width: elegido ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: borde,
        onTap: () => _elegirPlan(plan),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  plan,
                  style: EqText.bodySm.copyWith(
                    color: EqColors.onSurface,
                    fontWeight: elegido ? FontWeight.w600 : null,
                  ),
                ),
              ),
              if (elegido)
                Icon(Icons.check_circle, color: EqColors.primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
