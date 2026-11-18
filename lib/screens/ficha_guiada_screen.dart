import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/api.dart';
import '../data/models.dart';
import '../theme/eq_tokens.dart';
import '../widgets/eq_basicos.dart';
import '../widgets/popup_datos.dart' show nivelesActividad;
import 'crear_gasto_screen.dart' show abrirHojaActividad;
import 'shell_screen.dart';

/// Asistente posterior al registro: una pregunta por pantalla, con Anterior y
/// Continuar. No se puede salir hasta terminar. Guarda en la API al cerrar cada
/// bloque: antropométricos (obligatorios), clínicos y laboratorio (opcionales)
/// y, al final, aplica un plan de gasto calórico que se puede ajustar.
class FichaGuiadaScreen extends StatefulWidget {
  const FichaGuiadaScreen({super.key});

  @override
  State<FichaGuiadaScreen> createState() => _FichaGuiadaScreenState();
}

enum _Tipo {
  fecha,
  sexo,
  actividad,
  numero,
  medida,
  siNo,
  planGasto,
  resumenGasto,
}

/// Slider con unidad alterna. La API recibe siempre la unidad base (cm, kg).
class _Medida {
  const _Medida({
    required this.alterna,
    required this.factor,
    required this.inicial,
    required this.paso,
    required this.pasoAlterno,
  });

  final String alterna;

  /// Unidades base por cada unidad alterna (1 in = 2,54 cm).
  final double factor;
  final double inicial;
  final double paso;
  final double pasoAlterno;
}

const _medidas = {
  'ndEstatura': _Medida(
    alterna: 'in',
    factor: 2.54,
    inicial: 165,
    paso: 1,
    pasoAlterno: 0.5,
  ),
  'ndPesoKg': _Medida(
    alterna: 'lb',
    factor: 0.45359237,
    inicial: 70,
    paso: 0.5,
    pasoAlterno: 1,
  ),
  'ndCircMuñeca': _Medida(
    alterna: 'in',
    factor: 2.54,
    inicial: 16,
    paso: 0.5,
    pasoAlterno: 0.25,
  ),
  'nd11200': _Medida(
    alterna: 'in',
    factor: 2.54,
    inicial: 85,
    paso: 1,
    pasoAlterno: 0.5,
  ),
  'nd11210': _Medida(
    alterna: 'in',
    factor: 2.54,
    inicial: 95,
    paso: 1,
    pasoAlterno: 0.5,
  ),
};

enum _Bloque {
  antropometricos('Datos antropométricos'),
  clinicos('Datos clínicos'),
  laboratorio('Datos de laboratorio'),
  gasto('Gasto calórico');

  const _Bloque(this.titulo);
  final String titulo;
}

class _Paso {
  const _Paso(
    this.clave,
    this.bloque,
    this.pregunta,
    this.tipo, {
    this.ayuda,
    this.unidad = '',
    this.min = 0,
    this.max = 0,
    this.obligatorio = true,
  });

  final String clave;
  final _Bloque bloque;
  final String pregunta;
  final _Tipo tipo;
  final String? ayuda;
  final String unidad;
  final double min;
  final double max;
  final bool obligatorio;

  /// "¿Deseas llenar...?": los botones No / Sí reemplazan a Anterior / Continuar.
  bool get decision => clave.startsWith('llenar');

  // Clínicos y laboratorio llevan Omitir en lugar de Anterior; antropométricos
  // los exige la API y el gasto calórico es el cierre del asistente.
  bool get omitible =>
      (bloque == _Bloque.clinicos || bloque == _Bloque.laboratorio) &&
      !decision;
}

// La API exige estas cantidades (> 0) cuando la pregunta previa es SI: omitirlas
// deja esa pregunta en NO para que el guardado no se rechace.
const _preguntaPrevia = {
  'nd10401': 'nd10400',
  'nd10403': 'nd10402',
  'nd10461': 'nd10460',
  'nd10471': 'nd10470',
};

/// Número con punto decimal y a lo más un decimal, como lo espera la API: 70.5, 165.
String _aTexto(double v) =>
    v.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');

// Al continuar desde estos pasos se guarda el bloque en la API.
const _ultimoAntropometrico = 'nd11210';
const _ultimoClinico = 'nd10800';
const _ultimoLaboratorio = 'ndCreatinina';
const _pasoPlan = 'codigoPlan';

const _siNoClinicos = [
  'nd10100',
  'nd10150',
  'nd10160',
  'nd10170',
  'nd10180',
  'nd10300',
  'nd10450',
  'nd10460',
  'nd10470',
  'nd10480',
  'nd10500',
  'nd10600',
  'nd10700',
  'nd10900',
  'nd11000',
  'nd11100',
  'nd11101',
  'nd11102',
  'nd11103',
  'nd10400',
  'nd10402',
  'nd10800',
];

// Valor que se envía cuando la pregunta no se mostró (la respuesta previa fue NO).
const _numerosClinicos = {
  'nd10101': '120',
  'nd10102': '80',
  'nd10401': '0',
  'nd10403': '0',
  'nd10404': '0',
  'nd10461': '0',
  'nd10471': '0',
};

const _camposLaboratorio = [
  'ndGlucosa',
  'ndTriglicerido',
  'ndColesterol',
  'ndLDL',
  'ndHDL',
  'ndAcidoUrico',
  'ndHemoglobina',
  'ndHematocrito',
  'ndCreatinina',
];

class _FichaGuiadaScreenState extends State<FichaGuiadaScreen> {
  final _valores = <String, String>{};
  final _textos = <String, TextEditingController>{};
  var _deportes = <Opcion>[];
  var _planes = <Opcion>[];
  String? _errorPlanes;

  /// Plan de gasto aplicado en el paso de planes; lo muestra el resumen.
  PlanGasto? _gasto;
  var _i = 0;
  var _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarDeportes();
    _cargarPlanes();
  }

  Future<void> _cargarPlanes() async {
    setState(() => _errorPlanes = null);
    try {
      final plan = PlanGasto.desdeJson(await Api.get('gasto-calorico') as Json);
      if (mounted) setState(() => _planes = plan.planes);
    } on ApiError catch (e) {
      if (mounted) setState(() => _errorPlanes = e.detalle);
    }
  }

  Future<void> _cargarGasto(String fecha) async {
    final plan = PlanGasto.desdeJson(
      await Api.get('gasto-calorico', {'fecha': fecha}) as Json,
    );
    if (mounted) setState(() => _gasto = plan);
  }

  Future<void> _editarActividad(Actividad actividad) async {
    final fecha = _gasto?.fecha;
    if (fecha == null) return;
    final guardado = await abrirHojaActividad(
      context,
      fecha: fecha,
      actividad: actividad,
    );
    if (guardado != true) return;
    try {
      await _cargarGasto(fecha);
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.detalle);
    }
  }

  @override
  void dispose() {
    for (final c in _textos.values) {
      c.dispose();
    }
    for (final c in _ruedas.values) {
      c.dispose();
    }
    super.dispose();
  }

  // La lista de deportes viene con GET antropométricos; sin ella "Deportista" se guarda solo.
  Future<void> _cargarDeportes() async {
    try {
      final r = await Api.get('datos-paciente/antropometricos') as Json;
      final deportes = [
        for (final d in (r['lstDeportes'] as List?) ?? const [])
          Opcion.desdeJson(d as Json),
      ];
      if (mounted) setState(() => _deportes = deportes);
    } on ApiError {
      // Usuario recién creado: la API puede no tener aún su registro.
    }
  }

  /// Controlador de cada ruleta por medida y unidad; se conserva entre builds
  /// para no cortar el giro, y uno nuevo arranca en el valor actual.
  final _ruedas = <String, FixedExtentScrollController>{};

  // Las ruletas arrancan en un valor típico para que haya algo que mover.
  TextEditingController _texto(String clave) => _textos.putIfAbsent(
    clave,
    () => TextEditingController(
      text: _medidas[clave] == null ? '' : _aTexto(_medidas[clave]!.inicial),
    ),
  );

  /// Claves de medida mostradas en la unidad alterna (in, lb).
  final _enAlterna = <String>{};

  String _numero(String clave) =>
      _texto(clave).text.trim().replaceAll(',', '.');

  int get _edad {
    final f = leerFechaApi(_valores['ndFecNacimiento']);
    if (f == null) return 0;
    final hoy = DateTime.now();
    var edad = hoy.year - f.year;
    if (DateTime(hoy.year, f.month, f.day).isAfter(hoy)) edad--;
    return edad;
  }

  // Se recalcula en cada build: las respuestas abren o cierran preguntas siguientes.
  List<_Paso> get _pasos {
    const a = _Bloque.antropometricos;
    const c = _Bloque.clinicos;
    const l = _Bloque.laboratorio;
    final edad = _edad;
    final adulto = edad > 18;
    final minimoCircunferencia = adulto ? 40.0 : 20.0;
    final opcional = adulto ? '' : ' Es opcional porque eres menor de 19 años.';
    bool si(String clave) => _valores[clave] == 'SI';
    _Paso sn(String clave, String pregunta, [String? ayuda]) =>
        _Paso(clave, c, pregunta, _Tipo.siNo, ayuda: ayuda);
    _Paso lab(
      String clave,
      String pregunta,
      double min,
      double max, [
      String unidad = 'mg/dL',
    ]) => _Paso(
      clave,
      l,
      pregunta,
      _Tipo.numero,
      unidad: unidad,
      min: min,
      max: max,
    );

    return [
      const _Paso('ndFecNacimiento', a, '¿Cuándo naciste?', _Tipo.fecha),
      const _Paso('ndSexo', a, '¿Cuál es tu sexo biológico?', _Tipo.sexo),
      const _Paso(
        'ndActividad',
        a,
        '¿Cuál es tu nivel de actividad física?',
        _Tipo.actividad,
      ),
      const _Paso(
        'ndEstatura',
        a,
        '¿Cuánto mides?',
        _Tipo.medida,
        unidad: 'cm',
        min: 50,
        max: 250,
      ),
      const _Paso(
        'ndPesoKg',
        a,
        '¿Cuánto pesas?',
        _Tipo.medida,
        unidad: 'kg',
        min: 2,
        max: 400,
      ),
      _Paso(
        'ndCircMuñeca',
        a,
        '¿Cuánto mide la circunferencia de tu muñeca?',
        _Tipo.medida,
        ayuda: 'Mídela con una cinta métrica alrededor del hueso de la muñeca.',
        unidad: 'cm',
        min: edad > 10 ? 10 : 5,
        max: 25,
      ),
      _Paso(
        'nd11200',
        a,
        '¿Cuánto mide tu cintura?',
        _Tipo.medida,
        ayuda: 'Mídela a la altura del ombligo.$opcional',
        unidad: 'cm',
        min: minimoCircunferencia,
        max: 250,
        obligatorio: adulto,
      ),
      _Paso(
        _ultimoAntropometrico,
        a,
        '¿Cuánto mide tu cadera?',
        _Tipo.medida,
        ayuda: 'Mídela en su parte más ancha.$opcional',
        unidad: 'cm',
        min: minimoCircunferencia,
        max: 250,
        obligatorio: adulto,
      ),
      sn(
        'llenarClinicos',
        '¿Deseas llenar tus datos clínicos?',
        'Son opcionales: presión arterial, diabetes, tabaquismo y antecedentes. '
            'Si no los llenas, Equilibra los completa por ti.',
      ),
      if (si('llenarClinicos')) ...[
        sn('nd10100', '¿Tienes la presión arterial elevada?'),
        if (si('nd10100')) ...[
          const _Paso(
            'nd10101',
            c,
            '¿Cuál es tu presión sistólica?',
            _Tipo.numero,
            ayuda: 'Es el valor alto de la medición: 120 en 120/80.',
            unidad: 'mmHg',
            min: 60,
            max: 260,
          ),
          const _Paso(
            'nd10102',
            c,
            '¿Cuál es tu presión diastólica?',
            _Tipo.numero,
            ayuda: 'Es el valor bajo de la medición: 80 en 120/80.',
            unidad: 'mmHg',
            min: 30,
            max: 160,
          ),
        ],
        sn('nd10150', '¿Padeces de diabetes?'),
        if (si('nd10150')) ...[
          sn('nd10160', '¿Utilizas insulina?'),
          sn('nd10170', '¿Tomas antidiabéticos orales?'),
          sn('nd10180', '¿La diabetes te ha provocado daño renal?'),
        ],
        sn('nd10300', '¿Se te ha diagnosticado insuficiencia renal?'),
        sn('nd10450', '¿Eres un/a atleta muy musculoso/a?'),
        sn('nd10480', '¿Te han diagnosticado «gota»?'),
        sn(
          'nd10500',
          '¿Tus padres o hermanos sufrieron un infarto antes de los 55 años?',
        ),
        sn('nd10600', '¿Has tenido un infarto al corazón o angina de pecho?'),
        sn('nd10700', '¿Has completado una dieta supervisada de 6 meses?'),
        sn(
          'nd11100',
          '¿Ingieres bebidas alcohólicas una o más veces por semana?',
        ),
        sn('nd11101', '¿Tu médico te ha diagnosticado anemia?'),
        sn('nd11102', '¿Te han diagnosticado cálculos renales de calcio?'),
        sn('nd11103', '¿Te han diagnosticado cálculos renales de ácido úrico?'),
        sn('nd11000', '¿Mantienes exposición frecuente al sol?'),
        sn('nd10900', '¿Alguno de tus padres vivió o vive más de 70 años?'),
        if (_valores['ndSexo'] == 'Femenino') ...[
          sn('nd10460', '¿Estás embarazada?'),
          if (si('nd10460'))
            const _Paso(
              'nd10461',
              c,
              '¿De cuántos meses estás embarazada?',
              _Tipo.numero,
              unidad: 'meses',
              min: 1,
              max: 9,
            ),
          sn('nd10470', '¿Estás dando de lactar?'),
          if (si('nd10470'))
            const _Paso(
              'nd10471',
              c,
              '¿Cuántos meses de lactancia llevas?',
              _Tipo.numero,
              unidad: 'meses',
              min: 1,
              max: 24,
            ),
        ],
        sn('nd10400', '¿Fumas actualmente?'),
        if (si('nd10400'))
          const _Paso(
            'nd10401',
            c,
            '¿Cuántos cigarrillos fumas al día?',
            _Tipo.numero,
            unidad: 'cigarrillos',
            min: 1,
            max: 100,
          ),
        sn('nd10402', '¿Fumabas en el pasado?'),
        if (si('nd10402')) ...[
          const _Paso(
            'nd10403',
            c,
            '¿Cuántos cigarrillos fumabas al día?',
            _Tipo.numero,
            unidad: 'cigarrillos',
            min: 1,
            max: 100,
          ),
          const _Paso(
            'nd10404',
            c,
            '¿Cuántos años hace que dejaste de fumar?',
            _Tipo.numero,
            unidad: 'años',
            min: 0,
            max: 80,
          ),
        ],
        sn(
          _ultimoClinico,
          '¿Tu médico te informó que tienes crecimiento ventricular izquierdo?',
        ),
      ],
      const _Paso(
        'llenarLaboratorio',
        l,
        '¿Deseas llenar tus datos de laboratorio?',
        _Tipo.siNo,
        ayuda:
            'Son opcionales: glucosa, colesterol, triglicéridos y otros exámenes de sangre. '
            'Si no los llenas, Equilibra los completa por ti. Se guardan solo si llenas los 9 exámenes.',
      ),
      if (si('llenarLaboratorio')) ...[
        lab('ndGlucosa', '¿Cuál es tu glucosa en ayunas?', 20, 600),
        lab('ndTriglicerido', '¿Cuáles son tus triglicéridos?', 10, 2000),
        lab('ndColesterol', '¿Cuál es tu colesterol total?', 50, 800),
        lab('ndLDL', '¿Cuál es tu colesterol LDL?', 10, 600),
        lab('ndHDL', '¿Cuál es tu colesterol HDL?', 5, 200),
        lab('ndAcidoUrico', '¿Cuál es tu ácido úrico?', 0.5, 20),
        lab('ndHemoglobina', '¿Cuál es tu hemoglobina?', 3, 25, 'g/dL'),
        lab('ndHematocrito', '¿Cuál es tu hematocrito?', 10, 70, '%'),
        lab(_ultimoLaboratorio, '¿Cuál es tu creatinina?', 0.1, 15),
      ],
      const _Paso(
        _pasoPlan,
        _Bloque.gasto,
        'Selecciona tu gasto calórico',
        _Tipo.planGasto,
        ayuda:
            'Elige el plan de actividades que más se parezca a tu semana. '
            'En el siguiente paso puedes ajustar cada actividad.',
      ),
      const _Paso(
        'resumenGasto',
        _Bloque.gasto,
        'Tu gasto calórico',
        _Tipo.resumenGasto,
        ayuda: 'Toca una actividad para editarla, o finaliza si así está bien.',
      ),
    ];
  }

  String? _validar(_Paso p) {
    switch (p.tipo) {
      case _Tipo.numero:
      case _Tipo.medida:
        final texto = _numero(p.clave);
        if (texto.isEmpty) {
          return p.obligatorio ? 'Ingresa un valor para continuar.' : null;
        }
        final n = double.tryParse(texto);
        if (n == null) return 'Ingresa un número válido.';
        if (n < p.min || n > p.max) {
          return 'Debe estar entre ${fmtNum(p.min)} y ${fmtNum(p.max)} ${p.unidad}.';
        }
        if (p.clave == 'nd10102' &&
            n >= double.parse(_numeroClinico('nd10101'))) {
          return 'La diastólica debe ser menor que la sistólica.';
        }
        return null;
      case _Tipo.fecha:
        return _valores[p.clave] == null
            ? 'Elige tu fecha de nacimiento.'
            : null;
      case _Tipo.actividad:
        final valor = _valores[p.clave];
        if (valor == null) return 'Elige tu nivel de actividad.';
        if (valor == 'Deportista' && _deportes.isNotEmpty) {
          return 'Elige tu deporte o disciplina.';
        }
        return null;
      case _Tipo.sexo:
      case _Tipo.siNo:
      case _Tipo.planGasto:
        return _valores[p.clave] == null
            ? 'Elige una opción para continuar.'
            : null;
      case _Tipo.resumenGasto:
        return _gasto == null ? 'Elige un plan de gasto calórico.' : null;
    }
  }

  Json _cuerpoAntropometricos() => {
    'ndFecNacimiento': _valores['ndFecNacimiento'],
    'ndSexo': _valores['ndSexo'],
    'ndActividad': _valores['ndActividad'],
    for (final c in [
      'ndEstatura',
      'ndPesoKg',
      'ndCircMuñeca',
      'nd11200',
      'nd11210',
    ])
      c: _numero(c),
    // Los POST de clínicos y laboratorio marcan ndcli/ndlab por su cuenta.
    'ndlab': false,
    'ndcli': false,
  };

  // Lo omitido o no mostrado va como NO o con su valor por defecto.
  String _numeroClinico(String clave) {
    final visible = _pasos.any((p) => p.clave == clave);
    final texto = _numero(clave);
    return visible && texto.isNotEmpty ? texto : _numerosClinicos[clave]!;
  }

  Json _cuerpoClinicos() {
    final visibles = {for (final p in _pasos) p.clave};
    return {
      for (final c in _siNoClinicos)
        c: visibles.contains(c) ? _valores[c] ?? 'NO' : 'NO',
      for (final c in _numerosClinicos.keys) c: _numeroClinico(c),
    };
  }

  // La API exige los 9 exámenes: si omitió alguno, laboratorio no se guarda.
  bool get _laboratorioCompleto =>
      _camposLaboratorio.every((c) => _numero(c).isNotEmpty);

  Json _cuerpoLaboratorio() => {
    for (final c in _camposLaboratorio) c: _numero(c),
  };

  Future<void> _continuar({bool omitir = false}) async {
    if (_guardando) return;
    final paso = _pasos[_i];
    if (omitir) {
      _valores.remove(paso.clave);
      _texto(paso.clave).clear();
      final previa = _preguntaPrevia[paso.clave];
      if (previa != null) _valores[previa] = 'NO';
    } else if (_validar(paso) != null) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      switch (paso.clave) {
        case _ultimoAntropometrico:
          await Api.post(
            'datos-paciente/antropometricos',
            _cuerpoAntropometricos(),
          );
        case _ultimoClinico:
          await Api.post('datos-paciente/clinicos', _cuerpoClinicos());
        case _ultimoLaboratorio when _laboratorioCompleto:
          await Api.post('datos-paciente/laboratorio', _cuerpoLaboratorio());
        case _pasoPlan:
          // Hoy: el gasto usa el peso que se acaba de guardar en antropométricos.
          final hoy = fechaApi(DateTime.now());
          await Api.post('gasto-calorico/aplicar-plan', {
            'fecha': hoy,
            'codigoPlan': _valores[_pasoPlan],
            'ajuGascal': 0,
          });
          await _cargarGasto(hoy);
      }
    } on ApiError catch (e) {
      if (mounted) {
        setState(() {
          _guardando = false;
          _error = e.detalle;
        });
      }
      return;
    }
    if (!mounted) return;
    if (_i + 1 >= _pasos.length) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => const ShellScreen(tutorial: true),
        ),
        (_) => false,
      );
      return;
    }
    setState(() {
      _guardando = false;
      _i++;
    });
  }

  void _anterior() {
    if (_i == 0 || _guardando) return;
    setState(() {
      _i--;
      _error = null;
    });
  }

  void _decidir(String valor) {
    _valores[_pasos[_i].clave] = valor;
    _continuar();
  }

  void _elegir(String clave, String valor) => setState(() {
    _valores[clave] = valor;
    _error = null;
  });

  @override
  Widget build(BuildContext context) {
    final pasos = _pasos;
    final paso = pasos[_i];
    final delBloque = pasos.where((p) => p.bloque == paso.bloque).toList();
    final posicion = delBloque.indexWhere((p) => p.clave == paso.clave) + 1;
    final esUltimo = _i == pasos.length - 1;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _anterior();
      },
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      EqSpace.lg,
                      EqSpace.lg,
                      EqSpace.lg,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                paso.bloque.titulo.toUpperCase(),
                                style: EqText.caption.copyWith(
                                  color: EqColors.primary,
                                ),
                              ),
                            ),
                            Text(
                              '$posicion de ${delBloque.length}',
                              style: EqText.caption,
                            ),
                          ],
                        ),
                        const SizedBox(height: EqSpace.sm),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(EqRadius.sm),
                          child: LinearProgressIndicator(
                            value: posicion / delBloque.length,
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      layoutBuilder: (actual, anteriores) => Stack(
                        alignment: Alignment.topCenter,
                        children: [...anteriores, ?actual],
                      ),
                      transitionBuilder: (child, animacion) => FadeTransition(
                        opacity: animacion,
                        child: SlideTransition(
                          position: Tween(
                            begin: const Offset(0.06, 0),
                            end: Offset.zero,
                          ).animate(animacion),
                          child: child,
                        ),
                      ),
                      child: SingleChildScrollView(
                        key: ValueKey(paso.clave),
                        padding: const EdgeInsets.all(EqSpace.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(paso.pregunta, style: EqText.h2),
                            if (paso.ayuda != null) ...[
                              const SizedBox(height: EqSpace.sm),
                              Text(paso.ayuda!, style: EqText.bodySm),
                            ],
                            const SizedBox(height: EqSpace.lg),
                            _control(paso),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      EqSpace.lg,
                      0,
                      EqSpace.lg,
                      EqSpace.lg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_error != null) ...[
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: EqText.bodySm.copyWith(
                              color: EqColors.error,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (paso.decision)
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _guardando
                                      ? null
                                      : () => _decidir('NO'),
                                  child: const Text('No'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton(
                                  onPressed: _guardando
                                      ? null
                                      : () => _decidir('SI'),
                                  child: _guardando
                                      ? const SizedBox.square(
                                          dimension: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text('Sí'),
                                ),
                              ),
                            ],
                          )
                        else
                          Row(
                            children: [
                              if (paso.omitible) ...[
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _guardando
                                        ? null
                                        : () => _continuar(omitir: true),
                                    child: const Text('Omitir'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ] else if (_i > 0) ...[
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _guardando ? null : _anterior,
                                    child: const Text('Anterior'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              Expanded(
                                child: FilledButton(
                                  // Desactivado hasta que la respuesta sea válida.
                                  onPressed:
                                      _guardando || _validar(paso) != null
                                      ? null
                                      : _continuar,
                                  child: _guardando
                                      ? const SizedBox.square(
                                          dimension: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Text(
                                          esUltimo ? 'Finalizar' : 'Continuar',
                                        ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _control(_Paso p) {
    switch (p.tipo) {
      case _Tipo.numero:
        // El aviso aparece en cuanto escribe algo fuera de rango; vacío solo desactiva Continuar.
        final aviso = _numero(p.clave).isEmpty ? null : _validar(p);
        return TextField(
          controller: _texto(p.clave),
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          style: EqText.h3,
          onChanged: (_) => setState(() => _error = null),
          onSubmitted: (_) => _continuar(),
          decoration: InputDecoration(
            hintText: 'Entre ${fmtNum(p.min)} y ${fmtNum(p.max)}',
            suffixText: p.unidad,
            helperText: p.obligatorio ? null : 'Opcional',
            errorText: aviso,
            errorMaxLines: 2,
          ),
        );
      case _Tipo.fecha:
        final fecha = _valores[p.clave];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: _elegirFecha,
              child: InputDecorator(
                decoration: const InputDecoration(
                  suffixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: Text(
                  fecha == null
                      ? 'Toca para elegir (dd/mm/aaaa)'
                      : fechaVista(fecha),
                  style: EqText.body,
                ),
              ),
            ),
            if (fecha != null) ...[
              const SizedBox(height: EqSpace.sm),
              Text('Tienes $_edad años', style: EqText.bodySm),
            ],
          ],
        );
      case _Tipo.sexo:
        return Column(
          children: [
            for (final (valor, icono) in [
              ('Masculino', Icons.male),
              ('Femenino', Icons.female),
            ])
              _Opcion(
                texto: valor,
                icono: icono,
                elegida: _valores[p.clave] == valor,
                onTap: () => _elegir(p.clave, valor),
              ),
          ],
        );
      case _Tipo.siNo when p.decision:
        return const SizedBox.shrink();
      case _Tipo.medida:
        return _medida(p, _medidas[p.clave]!);
      case _Tipo.planGasto:
        if (_planes.isEmpty) {
          return _errorPlanes == null
              ? const Cargando()
              : ErrorCarga(_errorPlanes!, onReintentar: _cargarPlanes);
        }
        return Column(
          children: [
            for (final plan in _planes)
              _Opcion(
                texto: plan.texto,
                icono: Icons.directions_run,
                elegida: _valores[p.clave] == plan.valor,
                onTap: () => _elegir(p.clave, plan.valor),
              ),
          ],
        );
      case _Tipo.resumenGasto:
        final gasto = _gasto;
        if (gasto == null) return const Cargando();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EqHero(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GASTO ENERGÉTICO TOTAL',
                    style: EqText.caption.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: EqSpace.xs),
                  Text.rich(
                    TextSpan(
                      style: EqText.display.copyWith(color: Colors.white),
                      children: [
                        TextSpan(text: '${gasto.totalDiario.round()}'),
                        TextSpan(
                          text: ' kcal/día',
                          style: EqText.body.copyWith(
                            color: EqColors.primarySoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (gasto.nombre.isNotEmpty)
                    Text(
                      gasto.nombre,
                      style: EqText.bodySm.copyWith(color: Colors.white70),
                    ),
                ],
              ),
            ),
            const SizedBox(height: EqSpace.lg),
            if (gasto.actividades.isEmpty)
              const EqAviso('Este plan no tiene actividades.')
            else
              for (final a in gasto.actividades)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: EqCard(
                    sombra: false,
                    onTap: () => _editarActividad(a),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                a.nombre,
                                style: EqText.label.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${a.vecesSemana}× por semana · ${fmtNum(a.tiempo)} ${a.unidad}',
                                style: EqText.bodySm,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${a.gastoDiario.round()} kcal',
                          style: EqText.label.copyWith(color: EqColors.primary),
                        ),
                        const SizedBox(width: EqSpace.sm),
                        Icon(
                          Icons.edit_outlined,
                          size: 20,
                          color: EqColors.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        );
      case _Tipo.siNo:
        return Column(
          children: [
            for (final (valor, texto) in [('SI', 'Sí'), ('NO', 'No')])
              _Opcion(
                texto: texto,
                elegida: _valores[p.clave] == valor,
                onTap: () => _elegir(p.clave, valor),
              ),
          ],
        );
      case _Tipo.actividad:
        final [nivel, deporte] = [
          ...(_valores[p.clave] ?? '').split(';'),
          '',
        ].take(2).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final a in nivelesActividad.entries)
              _Opcion(
                texto: a.value,
                elegida: nivel == a.key,
                onTap: () => _elegir(p.clave, a.key),
              ),
            if (nivel == 'Deportista' && _deportes.isNotEmpty) ...[
              const SizedBox(height: EqSpace.sm),
              EqField(
                etiqueta: 'Deporte o disciplina',
                child: DropdownButtonFormField<String>(
                  initialValue: _deportes.any((d) => d.valor == deporte)
                      ? deporte
                      : null,
                  hint: const Text('Escoge tu deporte'),
                  isExpanded: true,
                  items: [
                    for (final d in _deportes)
                      DropdownMenuItem(value: d.valor, child: Text(d.texto)),
                  ],
                  onChanged: (v) => _elegir(p.clave, 'Deportista;$v'),
                ),
              ),
            ],
          ],
        );
    }
  }

  Widget _medida(_Paso p, _Medida m) {
    final alterna = _enAlterna.contains(p.clave);
    final factor = alterna ? m.factor : 1.0;
    final paso = alterna ? m.pasoAlterno : m.paso;
    final unidad = alterna ? m.alterna : p.unidad;
    // Límites redondeados al paso para que la ruleta muestre valores limpios.
    final min = (p.min / factor / paso).ceil() * paso;
    final max = (p.max / factor / paso).floor() * paso;
    final base = double.tryParse(_numero(p.clave)) ?? m.inicial;
    final valor = ((base / factor / paso).round() * paso).clamp(min, max);
    final cantidad = ((max - min) / paso).round() + 1;
    final indice = ((valor - min) / paso).round();
    final equivalente = alterna
        ? '${fmtNum(base, 1)} ${p.unidad}'
        : '${fmtNum(base / m.factor, 1)} ${m.alterna}';
    final rueda = _ruedas.putIfAbsent(
      '${p.clave}|$alterna|$min',
      () => FixedExtentScrollController(initialItem: indice),
    );
    // La ruleta de la otra unidad quedó donde estaba: se alinea con el valor actual.
    if (rueda.hasClients && rueda.selectedItem != indice) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (rueda.hasClients) rueda.jumpToItem(indice);
      });
    }

    void fijar(int i) {
      HapticFeedback.selectionClick();
      setState(() {
        final v = ((min + i * paso) * factor).clamp(p.min, p.max);
        _texto(p.clave).text = _aTexto(v);
        _error = null;
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: false, label: Text(p.unidad)),
              ButtonSegment(value: true, label: Text(m.alterna)),
            ],
            selected: {alterna},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() {
              if (s.first) {
                _enAlterna.add(p.clave);
              } else {
                _enAlterna.remove(p.clave);
              }
            }),
          ),
        ),
        const SizedBox(height: EqSpace.md),
        SizedBox(
          height: 240,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Franja que marca el valor elegido.
              Container(
                height: 52,
                decoration: BoxDecoration(
                  color: EqColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(EqRadius.md),
                  border: Border.all(
                    color: EqColors.primary.withValues(alpha: 0.4),
                  ),
                ),
              ),
              ListWheelScrollView.useDelegate(
                controller: rueda,
                itemExtent: 52,
                diameterRatio: 1.4,
                physics: const FixedExtentScrollPhysics(),
                onSelectedItemChanged: fijar,
                childDelegate: ListWheelChildBuilderDelegate(
                  childCount: cantidad,
                  builder: (context, i) {
                    final elegido = i == indice;
                    return Center(
                      child: Text(
                        '${fmtNum(min + i * paso)} $unidad',
                        style: elegido
                            ? EqText.h2.copyWith(color: EqColors.primary)
                            : EqText.h4.copyWith(color: EqColors.textMuted),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: EqSpace.sm),
        Text(
          '≈ $equivalente',
          textAlign: TextAlign.center,
          style: EqText.bodySm,
        ),
      ],
    );
  }

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final fecha = await showDatePicker(
      context: context,
      initialDate:
          leerFechaApi(_valores['ndFecNacimiento']) ?? DateTime(hoy.year - 30),
      firstDate: DateTime(hoy.year - 120, hoy.month, hoy.day),
      lastDate: hoy,
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Fecha de nacimiento',
    );
    if (fecha != null) _elegir('ndFecNacimiento', fechaApi(fecha));
  }
}

/// Opción grande y tocable: una por fila.
class _Opcion extends StatelessWidget {
  const _Opcion({
    required this.texto,
    required this.elegida,
    required this.onTap,
    this.icono,
  });

  final String texto;
  final bool elegida;
  final VoidCallback onTap;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: EqCard(
        sombra: false,
        color: elegida ? EqColors.surfaceLow : null,
        borde: elegida ? EqColors.primary : null,
        onTap: onTap,
        child: Row(
          children: [
            if (icono != null) ...[
              Icon(icono, color: EqColors.primary),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                texto,
                style: EqText.body.copyWith(
                  color: EqColors.onSurface,
                  fontWeight: elegida ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            Icon(
              elegida
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: elegida ? EqColors.primary : EqColors.textFaint,
            ),
          ],
        ),
      ),
    );
  }
}
