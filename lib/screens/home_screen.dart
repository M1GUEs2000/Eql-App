import 'package:flutter/material.dart';

import '../data/analisis.dart';
import '../data/api.dart';
import '../data/cache_dietas.dart';
import '../data/cambios.dart';
import '../data/models.dart';
import '../data/sesion.dart';
import '../data/ultima_dieta.dart';
import '../theme/eq_tokens.dart';
import '../widgets/eq_basicos.dart';
import '../widgets/analisis_nutricional.dart';
import '../widgets/deslizar_fechas.dart';
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
                  onTap: () => crearDieta(context, onIrAPestana),
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

/// Abre la hoja "Nueva ingesta"; si se crea la dieta lleva a "Mis dietas"
/// (pestaña 1), que ya la muestra para empezar a poner alimentos.
Future<void> crearDieta(BuildContext context, ValueChanged<int> irA) async {
  final creada = await abrirHoja<bool>(context, const CrearDietaScreen());
  if (creada == true) irA(1);
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

  /// Análisis del día completo, igual que en "Ver dieta"; da la satisfacción
  /// y las calorías. `ingesta.objetivos.satisfaccion` llega en 0 del servidor.
  AnalisisNutricional? _analisis;
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

  /// Al abrir y tras cada cambio se vuelve a la última dieta editada.
  Future<void> _cargar() => _abrir(null);

  /// Fecha con dieta vecina a la mostrada: [paso] 1 la siguiente, -1 la anterior.
  String? _vecina(int paso) {
    final dieta = _dieta;
    return dieta == null
        ? null
        : fechaDietaVecina(dieta.dietas, dieta.fecha, paso);
  }

  /// Con [fecha] (al deslizar) usa la vecina ya pedida por adelantado; sin
  /// fecha (al abrir o tras un cambio) pide todo fresco al servidor.
  Future<void> _abrir(String? fecha) async {
    try {
      var ingesta = fecha == null
          ? Ingesta.desdeJson(await Api.get('ingesta') as Json)
          : await CacheDietas.ingesta(fecha);
      if (fecha == null) {
        // La API da la de hoy: se muestra la última dieta editada
        // (o la más reciente), igual que en "Ver mis dietas".
        if (ingesta.dietas.isNotEmpty) {
          final elegida = await fechaDietaAMostrar(ingesta.dietas);
          if (elegida != ingesta.fecha) {
            CacheDietas.olvidar(elegida);
            ingesta = await CacheDietas.ingesta(elegida);
          }
        }
        CacheDietas.olvidar(ingesta.fecha); // su análisis también, fresco
      }
      AnalisisNutricional? analisis;
      try {
        analisis = await CacheDietas.analisis(ingesta);
      } on ApiError {
        // Sin análisis la tarjeta muestra "—" en vez de un 0 falso.
      }
      if (mounted) {
        setState(() {
          _dieta = ingesta;
          _analisis = analisis;
          _fallo = false;
        });
      }
      // Guarda esta y pide por adelantado la anterior y la siguiente.
      CacheDietas.mantener('inicio', ingesta);
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
              onTap: () => crearDieta(context, widget.onIrAPestana),
            )
          else ...[
            // Arrastrar la tarjeta de lado pasa a la fecha anterior o siguiente.
            DeslizarFechas(
              clave: dieta.fecha,
              puede: (paso) => _vecina(paso) != null,
              onCambiar: (paso) async {
                final f = _vecina(paso);
                if (f != null) await _abrir(f);
              },
              child: _UltimaDieta(
                dieta,
                _analisis,
                onTap: () => widget.onIrAPestana(1),
              ),
            ),
            if (dieta.dietas.length > 1) _Posicion(dieta),
          ],
        ],
      ),
    );
  }
}

/// "‹ 3 de 12 ›": en qué dieta va, para que se note que se puede deslizar.
class _Posicion extends StatelessWidget {
  const _Posicion(this.d);

  final Ingesta d;

  @override
  Widget build(BuildContext context) {
    final fechas = [for (final x in d.dietas) x.fecha]..sort();
    final i = fechas.indexOf(d.fecha);
    final estilo = EqText.caption.copyWith(
      letterSpacing: 0,
      color: EqColors.textFaint,
    );
    return Padding(
      padding: const EdgeInsets.only(top: EqSpace.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chevron_left, size: 16, color: EqColors.textFaint),
          const SizedBox(width: 4),
          Text(
            i < 0
                ? 'Desliza para ver otras fechas'
                : 'Dieta ${i + 1} de ${fechas.length} · desliza para cambiar de fecha',
            style: estilo,
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, size: 16, color: EqColors.textFaint),
        ],
      ),
    );
  }
}

class _UltimaDieta extends StatelessWidget {
  const _UltimaDieta(this.d, this.analisis, {required this.onTap});

  final Ingesta d;
  final AnalisisNutricional? analisis;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pct = analisis?.satisfaccion ?? 0;
    final kcal = analisis?.nutrientes
        .where((n) => n.campo == 'KCALS')
        .firstOrNull;
    final nombre = d.nombre.isEmpty ? 'Dieta sin nombre' : d.nombre;
    final color = colorPorcentaje(pct);
    return Semantics(
      button: true,
      label:
          'Tu última dieta: $nombre, del ${fechaVista(d.fecha)}. '
          'Satisfacción general ${analisis == null ? 'sin calcular' : '${pct.round()} %'}. '
          '${kcal == null ? '' : 'Calorías: ${kcal.cantidad.round()} de ${kcal.objetivo.round()} kcal. '}'
          'Ver mis dietas',
      excludeSemantics: true,
      child: EqCard(
        radio: EqRadius.lg,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _cabecera(pct, color, nombre),
            if (kcal != null) ...[
              const SizedBox(height: EqSpace.md),
              Divider(height: 1, color: EqColors.borderFaint),
              const SizedBox(height: EqSpace.md),
              _Calorias(kcal),
            ],
          ],
        ),
      ),
    );
  }

  Widget _cabecera(double pct, Color color, String nombre) {
    return Row(
      children: [
        SizedBox.square(
          dimension: 96,
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
                      TextSpan(text: analisis == null ? '—' : '${pct.round()}'),
                      if (analisis != null)
                        TextSpan(
                          text: '%',
                          style: EqText.caption.copyWith(letterSpacing: 0),
                        ),
                    ],
                  ),
                  style: EqText.h3.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
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
                style: EqText.label.copyWith(
                  color: EqColors.acento,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Icon(Icons.chevron_right, color: EqColors.textMuted),
      ],
    );
  }
}

/// Calorías de la dieta contra el objetivo (fila KCALS del análisis), con barra.
class _Calorias extends StatelessWidget {
  const _Calorias(this.n);

  final Nutriente n;

  @override
  Widget build(BuildContext context) {
    final fraccion = n.objetivo <= 0 ? 0.0 : n.cantidad / n.objetivo;
    final diferencia = (n.objetivo - n.cantidad).round();
    // Mismo color que la fila de calorías en el análisis (por % cuantitativo).
    final color = colorPorcentaje(n.cuantitativo);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.local_fire_department_outlined, size: 20, color: color),
            const SizedBox(width: 6),
            Text(
              'Calorías',
              style: EqText.label.copyWith(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Text(
              '${fmtNum(n.cuantitativo)} %',
              style: EqText.label.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: EqSpace.sm),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '${n.cantidad.round()}'),
              TextSpan(
                text: ' / ${n.objetivo.round()} kcal',
                style: EqText.bodySm.copyWith(color: EqColors.textMuted),
              ),
            ],
          ),
          style: EqText.h2.copyWith(fontWeight: FontWeight.w700, height: 1.1),
        ),
        const SizedBox(height: EqSpace.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: fraccion.clamp(0, 1).toDouble(),
            minHeight: 10,
            color: color,
            backgroundColor: EqColors.surfaceContainer,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          diferencia >= 0
              ? 'Faltan $diferencia kcal para el objetivo'
              : 'Te pasas por ${-diferencia} kcal del objetivo',
          style: EqText.bodySm,
        ),
      ],
    );
  }
}
