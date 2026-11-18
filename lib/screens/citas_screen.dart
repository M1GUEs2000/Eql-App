import 'package:flutter/material.dart';

import '../data/api.dart';
import '../data/sesion.dart';
import '../theme/eq_tokens.dart';
import '../widgets/eq_basicos.dart';
import '../widgets/eq_top_bar.dart';

typedef _J = Map<String, dynamic>;

const _diasCortos = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
const _diasLargos = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];
const _meses = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

String _fechaLarga(DateTime d) =>
    '${_diasLargos[d.weekday - 1]} ${d.day} de ${_meses[d.month - 1]}';

/// "09:30:00" o "09:30" → "09:30".
String _hora(Object? v) {
  final s = '${v ?? ''}';
  return s.length >= 5 ? s.substring(0, 5) : s;
}

/// Estados de la API: 1 Disponible, 2 Por confirmar, 3 Asignado, 4 Atendido.
class _Cita {
  _Cita(_J j)
    : id = (j['idCita'] as num?)?.toInt() ?? 0,
      estado = (j['idEstadoCita'] as num?)?.toInt() ?? 0,
      nombreEstado = j['nombreEstadoCita'] as String? ?? '',
      nutricionista = j['nombreNutricionista'] as String? ?? '',
      paciente = j['nombrePaciente'] as String? ?? '',
      hora = _hora(j['horaAtencionString'] ?? j['horaAtencion']);

  final int id;
  final int estado;
  final String nombreEstado;
  final String nutricionista;
  final String paciente;
  final String hora;

  bool get libre => id == 0;
  bool get atendida => estado == 4;
}

/// Agenda de citas con el nutricionista (api/v1/citas): días hasta un mes
/// adelante, horarios libres de cada día y las citas propias.
class CitasScreen extends StatefulWidget {
  const CitasScreen({super.key});

  @override
  State<CitasScreen> createState() => _CitasScreenState();
}

class _CitasScreenState extends State<CitasScreen> {
  final _hoy = DateUtils.dateOnly(DateTime.now());
  late DateTime _limite = DateTime(_hoy.year, _hoy.month + 1, _hoy.day);
  late DateTime _dia = _hoy;

  List<(int, String)> _nutricionistas = [];
  int _idNutricionista = 0;
  late Future<void> _inicio = _cargarInicio();
  Future<List<_Cita>>? _citasDia;

  bool get _esNutricionista => Sesion.perfil?.esNutricionista ?? false;

  String get _nombreNutricionista => _nutricionistas
      .firstWhere(
        (n) => n.$1 == _idNutricionista,
        orElse: () => (0, 'tu nutricionista'),
      )
      .$2;

  Future<void> _cargarInicio() async {
    final datos = await Api.get('citas') as _J;
    final form = (datos['formConsulta'] as _J?) ?? const {};
    _nutricionistas = [
      for (final n in (form['listaNutricionista'] as List?) ?? const [])
        if (n is Map)
          (int.tryParse('${n['value']}') ?? 0, '${n['text'] ?? ''}'),
    ];
    _idNutricionista =
        (form['idNutricionistaConsulta'] as num?)?.toInt() ??
        (_nutricionistas.isEmpty ? 0 : _nutricionistas.first.$1);
    _limite = leerFechaApi(form['f_LimiteString'] as String?) ?? _limite;
    final lista = ((datos['citas'] as _J?)?['lista'] as List?) ?? const [];
    _citasDia = Future.value([for (final c in lista) _Cita(c as _J)]);
  }

  Future<List<_Cita>> _pedirDia() async {
    final datos = await Api.get('citas/dia', {
      'fecha': fechaApi(_dia),
      'idNutricionista': _idNutricionista,
    }) as _J;
    return [
      for (final c in (datos['lista'] as List?) ?? const []) _Cita(c as _J),
    ];
  }

  void _recargarDia() => setState(() => _citasDia = _pedirDia());

  void _elegirDia(DateTime dia) {
    _dia = dia;
    _recargarDia();
  }

  void _elegirNutricionista(int id) {
    _idNutricionista = id;
    _recargarDia();
  }

  Future<void> _agendar(_Cita horario) async {
    final telefono = await showDialog<String>(
      context: context,
      builder: (_) => _DialogoAgendar(
        fecha: _dia,
        hora: horario.hora,
        nutricionista: _nombreNutricionista,
      ),
    );
    if (telefono == null || !mounted) return;
    try {
      await Api.post('citas', {
        'idCita': 0,
        'idNutricionista': _idNutricionista,
        'idPaciente': 0,
        'fecha': fechaApi(_dia),
        'hora': horario.hora,
        'secuencial': 0,
        'idEstado': 2, // Por confirmar: la confirma el nutricionista.
        'telefono': telefono,
      });
      if (mounted) {
        mostrarMensaje(context, Api.ultimoMensaje ?? 'Cita agendada.');
      }
    } on ApiError catch (e) {
      if (mounted) mostrarMensaje(context, e.detalle);
    }
    if (mounted) _recargarDia();
  }

  Future<void> _cancelar(_Cita cita) async {
    final si = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar cita'),
        content: Text(
          '¿Cancelar la cita del ${_fechaLarga(_dia).toLowerCase()} a las ${cita.hora}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: EqColors.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
    if (si != true || !mounted) return;
    try {
      await Api.delete('citas/${cita.id}');
      if (mounted) {
        mostrarMensaje(context, Api.ultimoMensaje ?? 'Cita cancelada.');
      }
    } on ApiError catch (e) {
      if (mounted) mostrarMensaje(context, e.detalle);
    }
    if (mounted) _recargarDia();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const EqTopBar(titulo: 'Citas'),
      body: FutureBuilder<void>(
        future: _inicio,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return ListView(
              padding: const EdgeInsets.all(EqSpace.md),
              children: [
                EqAviso(
                  '${snap.error}',
                  icono: Icons.event_busy_outlined,
                  accion: OutlinedButton(
                    onPressed: () => setState(() => _inicio = _cargarInicio()),
                    child: const Text('Reintentar'),
                  ),
                ),
              ],
            );
          }
          return _contenido();
        },
      ),
    );
  }

  Widget _contenido() {
    return RefreshIndicator(
      onRefresh: () async {
        _recargarDia();
        await _citasDia;
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, EqSpace.lg, 0, EqSpace.xl),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: EqSpace.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _esNutricionista ? 'Tu agenda' : 'Agenda una cita',
                  style: EqText.h2,
                ),
                const SizedBox(height: EqSpace.xs),
                Text(
                  _esNutricionista
                      ? 'Tus horarios y las citas de tus pacientes, hasta un mes adelante.'
                      : 'Elige un día y un horario libre con $_nombreNutricionista. Puedes agendar hasta un mes adelante.',
                  style: EqText.bodySm,
                ),
                if (!_esNutricionista && _nutricionistas.length > 1) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: EqSpace.sm,
                    runSpacing: EqSpace.sm,
                    children: [
                      for (final (id, nombre) in _nutricionistas)
                        EqChip(
                          texto: nombre,
                          activo: id == _idNutricionista,
                          onTap: () => _elegirNutricionista(id),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: EqSpace.md),
          _TiraDias(
            desde: _hoy,
            hasta: _limite,
            elegido: _dia,
            onElegir: _elegirDia,
          ),
          const SizedBox(height: EqSpace.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: EqSpace.md),
            child: Text(_fechaLarga(_dia), style: EqText.h3),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<_Cita>>(
            future: _citasDia,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(EqSpace.xl),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snap.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: EqSpace.md),
                  child: EqAviso(
                    '${snap.error}',
                    icono: Icons.error_outline,
                    accion: OutlinedButton(
                      onPressed: _recargarDia,
                      child: const Text('Reintentar'),
                    ),
                  ),
                );
              }
              return _Dia(
                citas: snap.data ?? const [],
                esNutricionista: _esNutricionista,
                onAgendar: _esNutricionista ? null : _agendar,
                onCancelar: _cancelar,
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Días desde hoy hasta el límite, en fila desplazable.
class _TiraDias extends StatelessWidget {
  const _TiraDias({
    required this.desde,
    required this.hasta,
    required this.elegido,
    required this.onElegir,
  });

  final DateTime desde;
  final DateTime hasta;
  final DateTime elegido;
  final ValueChanged<DateTime> onElegir;

  @override
  Widget build(BuildContext context) {
    final total = hasta.difference(desde).inDays + 1;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: EqSpace.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: EqSpace.sm),
            _Dia1(
              dia: DateTime(desde.year, desde.month, desde.day + i),
              hoy: i == 0,
              elegido: DateUtils.isSameDay(
                DateTime(desde.year, desde.month, desde.day + i),
                elegido,
              ),
              onElegir: onElegir,
            ),
          ],
        ],
      ),
    );
  }
}

class _Dia1 extends StatelessWidget {
  const _Dia1({
    required this.dia,
    required this.hoy,
    required this.elegido,
    required this.onElegir,
  });

  final DateTime dia;
  final bool hoy;
  final bool elegido;
  final ValueChanged<DateTime> onElegir;

  @override
  Widget build(BuildContext context) {
    final forma = BorderRadius.circular(EqRadius.md);
    final texto = elegido ? Colors.white : EqColors.onSurface;
    final suave = elegido ? Colors.white70 : EqColors.textMuted;
    return Semantics(
      button: true,
      selected: elegido,
      label: _fechaLarga(dia),
      child: Material(
        color: elegido ? EqColors.primary : EqColors.surface,
        borderRadius: forma,
        child: InkWell(
          borderRadius: forma,
          onTap: () => onElegir(dia),
          child: Container(
            constraints: const BoxConstraints(minWidth: 56),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: forma,
              border: Border.all(
                color: elegido ? EqColors.primary : EqColors.borderLight,
              ),
            ),
            child: Column(
              children: [
                Text(
                  hoy ? 'hoy' : _diasCortos[dia.weekday - 1],
                  style: EqText.caption.copyWith(
                    color: suave,
                    letterSpacing: 0,
                  ),
                ),
                Text(
                  '${dia.day}',
                  style: EqText.h3.copyWith(color: texto, height: 1.2),
                ),
                Text(
                  _meses[dia.month - 1].substring(0, 3),
                  style: EqText.caption.copyWith(
                    color: suave,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Citas agendadas del día y, debajo, los horarios libres.
class _Dia extends StatelessWidget {
  const _Dia({
    required this.citas,
    required this.esNutricionista,
    required this.onAgendar,
    required this.onCancelar,
  });

  final List<_Cita> citas;
  final bool esNutricionista;
  final ValueChanged<_Cita>? onAgendar;
  final ValueChanged<_Cita> onCancelar;

  @override
  Widget build(BuildContext context) {
    final agendadas = [
      for (final c in citas)
        if (!c.libre) c,
    ];
    final libres = [
      for (final c in citas)
        if (c.libre && c.estado == 1) c,
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: EqSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (agendadas.isNotEmpty) ...[
            Text(
              esNutricionista ? 'Citas del día' : 'Tus citas',
              style: EqText.label.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: EqSpace.sm),
            for (final c in agendadas) ...[
              _TarjetaCita(
                cita: c,
                titulo: esNutricionista ? c.paciente : c.nutricionista,
                onCancelar: c.atendida ? null : () => onCancelar(c),
              ),
              const SizedBox(height: EqSpace.sm),
            ],
            const SizedBox(height: EqSpace.md),
          ],
          Text(
            'Horarios disponibles',
            style: EqText.label.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: EqSpace.sm),
          if (libres.isEmpty)
            Text(
              'No hay horarios libres este día. Prueba con otro.',
              style: EqText.bodySm,
            )
          else ...[
            Wrap(
              spacing: EqSpace.sm,
              runSpacing: EqSpace.sm,
              children: [
                for (final h in libres)
                  _HoraLibre(
                    hora: h.hora,
                    onTap: onAgendar == null ? null : () => onAgendar!(h),
                  ),
              ],
            ),
            if (esNutricionista) ...[
              const SizedBox(height: 12),
              Text(
                'Para agendar a un paciente usa la versión web.',
                style: EqText.bodySm,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _HoraLibre extends StatelessWidget {
  const _HoraLibre({required this.hora, required this.onTap});

  final String hora;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final forma = BorderRadius.circular(EqRadius.md);
    return Semantics(
      button: onTap != null,
      label: 'Agendar a las $hora',
      child: Material(
        color: EqColors.surface,
        borderRadius: forma,
        child: InkWell(
          borderRadius: forma,
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minWidth: 76, minHeight: 44),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: forma,
              border: Border.all(
                color: EqColors.primary.withValues(alpha: 0.5),
              ),
            ),
            child: Text(
              hora,
              style: EqText.label.copyWith(
                fontWeight: FontWeight.w600,
                color: EqColors.acento,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TarjetaCita extends StatelessWidget {
  const _TarjetaCita({
    required this.cita,
    required this.titulo,
    required this.onCancelar,
  });

  final _Cita cita;
  final String titulo;
  final VoidCallback? onCancelar;

  @override
  Widget build(BuildContext context) {
    final (color, estado) = switch (cita.estado) {
      2 => (EqColors.warningText, 'Por confirmar'),
      3 => (EqColors.successText, 'Confirmada'),
      4 => (EqColors.textMuted, 'Atendida'),
      _ => (EqColors.textMuted, cita.nombreEstado),
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: EqColors.surface,
        borderRadius: BorderRadius.circular(EqRadius.lg),
        border: Border.all(color: EqColors.borderLight),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: EqColors.acentoFondo,
              borderRadius: BorderRadius.circular(EqRadius.md),
            ),
            child: Text(
              cita.hora,
              textAlign: TextAlign.center,
              style: EqText.label.copyWith(
                fontWeight: FontWeight.w700,
                color: EqColors.acento,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (titulo.isNotEmpty)
                  Text(
                    titulo,
                    style: EqText.label.copyWith(fontWeight: FontWeight.w600),
                  ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    estado,
                    style: EqText.caption.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (onCancelar != null)
            IconButton(
              tooltip: 'Cancelar cita',
              onPressed: onCancelar,
              icon: Icon(Icons.event_busy_outlined, color: EqColors.error),
            ),
        ],
      ),
    );
  }
}

/// Confirmación del horario con teléfono opcional; devuelve el teléfono.
class _DialogoAgendar extends StatefulWidget {
  const _DialogoAgendar({
    required this.fecha,
    required this.hora,
    required this.nutricionista,
  });

  final DateTime fecha;
  final String hora;
  final String nutricionista;

  @override
  State<_DialogoAgendar> createState() => _DialogoAgendarState();
}

class _DialogoAgendarState extends State<_DialogoAgendar> {
  final _telefono = TextEditingController();

  @override
  void dispose() {
    _telefono.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget linea(IconData icono, String texto) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icono, size: 20, color: EqColors.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(texto, style: EqText.label)),
        ],
      ),
    );
    return AlertDialog(
      title: const Text('Agendar cita'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            linea(Icons.event_outlined, _fechaLarga(widget.fecha)),
            linea(Icons.schedule, widget.hora),
            linea(Icons.person_outline, widget.nutricionista),
            const SizedBox(height: EqSpace.md),
            TextField(
              controller: _telefono,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Teléfono de contacto (opcional)',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'La cita queda por confirmar hasta que tu nutricionista la acepte.',
              style: EqText.bodySm,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_telefono.text.trim()),
          child: const Text('Agendar'),
        ),
      ],
    );
  }
}
