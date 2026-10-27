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

/// Saludo con la fecha y el resumen de calorías de hoy (GET ingesta/objetivos).
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

  ObjetivosDia? _hoy;
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
      final datos = await Api.get('ingesta/objetivos') as Json;
      if (mounted) {
        setState(() {
          _hoy = ObjetivosDia.desdeJson(datos);
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
    final hoy = _hoy;
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
          else if (hoy == null)
            const SizedBox(height: 120, child: Cargando())
          else if (!hoy.tieneObjetivo || hoy.objKcal <= 0)
            OpcionCard(
              icono: Icons.flag_outlined,
              titulo: 'Define tu objetivo diario',
              descripcion:
                  'Crea una evaluación para saber cuántas calorías te tocan al día',
              onTap: () => widget.onIrAPestana(4),
            )
          else
            _ResumenHoy(hoy, onTap: () => widget.onIrAPestana(1)),
        ],
      ),
    );
  }
}

class _ResumenHoy extends StatelessWidget {
  const _ResumenHoy(this.d, {required this.onTap});

  final ObjetivosDia d;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final restan = (d.objKcal - d.kcal).round();
    return Semantics(
      button: true,
      label:
          'Hoy llevas ${d.kcal.round()} de ${d.objKcal.round()} kilocalorías. '
          'Ver mis dietas',
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
                    value: (d.kcal / d.objKcal).clamp(0, 1).toDouble(),
                    strokeWidth: 8,
                    strokeCap: StrokeCap.round,
                    color: restan < 0 ? EqColors.warning : EqColors.primary,
                    backgroundColor: EqColors.surfaceContainer,
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${d.kcal.round()}',
                          style: EqText.h3.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                          ),
                        ),
                        Text(
                          'kcal',
                          style: EqText.caption.copyWith(letterSpacing: 0),
                        ),
                      ],
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
                  Text(
                    restan >= 0
                        ? 'Te quedan $restan kcal'
                        : 'Pasaste tu objetivo por ${-restan} kcal',
                    style: EqText.h4.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'de ${d.objKcal.round()} kcal para hoy',
                    style: EqText.bodySm,
                  ),
                  const SizedBox(height: 6),
                  _Macro('Proteínas', d.proteinas, d.objProteinas),
                  _Macro('Carbohidratos', d.carbohidratos, d.objCarbohidratos),
                  _Macro('Grasas', d.grasa, d.objGrasa),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Macro extends StatelessWidget {
  const _Macro(this.nombre, this.valor, this.objetivo);

  final String nombre;
  final double valor;
  final double objetivo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              nombre,
              style: EqText.caption.copyWith(letterSpacing: 0),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: objetivo <= 0 ? 0 : (valor / objetivo).clamp(0, 1),
                minHeight: 6,
                color: EqColors.primaryLight,
                backgroundColor: EqColors.surfaceContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
