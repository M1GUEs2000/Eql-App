import 'package:flutter/material.dart';

import '../data/analisis.dart';
import '../data/api.dart';
import '../data/models.dart';
import '../theme/eq_tokens.dart';
import '../widgets/eq_basicos.dart';
import '../widgets/hoja_inferior.dart';

/// Abre los objetivos completos de la evaluación [fecha] en una hoja que sube
/// desde abajo, como el análisis nutricional. [nutricionista] elige la página
/// inicial; luego se pasa de una a otra deslizando o con las pestañas.
Future<void> verObjetivos(
  BuildContext context, {
  required String? fecha,
  bool nutricionista = false,
}) {
  return abrirHoja<void>(
    context,
    ObjetivosScreen(fecha: fecha, nutricionista: nutricionista),
  );
}

/// GET objetivos: el objetivo del usuario (`objetivoSistema`, calculado por
/// Equilibra) y el del nutricionista (`objetivoNutricionista`), cada uno con
/// todos sus nutrientes, en dos páginas deslizables.
class ObjetivosScreen extends StatefulWidget {
  const ObjetivosScreen({
    super.key,
    required this.fecha,
    this.nutricionista = false,
  });

  final String? fecha;
  final bool nutricionista;

  @override
  State<ObjetivosScreen> createState() => _ObjetivosScreenState();
}

class _ObjetivosScreenState extends State<ObjetivosScreen> {
  late final _paginas = PageController(
    initialPage: widget.nutricionista ? 1 : 0,
  );
  late var _pagina = widget.nutricionista ? 1 : 0;
  Json? _usuario;
  Json? _nutricionista;
  String? _fecha;
  String? _error;
  var _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _paginas.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final j = await Api.get('objetivos', {'fecha': widget.fecha}) as Json;
      if (!mounted) return;
      setState(() {
        _usuario = j['objetivoSistema'] as Json?;
        _nutricionista = j['objetivoNutricionista'] as Json?;
        _fecha = j['fechaEvaluacion'] as String? ?? widget.fecha;
      });
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.detalle);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _ir(int pagina) => _paginas.animateToPage(
    pagina,
    duration: const Duration(milliseconds: 280),
    curve: Curves.easeOutCubic,
  );

  @override
  Widget build(BuildContext context) {
    final fecha = _fecha;
    return HojaInferior(
      titulo: 'Objetivos diarios',
      subtitulo: fecha == null || fecha.isEmpty ? null : fechaVista(fecha),
      child: _cargando
          ? const Cargando()
          : _error != null
          ? ErrorCarga(_error!, onReintentar: _cargar)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    EqSpace.md,
                    EqSpace.md,
                    EqSpace.md,
                    EqSpace.sm,
                  ),
                  child: Row(
                    children: [
                      EqChip(
                        texto: 'Del usuario',
                        activo: _pagina == 0,
                        onTap: () => _ir(0),
                      ),
                      const SizedBox(width: EqSpace.sm),
                      EqChip(
                        texto: 'Del nutricionista',
                        activo: _pagina == 1,
                        onTap: () => _ir(1),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _paginas,
                    onPageChanged: (p) => setState(() => _pagina = p),
                    children: [
                      _PaginaObjetivo(
                        _usuario,
                        otro: _nutricionista,
                        origen: 'Calculado por Equilibra con tu evaluación',
                        vacio: 'Todavía no hay objetivos calculados para esta evaluación.',
                      ),
                      _PaginaObjetivo(
                        _nutricionista,
                        otro: _usuario,
                        origen: 'Fijado por tu nutricionista',
                        vacio: 'Tu nutricionista aún no ha fijado objetivos para esta evaluación.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// Campos de tbObj_usuario agrupados como en el análisis nutricional.
const _grupos = [
  (
    'Macronutrientes',
    [
      ('PROTS', 'Proteínas'),
      ('CHO', 'Carbohidratos'),
      ('AZUCART', 'Azúcares totales'),
      ('FIBRA', 'Fibra'),
      ('GRASA', 'Grasa total'),
      ('GRASAMINSA', 'Grasa monoinsaturada'),
      ('GRASAPINSA', 'Grasa poliinsaturada'),
      ('GRASASAT', 'Grasa saturada'),
      ('COLEST', 'Colesterol'),
      ('OMEGA3', 'Omega 3'),
    ],
  ),
  (
    'Vitaminas',
    [
      ('VITAA', 'Vitamina A'),
      ('VITAC', 'Vitamina C'),
      ('VITAD', 'Vitamina D'),
      ('VITAE', 'Vitamina E'),
      ('VITAB6', 'Vitamina B6'),
      ('VITAB12', 'Vitamina B12'),
      ('TIAMINA', 'Tiamina (B1)'),
      ('RIBOFLAVIN', 'Riboflavina (B2)'),
      ('NIACINA', 'Niacina (B3)'),
      ('FOLATO', 'Folato'),
    ],
  ),
  (
    'Minerales',
    [
      ('CALCIO', 'Calcio'),
      ('HIERRO', 'Hierro'),
      ('FOSFORO', 'Fósforo'),
      ('MAGNESIO', 'Magnesio'),
      ('POTASIO', 'Potasio'),
      ('SODIO', 'Sodio'),
      ('ZINC', 'Zinc'),
      ('SELENIO', 'Selenio'),
    ],
  ),
];

class _PaginaObjetivo extends StatelessWidget {
  const _PaginaObjetivo(
    this.o, {
    this.otro,
    required this.origen,
    required this.vacio,
  });

  final Json? o;
  final Json? otro;
  final String origen;
  final String vacio;

  @override
  Widget build(BuildContext context) {
    final o = this.o;
    if (o == null) {
      return ListView(
        padding: const EdgeInsets.all(EqSpace.md),
        children: [EqAviso(vacio, icono: Icons.flag_outlined)],
      );
    }
    // El JSON viene en camelCase ("vitaB6", "h2O"): se busca sin distinguir mayúsculas.
    final valores = {for (final e in o.entries) e.key.toLowerCase(): e.value};
    double v(String campo) => numero(valores[campo.toLowerCase()]);

    final otroMap = otro != null && otro!.isNotEmpty
        ? {for (final e in otro!.entries) e.key.toLowerCase(): e.value}
        : null;
    double? vOtro(String campo) =>
        otroMap == null ? null : numero(otroMap[campo.toLowerCase()]);

    final agua = v('H2O');
    final aguaOtro = vOtro('H2O');
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        EqSpace.md,
        EqSpace.xs,
        EqSpace.md,
        EqSpace.xl,
      ),
      children: [
        EqHero(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CALORÍAS POR DÍA',
                style: EqText.caption.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '${v('KCALS').round()}'),
                      if (otroMap != null)
                        TextSpan(
                          text: ' (${vOtro('KCALS')!.round()})',
                          style: EqText.h2.copyWith(
                            color: EqColors.primarySoft,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      TextSpan(
                        text: ' kcal',
                        style: EqText.body.copyWith(
                          color: EqColors.primarySoft,
                        ),
                      ),
                    ],
                  ),
                  style: EqText.h1.copyWith(color: Colors.white),
                ),
              ),
              Text(
                origen,
                style: EqText.bodySm.copyWith(color: EqColors.primarySoft),
              ),
              const SizedBox(height: EqSpace.md),
              const Divider(height: 1, color: Colors.white24),
              const SizedBox(height: 12),
              IntrinsicHeight(
                child: Row(
                  children: [
                    _DatoHero(
                      'Quemar',
                      '${v('Egreso').round()}',
                      'kcal por día',
                      otro: otroMap == null
                          ? null
                          : '${vOtro('Egreso')!.round()}',
                    ),
                    const VerticalDivider(width: 1, color: Colors.white24),
                    _DatoHero(
                      'Cambio de peso',
                      fmtNum(v('Dif_peso'), 1),
                      'kg',
                      otro: otroMap == null
                          ? null
                          : fmtNum(vOtro('Dif_peso')!, 1),
                    ),
                    const VerticalDivider(width: 1, color: Colors.white24),
                    _DatoHero(
                      'Plazo',
                      '${v('Dias').round()}',
                      'días',
                      otro: otroMap == null
                          ? null
                          : '${vOtro('Dias')!.round()}',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        for (final (titulo, campos) in _grupos) ...[
          const SizedBox(height: EqSpace.lg),
          Text(titulo, style: EqText.h4.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: EqSpace.sm),
          _Tabla([
            for (final (campo, nombre) in campos)
              (nombre, v(campo), vOtro(campo), unidadNutriente(campo)),
          ]),
        ],
        if (agua > 0 || (aguaOtro != null && aguaOtro > 0)) ...[
          const SizedBox(height: EqSpace.lg),
          Text('Otros', style: EqText.h4.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: EqSpace.sm),
          _Tabla([('Agua', agua, aguaOtro, 'ml')]),
        ],
      ],
    );
  }
}

class _DatoHero extends StatelessWidget {
  const _DatoHero(this.nombre, this.valor, this.nota, {this.otro});

  final String nombre;
  final String valor;
  final String? otro;
  final String nota;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            nombre,
            style: EqText.caption.copyWith(
              color: Colors.white70,
              letterSpacing: 0,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text.rich(
              TextSpan(
                style: EqText.h4.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
                children: [
                  TextSpan(text: valor),
                  if (otro != null)
                    TextSpan(
                      text: ' ($otro)',
                      style: EqText.bodySm.copyWith(
                        color: EqColors.primarySoft,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ),
          Text(
            nota,
            style: EqText.caption.copyWith(
              color: Colors.white60,
              letterSpacing: 0,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// Lista nombre → valor (con valor de comparación opcional entre paréntesis) y unidad.
class _Tabla extends StatelessWidget {
  const _Tabla(this.filas);

  final List<(String, double, double?, String)> filas;

  @override
  Widget build(BuildContext context) {
    return EqCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final (i, (nombre, valor, otro, unidad)) in filas.indexed) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: EqSpace.md,
                endIndent: EqSpace.md,
                color: EqColors.borderFaint,
              ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: EqSpace.md,
                vertical: 12,
              ),
              child: Row(
                children: [
                  Expanded(child: Text(nombre, style: EqText.body)),
                  Text.rich(
                    TextSpan(
                      style: EqText.label.copyWith(fontWeight: FontWeight.w700),
                      children: [
                        TextSpan(text: fmtNum(valor)),
                        if (otro != null)
                          TextSpan(
                            text: ' (${fmtNum(otro)})',
                            style: EqText.bodySm.copyWith(
                              color: EqColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (unidad.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 52,
                      child: Text(
                        unidad,
                        style: EqText.bodySm.copyWith(
                          color: EqColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
