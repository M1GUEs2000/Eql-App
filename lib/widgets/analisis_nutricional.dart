import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/analisis.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../theme/eq_tokens.dart';
import 'eq_basicos.dart';
import 'hoja_inferior.dart';

/// Abre el análisis nutricional (GET analisis) de [dieta] en una hoja inferior.
/// [objetivos] aporta índice glucémico, costo y agua cuando el servidor los calcula.
Future<void> verAnalisis(BuildContext context, String dieta, AnalisisNutricional analisis, {ObjetivosDia? objetivos}) {
  return abrirHoja<void>(
    context,
    HojaInferior(
      titulo: 'Análisis nutricional',
      subtitulo: analisis.estado.isEmpty ? dieta : '$dieta · ${analisis.estado}',
      child: _Analisis(analisis, objetivos),
    ),
  );
}

// Valores bajos sobre el verde oscuro del resumen.
const _coral = Color(0xFFFFA39B);

enum _Tono { bajo, medio, bien }

_Tono _tono(double pct) => pct < 50
    ? _Tono.bajo
    : pct < 90
    ? _Tono.medio
    : _Tono.bien;

Color _colorTono(_Tono t) => switch (t) {
  _Tono.bajo => EqColors.errorText,
  _Tono.medio => EqColors.warningText,
  _Tono.bien => EqColors.primary,
};

enum _Orden {
  cualitativo('% cualitativo'),
  cuantitativo('% cuantitativo'),
  nombre('Nutriente'),
  sec('Sección'),
  objetivo('Objetivo'),
  cantidad('Cantidad'),
  excDef('-Exc / +Def');

  const _Orden(this.etiqueta);
  final String etiqueta;

  Comparable<Object> clave(Nutriente n) => switch (this) {
    _Orden.cualitativo => n.cualitativo,
    _Orden.cuantitativo => n.cuantitativo,
    _Orden.nombre => n.nombre.toLowerCase(),
    _Orden.sec => n.sec,
    _Orden.objetivo => n.objetivo,
    _Orden.cantidad => n.cantidad,
    _Orden.excDef => n.excDef,
  };
}

class _Analisis extends StatefulWidget {
  const _Analisis(this.analisis, this.objetivos);

  final AnalisisNutricional analisis;
  final ObjetivosDia? objetivos;

  @override
  State<_Analisis> createState() => _AnalisisState();
}

class _AnalisisState extends State<_Analisis> {
  GrupoNutriente? _grupo;
  var _orden = _Orden.cualitativo;
  var _ascendente = true;
  final _abiertos = <Nutriente>{};

  List<Nutriente> get _visibles {
    final lista = [
      for (final n in widget.analisis.nutrientes)
        if (_grupo == null || n.grupo == _grupo) n,
    ];
    lista.sort((a, b) {
      final c = _orden.clave(a).compareTo(_orden.clave(b));
      return _ascendente ? c : -c;
    });
    return lista;
  }

  void _ordenar(_Orden orden) {
    setState(() {
      if (orden == _orden) {
        _ascendente = !_ascendente;
      } else {
        _orden = orden;
        _ascendente = true;
      }
    });
  }

  int _cuantos(GrupoNutriente? g) => widget.analisis.nutrientes.where((n) => g == null || n.grupo == g).length;

  @override
  Widget build(BuildContext context) {
    final visibles = _visibles;
    return ListView(
      padding: const EdgeInsets.only(bottom: EqSpace.xl),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(EqSpace.md, EqSpace.md, EqSpace.md, 0),
          child: _Resumen(widget.analisis, widget.objetivos),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(EqSpace.lg, EqSpace.lg, EqSpace.lg, EqSpace.sm),
          child: Text('Nutriente por nutriente', style: EqText.h4.copyWith(fontWeight: FontWeight.w600)),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: EqSpace.lg),
          child: Row(
            children: [
              for (final g in <GrupoNutriente?>[null, ...GrupoNutriente.values]) ...[
                EqChip(
                  texto: '${g?.nombre ?? 'Todos'} ${_cuantos(g)}',
                  activo: _grupo == g,
                  onTap: () => setState(() => _grupo = g),
                ),
                const SizedBox(width: EqSpace.sm),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(EqSpace.md, EqSpace.xs, EqSpace.md, 0),
          child: _BotonOrden(orden: _orden, ascendente: _ascendente, onElegir: _ordenar),
        ),
        const _Encabezado(),
        for (final (i, n) in visibles.indexed) ...[
          if (i > 0) const Divider(height: 1, indent: EqSpace.lg, endIndent: EqSpace.lg, color: EqColors.borderFaint),
          _FilaNutriente(
            n,
            abierto: _abiertos.contains(n),
            onTap: () => setState(() {
              if (!_abiertos.remove(n)) _abiertos.add(n);
            }),
          ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(EqSpace.lg, EqSpace.lg, EqSpace.lg, 0),
          child: Text(
            'La barra muestra el % cuantitativo de 0 a 200 %; la línea del centro es el objetivo diario. '
            'Toca un nutriente para ver su objetivo y la cantidad de la dieta.',
            style: EqText.caption.copyWith(letterSpacing: 0, color: EqColors.textFaint),
          ),
        ),
      ],
    );
  }
}

// ── Resumen ──────────────────────────────────────────────────────────────

class _Resumen extends StatelessWidget {
  const _Resumen(this.a, this.o);

  final AnalisisNutricional a;
  final ObjetivosDia? o;

  @override
  Widget build(BuildContext context) {
    final duracion = MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 900);
    return EqHero(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: duracion,
        curve: Curves.easeOutCubic,
        builder: (context, t, _) => Column(
          children: [
            Row(
              children: [
                _Anillo(valor: a.satisfaccion, progreso: t),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _BarraResumen('Macronutrientes', a.macronutrientes, t),
                      const SizedBox(height: 12),
                      _BarraResumen('Minerales', a.minerales, t),
                      const SizedBox(height: 12),
                      _BarraResumen('Vitaminas', a.vitaminas, t),
                    ],
                  ),
                ),
              ],
            ),
            if (o case final o? when o.indiceGlucemico > 0 || o.costo > 0 || o.agua > 0) ...[
              const SizedBox(height: EqSpace.md),
              const Divider(height: 1, color: Colors.white24),
              const SizedBox(height: 12),
              IntrinsicHeight(
                child: Row(
                  children: [
                    _Dato('Índice glucémico', fmtNum(o.indiceGlucemico), 'promedio'),
                    const VerticalDivider(width: 1, color: Colors.white24),
                    _Dato('Costo', '\$${o.costo.toStringAsFixed(2)}', 'por día'),
                    const VerticalDivider(width: 1, color: Colors.white24),
                    _Dato('Agua', '${o.agua.round()} ml', 'en alimentos'),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Anillo extends StatelessWidget {
  const _Anillo({required this.valor, required this.progreso});

  final double valor;
  final double progreso;

  @override
  Widget build(BuildContext context) {
    final color = _tono(valor) == _Tono.bien ? EqColors.primarySoft : _coral;
    return Semantics(
      label: 'Satisfacción general: ${fmtNum(valor)} %',
      child: SizedBox(
        width: 104,
        child: Column(
          children: [
            CustomPaint(
              painter: _PintorAnillo(fraccion: valor / 100 * progreso, color: color),
              child: SizedBox.square(
                dimension: 96,
                child: Center(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: '${(valor * progreso).round()}'),
                        TextSpan(
                          text: '%',
                          style: EqText.h4.copyWith(color: Colors.white70),
                        ),
                      ],
                    ),
                    style: EqText.h1.copyWith(color: Colors.white, fontSize: 30, height: 1),
                  ),
                ),
              ),
            ),
            const SizedBox(height: EqSpace.sm),
            Text(
              'Satisfacción general',
              textAlign: TextAlign.center,
              style: EqText.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w600, letterSpacing: 0),
            ),
          ],
        ),
      ),
    );
  }
}

class _PintorAnillo extends CustomPainter {
  _PintorAnillo({required this.fraccion, required this.color});

  final double fraccion;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const grosor = 9.0;
    final rect = Offset.zero & size;
    final area = rect.deflate(grosor / 2);
    final pista = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor
      ..color = Colors.white.withValues(alpha: 0.14);
    canvas.drawArc(area, 0, math.pi * 2, false, pista);
    if (fraccion <= 0) return;
    final arco = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(area, -math.pi / 2, math.pi * 2 * fraccion.clamp(0, 1), false, arco);
  }

  @override
  bool shouldRepaint(_PintorAnillo old) => old.fraccion != fraccion || old.color != color;
}

class _BarraResumen extends StatelessWidget {
  const _BarraResumen(this.nombre, this.valor, this.progreso);

  final String nombre;
  final double valor;
  final double progreso;

  @override
  Widget build(BuildContext context) {
    final color = _tono(valor) == _Tono.bien ? EqColors.primarySoft : _coral;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(nombre, style: EqText.caption.copyWith(color: Colors.white70, letterSpacing: 0)),
            ),
            Text(
              '${fmtNum(valor)} %',
              style: EqText.label.copyWith(color: color, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: (valor / 100 * progreso).clamp(0, 1).toDouble(),
            minHeight: 5,
            color: color,
            backgroundColor: Colors.white.withValues(alpha: 0.14),
          ),
        ),
      ],
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato(this.nombre, this.valor, this.nota);

  final String nombre;
  final String valor;
  final String nota;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(nombre, style: EqText.caption.copyWith(color: Colors.white70, letterSpacing: 0, fontSize: 11)),
          const SizedBox(height: 2),
          Text(
            valor,
            style: EqText.h4.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          Text(nota, style: EqText.caption.copyWith(color: Colors.white60, letterSpacing: 0, fontSize: 11)),
        ],
      ),
    );
  }
}

// ── Lista de nutrientes ──────────────────────────────────────────────────

class _BotonOrden extends StatelessWidget {
  const _BotonOrden({required this.orden, required this.ascendente, required this.onElegir});

  final _Orden orden;
  final bool ascendente;
  final ValueChanged<_Orden> onElegir;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: PopupMenuButton<_Orden>(
        tooltip: 'Ordenar nutrientes',
        onSelected: onElegir,
        itemBuilder: (_) => [
          for (final o in _Orden.values)
            PopupMenuItem(
              value: o,
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: o == orden
                        ? Icon(
                            ascendente ? Icons.arrow_upward : Icons.arrow_downward,
                            size: 18,
                            color: EqColors.primary,
                          )
                        : null,
                  ),
                  Text(o.etiqueta),
                ],
              ),
            ),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: EqSpace.sm, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sort, size: 18, color: EqColors.primary),
              const SizedBox(width: 6),
              Text('Orden: ${orden.etiqueta}', style: EqText.label.copyWith(color: EqColors.primary, fontSize: 13)),
              Icon(ascendente ? Icons.arrow_upward : Icons.arrow_downward, size: 14, color: EqColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

// Ancho de la columna derecha (el % cualitativo); la regla ocupa el resto.
const _anchoValor = 72.0;

/// Leyenda que alinea 0 / 100 / 200 % con las reglas de cada fila.
class _Encabezado extends StatelessWidget {
  const _Encabezado();

  @override
  Widget build(BuildContext context) {
    final estilo = EqText.caption.copyWith(color: EqColors.textFaint, letterSpacing: 0, fontSize: 11);
    return Padding(
      padding: const EdgeInsets.fromLTRB(EqSpace.lg, EqSpace.xs, EqSpace.lg, EqSpace.xs),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Text('0', style: estilo),
                const Spacer(),
                Text('100 % · objetivo', style: estilo),
                const Spacer(),
                Text('200 %', style: estilo),
              ],
            ),
          ),
          SizedBox(
            width: _anchoValor,
            child: Text('Cualitativo', textAlign: TextAlign.right, style: estilo),
          ),
        ],
      ),
    );
  }
}

class _FilaNutriente extends StatelessWidget {
  const _FilaNutriente(this.n, {required this.abierto, required this.onTap});

  final Nutriente n;
  final bool abierto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cualitativo = _colorTono(_tono(n.cualitativo));
    final cuantitativo = _colorTono(_tono(n.cuantitativo));
    return InkWell(
      onTap: onTap,
      child: AnimatedSize(
        duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(EqSpace.lg, 12, EqSpace.lg, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: n.nombre),
                              TextSpan(
                                text: '  ${n.unidad}',
                                style: EqText.caption.copyWith(letterSpacing: 0, color: EqColors.textFaint),
                              ),
                            ],
                          ),
                          style: EqText.label.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _Regla(valor: n.cuantitativo, color: cuantitativo),
                            ),
                            const SizedBox(width: EqSpace.sm),
                            Text(
                              '${fmtNum(n.cuantitativo)} %',
                              style: EqText.caption.copyWith(letterSpacing: 0, color: EqColors.textMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: _anchoValor,
                    child: Text(
                      '${fmtNum(n.cualitativo)}%',
                      textAlign: TextAlign.right,
                      style: EqText.h4.copyWith(color: cualitativo, fontWeight: FontWeight.w700, height: 1),
                    ),
                  ),
                ],
              ),
              if (abierto) _Detalle(n),
            ],
          ),
        ),
      ),
    );
  }
}

/// La regla 0–200 %: el relleno es el % cuantitativo y la marca central el objetivo.
class _Regla extends StatelessWidget {
  const _Regla({required this.valor, required this.color});

  final double valor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${fmtNum(valor)} % del objetivo',
      child: SizedBox(
        height: 12,
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            Container(
              height: 6,
              decoration: BoxDecoration(color: EqColors.surfaceHigh, borderRadius: BorderRadius.circular(3)),
            ),
            FractionallySizedBox(
              widthFactor: (valor / 200).clamp(0.02, 1).toDouble(),
              child: Container(
                height: 6,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: Container(width: 2, height: 12, color: EqColors.onSurfaceVar.withValues(alpha: 0.55)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Detalle extends StatelessWidget {
  const _Detalle(this.n);

  final Nutriente n;

  @override
  Widget build(BuildContext context) {
    final u = n.unidad;
    final falta = n.excDef >= 0;
    final datos = [
      ('Objetivo', '${fmtNum(n.objetivo)} $u'),
      ('Cantidad', '${fmtNum(n.cantidad)} $u'),
      (falta ? 'Falta (+Def)' : 'Sobra (-Exc)', '${falta ? '+' : ''}${fmtNum(n.excDef)}'),
      ('% cuantitativo', '${fmtNum(n.cuantitativo)} %'),
      ('% cualitativo', '${fmtNum(n.cualitativo)} %'),
      ('% zonas crec.', (n.zona ?? '').isEmpty ? '—' : n.zona!.replaceAll('.', ',')),
    ];
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: EqColors.surfaceLow, borderRadius: BorderRadius.circular(EqRadius.md)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, c) {
              const hueco = 8.0;
              final ancho = (c.maxWidth - hueco * 2) / 3;
              return Wrap(
                spacing: hueco,
                runSpacing: 10,
                children: [
                  for (final (etiqueta, valor) in datos)
                    SizedBox(
                      width: ancho,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            etiqueta,
                            style: EqText.caption.copyWith(letterSpacing: 0, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            valor,
                            style: EqText.label.copyWith(
                              fontWeight: FontWeight.w600,
                              color: etiqueta.startsWith('Falta') ? EqColors.warningText : EqColors.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Text(
            'SEC ${fmtNum(n.sec)} · ${n.grupo.nombre.toUpperCase()}',
            style: EqText.caption.copyWith(fontSize: 11, color: EqColors.primary),
          ),
        ],
      ),
    );
  }
}
