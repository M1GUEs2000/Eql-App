import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/analisis.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../theme/eq_tokens.dart';
import 'analisis_nutricional.dart' show colorPorcentaje;

/// Operaciones que corren en segundo plano en el servidor.
enum TipoAjuste {
  automatico('aa'),
  dietaAjustada('da');

  const TipoAjuste(this.codigo);
  final String codigo;
}

/// Muestra un diálogo mientras consulta GET ajuste/estado cada pocos segundos.
/// Devuelve el resultado al completar, null si se canceló; lanza [ApiError] si
/// el servidor responde ERROR.
///
/// Es un solo diálogo de principio a fin: al completarse el ajuste llama a
/// [alCompletar] (aplicar los cambios, traer el análisis final...) sin cerrarse y,
/// si devuelve el análisis de la dieta resultante, anima el círculo y los 4
/// nutrientes más bajos hasta sus valores finales; se cierra con "Listo".
/// Si [alCompletar] devuelve null el diálogo se cierra directamente.
Future<Json?> esperarAjuste(
  BuildContext context, {
  required TipoAjuste tipo,
  required String fecha,
  double? satisfaccionInicial,
  List<Nutriente>? nutrientesIniciales,
  Future<AnalisisNutricional?> Function(Json resultado)? alCompletar,
}) async {
  final resultado = await showDialog<_Fin>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _Progreso(
      tipo: tipo,
      fecha: fecha,
      inicial: satisfaccionInicial,
      peores: peoresNutrientes(nutrientesIniciales ?? const []),
      alCompletar: alCompletar,
    ),
  );
  return switch (resultado) {
    _Completado(:final datos) => datos,
    _Fallo(:final error) => throw error,
    _ => null,
  };
}

sealed class _Fin {}

class _Completado extends _Fin {
  _Completado(this.datos);
  final Json datos;
}

class _Fallo extends _Fin {
  _Fallo(this.error);
  final ApiError error;
}

class _Progreso extends StatefulWidget {
  const _Progreso({
    required this.tipo,
    required this.fecha,
    this.inicial,
    this.peores = const [],
    this.alCompletar,
  });

  final TipoAjuste tipo;
  final String fecha;
  final Future<AnalisisNutricional?> Function(Json resultado)? alCompletar;

  /// Los nutrientes más bajos de la dieta antes de optimizar.
  final List<Nutriente> peores;

  /// Satisfacción de la dieta antes de empezar; el círculo arranca ahí.
  final double? inicial;

  @override
  State<_Progreso> createState() => _ProgresoState();
}

enum _Fase { corriendo, aplicando, listo }

class _ProgresoState extends State<_Progreso> {
  Timer? _temporizador;
  var _mensaje = 'Equilibra está ajustando la dieta. Puede tardar un poco.';
  var _cancelando = false;
  var _fase = _Fase.corriendo;

  /// Análisis de la dieta ya optimizada y resultado del ajuste, en la fase [_Fase.listo].
  AnalisisNutricional? _despues;
  Json _datos = const {};

  /// Satisfacción del último paso (GET ajuste/estado → porcentaje).
  late double? _pct = widget.inicial;
  double? _pctAnterior;

  @override
  void initState() {
    super.initState();
    _temporizador = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _consultar(),
    );
  }

  @override
  void dispose() {
    _temporizador?.cancel();
    super.dispose();
  }

  Future<void> _consultar() async {
    try {
      final estado = await Api.get('ajuste/estado', {
        'tipo': widget.tipo.codigo,
        'fecha': widget.fecha,
      }) as Json;
      if (!mounted || _fase != _Fase.corriendo) return;
      switch (estado['estado']) {
        case 'COMPLETADO':
          _completar((estado['resultado'] as Json?) ?? const {});
        case 'ERROR':
          _cerrar(
            _Fallo(
              ApiError(
                estado['mensaje'] as String? ??
                    'El ajuste no se pudo completar.',
              ),
            ),
          );
        case 'NO_ENCONTRADO':
          _cerrar(
            _Fallo(
              const ApiError(
                'El servidor ya no tiene el resultado del ajuste. Recargue la dieta.',
              ),
            ),
          );
        default:
          setState(() {
            if (estado['mensaje'] case final String m when m.isNotEmpty) {
              _mensaje = m;
            }
            if (estado['porcentaje'] case final num p
                when p.toDouble() != _pct) {
              _pctAnterior = _pct;
              _pct = p.toDouble();
            }
          });
      }
    } on ApiError catch (e) {
      if (mounted) _cerrar(_Fallo(e));
    }
  }

  /// El ajuste terminó: sin cerrar el diálogo, deja que quien llama aplique los
  /// cambios y trae el análisis final para animar el resultado aquí mismo.
  Future<void> _completar(Json datos) async {
    _temporizador?.cancel();
    final alCompletar = widget.alCompletar;
    if (alCompletar == null) return _cerrar(_Completado(datos));
    setState(() {
      _fase = _Fase.aplicando;
      _mensaje = 'Aplicando los cambios a tu dieta...';
    });
    try {
      final despues = await alCompletar(datos);
      if (!mounted) return;
      if (despues == null) return _cerrar(_Completado(datos));
      setState(() {
        _fase = _Fase.listo;
        _datos = datos;
        _despues = despues;
        _mensaje = 'Así mejoró tu dieta.';
        _pctAnterior = widget.inicial ?? _pct;
        _pct = despues.satisfaccion;
      });
    } on ApiError catch (e) {
      if (mounted) _cerrar(_Fallo(e));
    }
  }

  void _cerrar(_Fin fin) {
    _temporizador?.cancel();
    Navigator.of(context).pop(fin);
  }

  Future<void> _cancelar() async {
    setState(() => _cancelando = true);
    try {
      await Api.post('ajuste/automatico/cancelar', {'fecha': widget.fecha});
    } on ApiError {
      // Si ya terminó, la próxima consulta lo dirá.
    }
    if (mounted) _cerrar(_Cancelado());
  }

  /// Cuánto de la brecha de satisfacción ya se cerró (0..1). Mueve los nutrientes
  /// simulados al mismo ritmo que el círculo.
  double get _avance {
    final ini = widget.inicial;
    final p = _pct;
    if (ini == null || p == null || ini >= 100) return 0;
    return ((p - ini) / (100 - ini)).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final listo = _fase == _Fase.listo;
    final hayBoton =
        listo ||
        (_fase == _Fase.corriendo && widget.tipo == TipoAjuste.automatico);
    return AlertDialog(
      title: Text(listo ? 'Dieta optimizada' : 'Optimizando'),
      // Todo mide lo mismo en cada fase para que el diálogo no cambie de tamaño:
      // ancho fijo, mensaje en una caja de alto fijo y botón que solo se oculta.
      content: SizedBox(
        width: 300,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CirculoSatisfaccion(
                pct: _pct,
                anterior: _pctAnterior,
                girando: !listo,
              ),
              const SizedBox(height: EqSpace.md),
              SizedBox(
                height: 60,
                child: Center(
                  child: Text(
                    _mensaje,
                    style: EqText.bodySm,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (widget.peores.isNotEmpty) ...[
                const SizedBox(height: EqSpace.md),
                _ListaPeores(
                  nutrientes: widget.peores,
                  despues: _despues,
                  avance: _avance,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        Visibility(
          visible: hayBoton,
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          child: TextButton(
            onPressed: listo
                ? () => _cerrar(_Completado(_datos))
                : _cancelando
                ? null
                : _cancelar,
            child: Text(listo ? 'Listo' : 'Cancelar'),
          ),
        ),
      ],
    );
  }
}

class _Cancelado extends _Fin {}

/// Anillo con la satisfacción general que sube o baja en cada paso del ajuste.
/// Mientras [girando] un aro exterior da vueltas alrededor, como el pastel de
/// satisfacción "cargando"; al terminar el aro se desvanece.
/// Sin porcentaje todavía (o si el servidor no lo manda) solo gira el aro.
class _CirculoSatisfaccion extends StatelessWidget {
  const _CirculoSatisfaccion({
    required this.pct,
    required this.anterior,
    required this.girando,
  });

  final double? pct;
  final double? anterior;
  final bool girando;

  static const _tamano = 128.0;
  static const _aro = 148.0;

  @override
  Widget build(BuildContext context) {
    final p = pct;
    final reducir = MediaQuery.disableAnimationsOf(context);
    final aro = Positioned.fill(
      child: AnimatedOpacity(
        opacity: girando ? 1 : 0,
        duration: reducir ? Duration.zero : const Duration(milliseconds: 400),
        child: CircularProgressIndicator(
          strokeWidth: 4,
          strokeCap: StrokeCap.round,
          color: EqColors.primary,
        ),
      ),
    );
    if (p == null) {
      return SizedBox.square(
        dimension: _aro,
        child: Stack(alignment: Alignment.center, children: [aro]),
      );
    }
    final a = anterior;
    final sube = a != null && p > a;
    final baja = a != null && p < a;
    return Semantics(
      liveRegion: true,
      label: 'Satisfacción general ${fmtNum(p, 1)} %',
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: p),
        duration: reducir ? Duration.zero : const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, valor, _) {
          final color = colorPorcentaje(valor);
          return SizedBox.square(
            dimension: _aro,
            child: Stack(
              alignment: Alignment.center,
              children: [
                aro,
                SizedBox.square(
                  dimension: _tamano,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: CircularProgressIndicator(
                          value: (valor / 100).clamp(0.0, 1.0),
                          strokeWidth: 10,
                          strokeCap: StrokeCap.round,
                          color: color,
                          backgroundColor: color.withValues(alpha: 0.15),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${fmtNum(valor, 1)} %',
                            style: EqText.h3.copyWith(color: color),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (sube || baja)
                                Icon(
                                  sube
                                      ? Icons.arrow_upward
                                      : Icons.arrow_downward,
                                  size: 14,
                                  color: sube
                                      ? EqColors.successText
                                      : EqColors.errorText,
                                ),
                              Text(
                                'Satisfacción',
                                style: EqText.caption.copyWith(
                                  letterSpacing: 0,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Los [cuantos] nutrientes con menor % cualitativo (el orden por defecto del análisis).
List<Nutriente> peoresNutrientes(List<Nutriente> todos, {int cuantos = 4}) {
  final orden = [...todos]
    ..sort((a, b) => a.cualitativo.compareTo(b.cualitativo));
  return orden.take(cuantos).toList();
}

/// Filas de nutrientes con su barra. Mientras corre el ajuste las barras suben
/// **simuladas** según [avance] (el servidor no manda el avance por nutriente);
/// con [despues] saltan al valor real final y muestran la diferencia.
class _ListaPeores extends StatelessWidget {
  const _ListaPeores({
    required this.nutrientes,
    this.despues,
    this.avance = 0,
  });

  final List<Nutriente> nutrientes;
  final AnalisisNutricional? despues;
  final double avance;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Nutrientes más bajos',
          style: EqText.label.copyWith(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: EqSpace.sm),
        for (final n in nutrientes) ...[
          _BarraNutriente(
            nombre: n.nombre,
            antes: n.cualitativo,
            avance: avance,
            despues: despues == null
                ? null
                : despues!.nutrientes
                          .where((x) => x.campo == n.campo)
                          .firstOrNull
                          ?.cualitativo ??
                      n.cualitativo,
          ),
          const SizedBox(height: EqSpace.sm),
        ],
      ],
    );
  }
}

class _BarraNutriente extends StatelessWidget {
  const _BarraNutriente({
    required this.nombre,
    required this.antes,
    required this.avance,
    this.despues,
  });

  final String nombre;
  final double antes;
  final double avance;
  final double? despues;

  /// Simulación: el nutriente cierra la misma fracción de su brecha al 100 %
  /// que la satisfacción, con un 15 % de margen para que el valor real final
  /// no quede muy por debajo de lo que se vio subir.
  double get _simulado => antes + math.max(0, 100 - antes) * avance * 0.85;

  @override
  Widget build(BuildContext context) {
    final real = despues;
    final meta = real ?? _simulado;
    final delta = (real ?? antes) - antes;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: meta),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, valor, _) {
        final color = colorPorcentaje(valor);
        return Semantics(
          label: '$nombre ${fmtNum(meta, 1)} %',
          excludeSemantics: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      nombre,
                      style: EqText.caption.copyWith(letterSpacing: 0),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (real != null && delta.abs() >= 0.05) ...[
                    Icon(
                      delta > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 12,
                      color: delta > 0
                          ? EqColors.successText
                          : EqColors.errorText,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${fmtNum(delta.abs(), 1)}  ',
                      style: EqText.caption.copyWith(
                        letterSpacing: 0,
                        color: delta > 0
                            ? EqColors.successText
                            : EqColors.errorText,
                      ),
                    ),
                  ],
                  Text(
                    '${fmtNum(valor, 1)} %',
                    style: EqText.label.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: (valor / 100).clamp(0.0, 1.0),
                  minHeight: 6,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.15),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
