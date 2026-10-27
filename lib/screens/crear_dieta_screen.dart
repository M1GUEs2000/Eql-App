import 'package:flutter/material.dart';

import '../data/api.dart';
import '../data/cambios.dart';
import '../data/models.dart';
import '../theme/eq_tokens.dart';
import '../widgets/eq_basicos.dart';
import '../widgets/fecha_libre.dart';
import '../widgets/hoja_inferior.dart';
import '../widgets/progreso_ajuste.dart';

enum _Modo { vacia, ajustada }

/// Hoja "Nueva ingesta"; se abre con [abrirHoja]. Crea una dieta vacía
/// (POST ingesta/dietas) o una ajustada a partir de otra (POST ajuste/dieta-ajustada).
class CrearDietaScreen extends StatefulWidget {
  const CrearDietaScreen({super.key});

  @override
  State<CrearDietaScreen> createState() => _CrearDietaScreenState();
}

class _CrearDietaScreenState extends State<CrearDietaScreen> {
  final _nombre = TextEditingController();
  final List<DietaGuardada> _dietas =
      Cambios.ingestaActual.value?.dietas ?? const [];
  var _modo = _Modo.vacia;
  late var _fecha = primerDiaLibre(
    _dietas.map((d) => d.fecha),
    DateTime.now(),
  );
  String? _origen;
  var _intercambio = true;
  var _guardando = false;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

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
    if (nombre.isEmpty || (_modo == _Modo.ajustada && _origen == null)) {
      setState(
        () => _error = _modo == _Modo.vacia
            ? 'Escriba el nombre de la dieta'
            : 'Elija la dieta de partida y el nombre',
      );
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
      if (_modo == _Modo.vacia) {
        await Api.post('ingesta/dietas', {'nombre': nombre, 'fecha': fecha});
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
      Navigator.of(context).pop();
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
                ButtonSegment(value: _Modo.vacia, label: Text('Vacía')),
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
}
