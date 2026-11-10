import 'package:flutter/material.dart';

import '../data/api.dart';
import '../data/cambios.dart';
import '../data/models.dart';
import '../data/sesion.dart';
import '../theme/eq_tokens.dart';
import '../widgets/eq_basicos.dart';
import '../widgets/eq_top_bar.dart';
import '../widgets/hoja_inferior.dart';
import '../widgets/opcion_card.dart';
import 'crear_dieta_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onIrAPestana});

  final ValueChanged<int> onIrAPestana;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const EqTopBar(),
      body: ListView(
        children: [
          _Bienvenida(onIrAPestana: onIrAPestana),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              EqSpace.md,
              EqSpace.xl,
              EqSpace.md,
              EqSpace.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('¿Qué quieres hacer?', style: EqText.h3),
                const SizedBox(height: EqSpace.md),
                OpcionCard(
                  icono: Icons.restaurant_menu,
                  titulo: 'Ver mis dietas',
                  descripcion:
                      'Consulta las dietas que has guardado anteriormente',
                  onTap: () => onIrAPestana(1),
                ),
                const SizedBox(height: 12),
                OpcionCard(
                  icono: Icons.edit_calendar_outlined,
                  titulo: 'Crear nueva dieta',
                  descripcion:
                      'Empieza una nueva planificación nutricional desde cero',
                  onTap: () =>
                      abrirHoja<void>(context, const CrearDietaScreen()),
                ),
                const SizedBox(height: 12),
                OpcionCard(
                  icono: Icons.local_fire_department_outlined,
                  titulo: 'Ver mi gasto calórico',
                  descripcion:
                      'Revisa tu balance energético y el cálculo de calorías',
                  onTap: () => onIrAPestana(3),
                ),
                const SizedBox(height: 12),
                OpcionCard(
                  icono: Icons.search,
                  titulo: 'Buscar alimentos',
                  descripcion:
                      'Explora y añade alimentos o platos a tus dietas',
                  onTap: () => onIrAPestana(2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Saludo con la fecha y la última dieta del usuario con su satisfacción general.
/// Usa la misma regla que "Ver mis dietas" para elegir la dieta (GET ingesta).
class _Bienvenida extends StatefulWidget {
  const _Bienvenida({required this.onIrAPestana});

  final ValueChanged<int> onIrAPestana;

  @override
  State<_Bienvenida> createState() => _BienvenidaState();
}

class _BienvenidaState extends State<_Bienvenida> {
  static const _dias = [
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
    'sábado',
    'domingo',
  ];
  static const _meses = [
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

  Ingesta? _dieta;
  var _fallo = false;

  @override
  void initState() {
    super.initState();
    Cambios.version.addListener(_cargar);
    _cargar();
  }

  @override
  void dispose() {
    Cambios.version.removeListener(_cargar);
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      var ingesta = Ingesta.desdeJson(await Api.get('ingesta') as Json);
      // Sin dieta hoy se muestra la más reciente, igual que en "Ver mis dietas".
      if (ingesta.vacia && ingesta.dietas.isNotEmpty) {
        ingesta = Ingesta.desdeJson(
          await Api.get('ingesta', {'fecha': fechaDietaMasReciente(ingesta.dietas)}) as Json,
        );
      }
      if (mounted) {
        setState(() {
          _dieta = ingesta;
          _fallo = false;
        });
      }
    } on ApiError {
      if (mounted) setState(() => _fallo = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = DateTime.now();
    final fecha = '${_dias[f.weekday - 1]} ${f.day} de ${_meses[f.month - 1]}';
    final dieta = _dieta;
    return Padding(
      padding: const EdgeInsets.fromLTRB(EqSpace.md, EqSpace.lg, EqSpace.md, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(fecha.toUpperCase(), style: EqText.caption),
          const SizedBox(height: EqSpace.xs),
          Text(
            'Hola, ${Sesion.nombre}',
            style: EqText.h1.copyWith(fontSize: 28),
          ),
          const SizedBox(height: EqSpace.md),
          // Si el resumen no carga, el inicio sigue sirviendo sin él.
          if (_fallo)
            const SizedBox.shrink()
          else if (dieta == null)
            const SizedBox(height: 120, child: Cargando())
          else if (dieta.vacia)
            OpcionCard(
              icono: Icons.restaurant_menu,
              titulo: 'Crea tu primera dieta',
              descripcion: 'Aquí verás tu última dieta y qué tan bien cubre tus nutrientes',
              onTap: () => abrirHoja<void>(context, const CrearDietaScreen()),
            )
          else
            _UltimaDieta(dieta, onTap: () => widget.onIrAPestana(1)),
        ],
      ),
    );
  }
}

class _UltimaDieta extends StatelessWidget {
  const _UltimaDieta(this.d, {required this.onTap});

  final Ingesta d;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pct = d.objetivos.satisfaccion;
    final nombre = d.nombre.isEmpty ? 'Dieta sin nombre' : d.nombre;
    // Mismo corte que el análisis nutricional: desde 90 % se considera bien cubierta.
    final color = pct >= 90 ? EqColors.primary : EqColors.warning;
    return Semantics(
      button: true,
      label:
          'Tu última dieta: $nombre, del ${fechaVista(d.fecha)}. '
          'Satisfacción general ${pct.round()} %. Ver mis dietas',
      excludeSemantics: true,
      child: EqCard(
        radio: EqRadius.lg,
        onTap: onTap,
        child: Row(
          children: [
            SizedBox.square(
              dimension: 88,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: (pct / 100).clamp(0, 1).toDouble(),
                    strokeWidth: 8,
                    strokeCap: StrokeCap.round,
                    color: color,
                    backgroundColor: EqColors.surfaceContainer,
                  ),
                  Center(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: '${pct.round()}'),
                          TextSpan(
                            text: '%',
                            style: EqText.caption.copyWith(letterSpacing: 0),
                          ),
                        ],
                      ),
                      style: EqText.h3.copyWith(fontWeight: FontWeight.w700, height: 1.1),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: EqSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TU ÚLTIMA DIETA', style: EqText.caption),
                  const SizedBox(height: 2),
                  Text(
                    nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: EqText.h4.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(fechaVista(d.fecha), style: EqText.bodySm),
                  const SizedBox(height: 6),
                  Text(
                    'Satisfacción general',
                    style: EqText.label.copyWith(color: EqColors.acento, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: EqColors.textMuted),
          ],
        ),
      ),
    );
  }
}
