import 'package:flutter/material.dart';

import '../data/api.dart';
import '../data/cambios.dart';
import '../data/models.dart';
import '../theme/eq_tokens.dart';
import 'eq_basicos.dart';
import 'hoja_inferior.dart';

/// Los tres formularios de GET/POST datos-paciente/{antropometricos,clinicos,laboratorio}.
enum FichaDatos {
  antropometricos('Datos antropométricos', 'antropometricos'),
  clinicos('Datos clínicos', 'clinicos'),
  laboratorio('Datos de laboratorio', 'laboratorio');

  const FichaDatos(this.titulo, this.ruta);
  final String titulo;
  final String ruta;
}

Future<void> editarDatos(BuildContext context, FichaDatos ficha) => abrirHoja<void>(context, _HojaDatos(ficha));

enum _Tipo { numero, siNo, fecha, sexo, actividad }

class _Campo {
  const _Campo(this.clave, this.etiqueta, this.tipo, {this.unidad, this.siActivo, this.porDefecto = ''});

  final String clave;
  final String etiqueta;
  final _Tipo tipo;
  final String? unidad;

  /// Solo se muestra si este otro campo SI/NO está en SI.
  final String? siActivo;
  final String porDefecto;
}

class _Seccion {
  const _Seccion(this.titulo, this.campos, {this.soloMujeres = false});

  final String titulo;
  final List<_Campo> campos;
  final bool soloMujeres;
}

const _muneca = 'ndCircMuñeca';

// Mismas preguntas y rangos que las vistas de DatosPaciente de la web.
const _formularios = {
  FichaDatos.antropometricos: [
    _Seccion('Identificación', [
      _Campo('ndFecNacimiento', 'Fecha de nacimiento', _Tipo.fecha),
      _Campo('ndSexo', 'Sexo biológico', _Tipo.sexo, porDefecto: 'Masculino'),
      _Campo('ndActividad', 'Nivel de actividad', _Tipo.actividad),
    ]),
    _Seccion('Medidas', [
      _Campo('ndEstatura', 'Estatura (50 – 250)', _Tipo.numero, unidad: 'cm'),
      _Campo('ndPesoKg', 'Peso (2 – 400)', _Tipo.numero, unidad: 'kg'),
      _Campo(_muneca, 'Circunferencia de muñeca (10 – 25)', _Tipo.numero, unidad: 'cm'),
      _Campo('nd11200', 'Circunferencia de cintura (desde los 19 años)', _Tipo.numero, unidad: 'cm'),
      _Campo('nd11210', 'Circunferencia de cadera (desde los 19 años)', _Tipo.numero, unidad: 'cm'),
    ]),
  ],
  FichaDatos.clinicos: [
    _Seccion('Presión arterial', [
      _Campo('nd10100', '¿Tiene la presión arterial elevada?', _Tipo.siNo),
      _Campo('nd10101', 'Presión sistólica', _Tipo.numero, unidad: 'mmHg', porDefecto: '120'),
      _Campo('nd10102', 'Presión diastólica', _Tipo.numero, unidad: 'mmHg', porDefecto: '80'),
    ]),
    _Seccion('Diabetes', [
      _Campo('nd10150', '¿Padece usted de diabetes?', _Tipo.siNo),
      _Campo('nd10160', '¿Utiliza insulina?', _Tipo.siNo, siActivo: 'nd10150'),
      _Campo('nd10170', '¿Toma antidiabéticos orales?', _Tipo.siNo, siActivo: 'nd10150'),
      _Campo('nd10180', '¿La diabetes le ha provocado daño renal?', _Tipo.siNo, siActivo: 'nd10150'),
    ]),
    _Seccion('Condiciones generales', [
      _Campo('nd10300', '¿Se le ha diagnosticado insuficiencia renal?', _Tipo.siNo),
      _Campo('nd10450', '¿Es usted un/a atleta muy musculoso/a?', _Tipo.siNo),
      _Campo('nd10480', '¿Le han diagnosticado «gota»?', _Tipo.siNo),
      _Campo('nd10500', '¿Sus padres o hermanos sufrieron infarto antes de los 55 años?', _Tipo.siNo),
      _Campo('nd10600', '¿Usted ha tenido infarto al corazón o angina de pecho?', _Tipo.siNo),
      _Campo('nd10700', '¿Ha completado una dieta supervisada de 6 meses?', _Tipo.siNo),
      _Campo('nd11100', '¿Ingiere bebidas alcohólicas una o más veces por semana?', _Tipo.siNo),
      _Campo('nd11101', '¿Su médico le ha diagnosticado anemia?', _Tipo.siNo),
      _Campo('nd11102', '¿Ha sido diagnosticado de cálculos renales de calcio?', _Tipo.siNo),
      _Campo('nd11103', '¿Ha sido diagnosticado de cálculos renales de ácido úrico?', _Tipo.siNo),
      _Campo('nd11000', '¿Mantiene exposición frecuente al sol?', _Tipo.siNo),
      _Campo('nd10900', '¿Alguno de sus padres vivió o vive más de 70 años?', _Tipo.siNo),
    ]),
    _Seccion('Embarazo y lactancia', soloMujeres: true, [
      _Campo('nd10460', '¿Está usted embarazada?', _Tipo.siNo),
      _Campo('nd10461', 'Mes de embarazo (0 – 9)', _Tipo.numero, siActivo: 'nd10460', porDefecto: '0'),
      _Campo('nd10470', '¿Está dando de lactar?', _Tipo.siNo),
      _Campo('nd10471', 'Mes de lactancia', _Tipo.numero, siActivo: 'nd10470', porDefecto: '0'),
    ]),
    _Seccion('Riesgo de infarto cardíaco', [
      _Campo('nd10400', '¿Fuma actualmente?', _Tipo.siNo),
      _Campo('nd10401', 'Cigarrillos al día', _Tipo.numero, siActivo: 'nd10400', porDefecto: '0'),
      _Campo('nd10402', '¿Fumaba en el pasado?', _Tipo.siNo),
      _Campo('nd10403', 'Cigarrillos que fumaba al día', _Tipo.numero, siActivo: 'nd10402', porDefecto: '0'),
      _Campo('nd10404', 'Años desde que dejó de fumar', _Tipo.numero, siActivo: 'nd10402', porDefecto: '0'),
      _Campo('nd10800', '¿Su médico le informó que tiene crecimiento ventricular izquierdo?', _Tipo.siNo),
    ]),
  ],
  FichaDatos.laboratorio: [
    _Seccion('Exámenes', [
      _Campo('ndGlucosa', 'Glucosa en ayunas', _Tipo.numero, unidad: 'mg/dL'),
      _Campo('ndTriglicerido', 'Triglicéridos', _Tipo.numero, unidad: 'mg/dL'),
      _Campo('ndColesterol', 'Colesterol total', _Tipo.numero, unidad: 'mg/dL'),
      _Campo('ndLDL', 'LDL', _Tipo.numero, unidad: 'mg/dL'),
      _Campo('ndHDL', 'HDL', _Tipo.numero, unidad: 'mg/dL'),
      _Campo('ndAcidoUrico', 'Ácido úrico', _Tipo.numero, unidad: 'mg/dL'),
      _Campo('ndHemoglobina', 'Hemoglobina', _Tipo.numero, unidad: 'g/dL'),
      _Campo('ndHematocrito', 'Hematocrito', _Tipo.numero, unidad: '%'),
      _Campo('ndCreatinina', 'Creatinina', _Tipo.numero, unidad: 'mg/dL'),
    ]),
  ],
};

// Valores de ndActividad del formulario web; "Deportista" lleva además el deporte: "Deportista;21".
const _actividades = {
  'Sedentario': 'Sedentario (poco o nada)',
  'Moderadamente Activo': 'Moderado (3-5 días/semana)',
  'Activo': 'Activo (5-6 días/semana)',
  'Superactivo': 'Muy activo (todos los días)',
  'Deportista': 'Deportista de alta intensidad',
};

class _HojaDatos extends StatefulWidget {
  const _HojaDatos(this.ficha);

  final FichaDatos ficha;

  @override
  State<_HojaDatos> createState() => _HojaDatosState();
}

class _HojaDatosState extends State<_HojaDatos> {
  final _valores = <String, String>{};
  final _textos = <String, TextEditingController>{};
  var _deportes = <Opcion>[];
  var _cargando = true;
  var _guardando = false;
  var _esMujer = false;
  var _ndlab = false;
  var _ndcli = false;
  String? _aviso;
  String? _error;

  List<_Seccion> get _secciones => _formularios[widget.ficha]!;

  Iterable<_Campo> get _campos => _secciones.expand((s) => s.campos);

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    for (final c in _textos.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cargar() async {
    Map<String, dynamic> datos = const {};
    try {
      final r = await Api.get('datos-paciente/${widget.ficha.ruta}') as Json;
      datos = (r['datos'] as Json?) ?? const {};
      _deportes = [for (final d in (r['lstDeportes'] as List?) ?? const []) Opcion.desdeJson(d as Json)];
      if (r['tieneDatos'] == false) _aviso = 'Todavía no hay datos registrados. Complete el formulario y guárdelo.';
    } on ApiError {
      // GET antropométricos responde 500 cuando el usuario aún no tiene datos.
      _aviso = 'No se encontraron datos guardados. Complete el formulario y guárdelo.';
    }
    if (!mounted) return;
    setState(() {
      for (final c in _campos) {
        final v = datos[c.clave];
        final texto = v == null || '$v'.trim().isEmpty ? c.porDefecto : '$v'.trim();
        if (c.tipo == _Tipo.numero) {
          _textos[c.clave] = TextEditingController(text: texto);
        } else {
          _valores[c.clave] = c.tipo == _Tipo.siNo && texto.isEmpty ? 'NO' : texto;
        }
      }
      _esMujer = datos['sexo'] == 'F' || datos['ndSexo'] == 'Femenino';
      _ndlab = datos['ndlab'] as bool? ?? false;
      _ndcli = datos['ndcli'] as bool? ?? false;
      _cargando = false;
    });
  }

  bool _visible(_Campo c) => c.siActivo == null || _valores[c.siActivo] == 'SI';

  Future<void> _guardar() async {
    setState(() {
      _guardando = true;
      _error = null;
    });
    final cuerpo = <String, Object?>{
      for (final c in _campos)
        c.clave: c.tipo == _Tipo.numero ? _textos[c.clave]!.text.trim().replaceAll(',', '.') : _valores[c.clave],
      if (widget.ficha != FichaDatos.laboratorio) 'ndlab': _ndlab,
      if (widget.ficha == FichaDatos.antropometricos) 'ndcli': _ndcli,
    };
    try {
      await Api.post('datos-paciente/${widget.ficha.ruta}', cuerpo);
      if (!mounted) return;
      final mensajero = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      mensajero.showSnackBar(SnackBar(content: Text(Api.ultimoMensaje ?? 'Datos guardados')));
      Cambios.avisar();
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.detalle);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return HojaInferior(
      titulo: widget.ficha.titulo,
      subtitulo: 'Se guardan con las mismas reglas de la web',
      pie: _cargando
          ? null
          : PieFormulario(
              texto: _guardando ? 'Guardando...' : 'Guardar',
              onPressed: _guardando ? null : _guardar,
              error: _error,
            ),
      child: _cargando
          ? const Cargando()
          : ListView(
              padding: const EdgeInsets.all(EqSpace.lg),
              children: [
                if (_aviso != null) ...[EqAviso(_aviso!), const SizedBox(height: EqSpace.md)],
                for (final s in _secciones)
                  if (!s.soloMujeres || _esMujer) ...[
                    Text(s.titulo.toUpperCase(), style: EqText.caption.copyWith(color: EqColors.primary)),
                    const SizedBox(height: EqSpace.sm),
                    for (final c in s.campos)
                      if (_visible(c)) Padding(padding: const EdgeInsets.only(bottom: 12), child: _control(c)),
                    const SizedBox(height: EqSpace.sm),
                  ],
              ],
            ),
    );
  }

  Widget _control(_Campo c) {
    return switch (c.tipo) {
      _Tipo.numero => EqField(
        etiqueta: c.etiqueta,
        child: TextField(
          controller: _textos[c.clave],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(suffixText: c.unidad),
        ),
      ),
      _Tipo.siNo => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(c.etiqueta, style: EqText.bodySm.copyWith(color: EqColors.onSurface)),
        value: _valores[c.clave] == 'SI',
        onChanged: (v) => setState(() => _valores[c.clave] = v ? 'SI' : 'NO'),
      ),
      _Tipo.fecha => EqField(
        etiqueta: c.etiqueta,
        child: InkWell(
          onTap: () => _elegirFecha(c.clave),
          child: InputDecorator(
            decoration: const InputDecoration(suffixIcon: Icon(Icons.calendar_today_outlined)),
            child: Text(
              (_valores[c.clave] ?? '').isEmpty ? 'dd/mm/aaaa' : fechaVista(_valores[c.clave]!),
              style: EqText.body,
            ),
          ),
        ),
      ),
      _Tipo.sexo => EqField(
        etiqueta: c.etiqueta,
        child: SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'Masculino', label: Text('Masculino')),
            ButtonSegment(value: 'Femenino', label: Text('Femenino')),
          ],
          selected: {_valores[c.clave] == 'Femenino' ? 'Femenino' : 'Masculino'},
          onSelectionChanged: (s) => setState(() => _valores[c.clave] = s.first),
        ),
      ),
      _Tipo.actividad => _Actividad(
        valor: _valores[c.clave] ?? '',
        deportes: _deportes,
        onCambio: (v) => setState(() => _valores[c.clave] = v),
      ),
    };
  }

  Future<void> _elegirFecha(String clave) async {
    final hoy = DateTime.now();
    final fecha = await showDatePicker(
      context: context,
      initialDate: leerFechaApi(_valores[clave]) ?? DateTime(hoy.year - 30),
      firstDate: DateTime(1900),
      lastDate: hoy,
    );
    if (fecha != null) setState(() => _valores[clave] = fechaApi(fecha));
  }
}

class _Actividad extends StatelessWidget {
  const _Actividad({required this.valor, required this.deportes, required this.onCambio});

  final String valor;
  final List<Opcion> deportes;
  final ValueChanged<String> onCambio;

  @override
  Widget build(BuildContext context) {
    final [nivel, deporte] = [...valor.split(';'), ''].take(2).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EqField(
          etiqueta: 'Nivel de actividad',
          child: DropdownButtonFormField<String>(
            initialValue: _actividades.containsKey(nivel) ? nivel : null,
            hint: const Text('Escoja su nivel de actividad'),
            isExpanded: true,
            items: [for (final a in _actividades.entries) DropdownMenuItem(value: a.key, child: Text(a.value))],
            onChanged: (v) => onCambio(v!),
          ),
        ),
        if (nivel == 'Deportista' && deportes.isNotEmpty) ...[
          const SizedBox(height: 12),
          EqField(
            etiqueta: 'Deporte o disciplina',
            child: DropdownButtonFormField<String>(
              initialValue: deportes.any((d) => d.valor == deporte) ? deporte : null,
              hint: const Text('Escoja el deporte'),
              isExpanded: true,
              items: [for (final d in deportes) DropdownMenuItem(value: d.valor, child: Text(d.texto))],
              onChanged: (v) => onCambio('Deportista;$v'),
            ),
          ),
        ],
      ],
    );
  }
}
