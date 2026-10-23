import 'api.dart';

typedef Json = Map<String, dynamic>;

List<Json> _lista(Object? v) => [for (final e in (v as List?) ?? const []) e as Json];

/// Bloqueo del histórico que devuelven ingesta, gasto y evaluación.
String? _motivoBloqueo(Object? bloqueo) {
  if (bloqueo is! Json || bloqueo['bloqueado'] != true) return null;
  return bloqueo['motivo'] as String? ?? bloqueo['titulo'] as String? ?? 'Este registro está bloqueado por tu plan.';
}

// ── Alimentos ─────────────────────────────────────────────────────────────

/// Resultado de GET ingesta/alimentos/buscar: aporte nutricional por porción.
class AlimentoBusqueda {
  const AlimentoBusqueda({
    required this.codigo,
    required this.descripcion,
    required this.tipo,
    required this.nombreTipo,
    required this.kcal,
    required this.proteinas,
    required this.carbohidratos,
    required this.grasa,
  });

  factory AlimentoBusqueda.desdeJson(Json j) => AlimentoBusqueda(
    codigo: j['codPlatoAlimento'] as String? ?? '',
    descripcion: (j['descripcion'] as String? ?? '').trim(),
    tipo: j['tipo'] as String? ?? '',
    nombreTipo: (j['nombreTipo'] as String? ?? '').trim(),
    kcal: numero(j['kcals']),
    proteinas: numero(j['prots']),
    carbohidratos: numero(j['cho']),
    grasa: numero(j['grasa']),
  );

  final String codigo;
  final String descripcion;

  /// P para platos; en alimentos es la letra del grupo (A, C...).
  final String tipo;
  final String nombreTipo;
  final double kcal;
  final double proteinas;
  final double carbohidratos;
  final double grasa;

  bool get esPlato => tipo == 'P' || tipo == 'PU';

  /// Tipo que espera POST ingesta/alimentos: A, P o PU.
  String get tipoIngesta => esPlato ? tipo : 'A';

  @override
  bool operator ==(Object other) => other is AlimentoBusqueda && other.codigo == codigo && other.tipo == tipo;

  @override
  int get hashCode => Object.hash(codigo, tipo);
}

class Unidad {
  const Unidad(this.nombre, this.gramos);

  factory Unidad.desdeJson(Json j) => Unidad(j['nombreUnidad'] as String? ?? '', numero(j['pesoGramos']));

  final String nombre;
  final double gramos;
}

// ── Ingesta ───────────────────────────────────────────────────────────────

/// Un registro de la ingesta (cada elemento de comidas[].items).
class ItemIngesta {
  const ItemIngesta({
    required this.id,
    required this.nombre,
    required this.codigo,
    required this.cantidad,
    required this.unidad,
    required this.gramos,
    required this.comida,
  });

  factory ItemIngesta.desdeJson(Json j) => ItemIngesta(
    id: j['id'] as int,
    nombre: (j['nombrePlatoAlimento'] as String? ?? '').trim(),
    codigo: j['codPlatoAlimento'] as String? ?? '',
    cantidad: numero(j['cantidad']),
    unidad: j['unidad'] as String? ?? '',
    gramos: numero(j['cantidadGramos']),
    comida: j['comida'] as String? ?? '',
  );

  final int id;
  final String nombre;
  final String codigo;
  final double cantidad;
  final String unidad;
  final double gramos;
  final String comida;

  String get cantidadTexto => unidad == 'gramos' ? '${fmtNum(cantidad)} g' : '${fmtNum(cantidad)} × $unidad';
}

class ComidaIngesta {
  const ComidaIngesta(this.nombre, this.items);

  final String nombre;
  final List<ItemIngesta> items;
}

/// Calorías y macronutrientes consumidos frente al objetivo (objetivos de GET ingesta).
class ObjetivosDia {
  const ObjetivosDia({
    required this.objKcal,
    required this.objProteinas,
    required this.objCarbohidratos,
    required this.objGrasa,
    required this.kcal,
    required this.proteinas,
    required this.carbohidratos,
    required this.grasa,
    required this.tieneObjetivo,
    required this.agua,
    required this.indiceGlucemico,
    required this.costo,
  });

  factory ObjetivosDia.desdeJson(Json? j) {
    final o = j ?? const <String, dynamic>{};
    return ObjetivosDia(
      objKcal: numero(o['objKcals']),
      objProteinas: numero(o['objProts']),
      objCarbohidratos: numero(o['objCho']),
      objGrasa: numero(o['objGrasa']),
      kcal: numero(o['kcals']),
      proteinas: numero(o['prots']),
      carbohidratos: numero(o['cho']),
      grasa: numero(o['grasa']),
      tieneObjetivo: o['tieneObjetivo'] as bool? ?? false,
      agua: numero(o['aguaTotal']),
      indiceGlucemico: numero(o['igPromedio']),
      costo: numero(o['costoTotal']),
    );
  }

  final double objKcal;
  final double objProteinas;
  final double objCarbohidratos;
  final double objGrasa;
  final double kcal;
  final double proteinas;
  final double carbohidratos;
  final double grasa;
  final bool tieneObjetivo;
  final double agua;
  final double indiceGlucemico;
  final double costo;

  double get avance => objKcal <= 0 ? 0 : kcal / objKcal;
}

/// Una dieta guardada: fecha de la ingesta y su nombre.
class DietaGuardada {
  const DietaGuardada(this.fecha, this.titulo);

  final String fecha;
  final String titulo;

  String get etiqueta => titulo.trim().isEmpty ? fechaVista(fecha) : '${fechaVista(fecha)} · ${titulo.trim()}';
}

/// GET ingesta: comidas del día, objetivos y dietas guardadas.
class Ingesta {
  const Ingesta({
    required this.fecha,
    required this.nombre,
    required this.vacia,
    required this.comidas,
    required this.objetivos,
    required this.dietas,
    this.bloqueo,
  });

  factory Ingesta.desdeJson(Json j) {
    final conItems = {
      for (final c in _lista(j['comidas']))
        c['nombre'] as String: [for (final i in _lista(c['items'])) ItemIngesta.desdeJson(i)],
    };
    // Todas las comidas del catálogo, aunque estén vacías, para poder agregar en cualquiera.
    // "Resumen del día" (co_comi 6) no es una comida.
    final nombres = [
      for (final o in _lista(j['ordenesComida']))
        if (o['co_comi'] != 6) o['descri'] as String,
    ];
    for (final nombre in conItems.keys) {
      if (!nombres.contains(nombre)) nombres.add(nombre);
    }
    return Ingesta(
      fecha: j['fecha'] as String? ?? '',
      nombre: (j['nombreDieta'] as String? ?? '').trim(),
      vacia: j['sinIngesta'] as bool? ?? true,
      comidas: [for (final n in nombres) ComidaIngesta(n, conItems[n] ?? [])],
      objetivos: ObjetivosDia.desdeJson(j['objetivos'] as Json?),
      dietas: [for (final f in _lista(j['fechas'])) DietaGuardada(f['fecha'] as String, f['titulo'] as String? ?? '')],
      bloqueo: _motivoBloqueo(j['bloqueo']),
    );
  }

  final String fecha;
  final String nombre;

  /// No hay dieta creada en esta fecha.
  final bool vacia;
  final List<ComidaIngesta> comidas;
  final ObjetivosDia objetivos;
  final List<DietaGuardada> dietas;
  final String? bloqueo;

  int get totalItems => comidas.fold(0, (suma, c) => suma + c.items.length);
}

// ── Evaluación y objetivos ────────────────────────────────────────────────

/// datos.evaluacion de GET evaluacion: lo calcula el servidor con los datos y el gasto.
class Evaluacion {
  const Evaluacion({
    required this.fecha,
    required this.tipo,
    required this.estado,
    required this.gastoBasal,
    required this.contextura,
    required this.imc,
    required this.grasaCorporal,
    required this.superficieCorporal,
    required this.pesoDesde,
    required this.pesoHasta,
    required this.diferenciaPeso,
    required this.diasPlan,
    required this.caloriasConsumir,
    required this.caloriasQuemar,
    required this.determinantes,
    required this.factoresRiesgo,
  });

  factory Evaluacion.desdeJson(Json j) {
    List<String> partes(Object? v) => [
      for (final p in ((v as String?) ?? '').split('|'))
        if (p.trim().isNotEmpty) p.trim(),
    ];
    return Evaluacion(
      fecha: j['ndFechaIng'] as String? ?? '',
      tipo: j['tipoEvaluacion'] as String? ?? '',
      estado: j['estado'] as String? ?? '',
      gastoBasal: numero(j['gastoBasal']),
      contextura: j['contextura'] as String? ?? '',
      imc: numero(j['bmi']),
      grasaCorporal: numero(j['grasaCorporal']),
      superficieCorporal: numero(j['superficieCorporal']),
      pesoDesde: numero(j['pesoDesde']),
      pesoHasta: numero(j['pesoHasta']),
      diferenciaPeso: numero(j['difPeso']),
      diasPlan: (j['diasPlanIdeal'] as num?)?.toInt() ?? 0,
      caloriasConsumir: numero(j['caloriasConsumar']),
      caloriasQuemar: numero(j['caloriasQuemar']),
      determinantes: partes(j['determinantes']),
      factoresRiesgo: partes(j['factoresRiesgo']),
    );
  }

  final String fecha;
  final String tipo;
  final String estado;
  final double gastoBasal;
  final String contextura;
  final double imc;
  final double grasaCorporal;
  final double superficieCorporal;
  final double pesoDesde;
  final double pesoHasta;
  final double diferenciaPeso;
  final int diasPlan;
  final double caloriasConsumir;
  final double caloriasQuemar;
  final List<String> determinantes;
  final List<String> factoresRiesgo;
}

/// Opción de un combo de la API ({text, value}).
class Opcion {
  const Opcion(this.valor, this.texto);

  factory Opcion.desdeJson(Json j) => Opcion(j['value'] as String? ?? '', j['text'] as String? ?? '');

  final String valor;
  final String texto;
}

class VistaEvaluacion {
  const VistaEvaluacion({
    required this.evaluacion,
    required this.fecha,
    required this.fechas,
    required this.sinDatos,
    required this.tieneGasto,
    required this.fijada,
    this.bloqueo,
  });

  factory VistaEvaluacion.desdeJson(Json j) {
    final combo = [for (final o in _lista(j['lstComboFechas'])) Opcion.desdeJson(o)];
    return VistaEvaluacion(
      evaluacion: j['evaluacion'] == null ? null : Evaluacion.desdeJson(j['evaluacion'] as Json),
      fecha: j['fechaAEvaluar'] as String?,
      fechas: combo.isNotEmpty
          ? combo
          : [for (final f in (j['lstFechasDisponibles'] as List?) ?? const []) Opcion('$f', '$f')],
      sinDatos: j['sinDatos'] as bool? ?? false,
      tieneGasto: j['tieneGCD'] as bool? ?? false,
      fijada: j['evaluacionFijada'] as bool? ?? false,
      bloqueo: _motivoBloqueo(j['bloqueo']),
    );
  }

  final Evaluacion? evaluacion;
  final String? fecha;
  final List<Opcion> fechas;
  final bool sinDatos;
  final bool tieneGasto;
  final bool fijada;
  final String? bloqueo;
}

/// Objetivo nutricional diario (GET objetivos): el del nutricionista si existe, si no el del sistema.
class Objetivo {
  const Objetivo({
    required this.kcal,
    required this.proteinas,
    required this.carbohidratos,
    required this.grasa,
    required this.fibra,
    required this.delNutricionista,
    required this.estado,
  });

  static Objetivo? desdeJson(Json j) {
    final propio = j['objetivoNutricionista'] as Json?;
    final o = propio ?? j['objetivoSistema'] as Json?;
    if (o == null) return null;
    return Objetivo(
      kcal: numero(o['kcals']),
      proteinas: numero(o['prots']),
      carbohidratos: numero(o['cho']),
      grasa: numero(o['grasa']),
      fibra: numero(o['fibra']),
      delNutricionista: propio != null,
      estado: j['estado'] as String? ?? '',
    );
  }

  final double kcal;
  final double proteinas;
  final double carbohidratos;
  final double grasa;
  final double fibra;
  final bool delNutricionista;
  final String estado;
}

// ── Gasto calórico ────────────────────────────────────────────────────────

class Actividad {
  const Actividad({
    required this.nombre,
    required this.vecesSemana,
    required this.tiempo,
    required this.unidad,
    required this.gastoDiario,
    required this.gastoSemanal,
  });

  factory Actividad.desdeJson(Json j) => Actividad(
    nombre: j['actividad'] as String? ?? '',
    vecesSemana: (j['vecesSemana'] as num?)?.toInt() ?? 0,
    tiempo: numero(j['tiempo']),
    unidad: j['unidad'] as String? ?? 'minutos',
    gastoDiario: numero(j['gastoDiario']),
    gastoSemanal: numero(j['gastoSemanal']),
  );

  final String nombre;
  final int vecesSemana;
  final double tiempo;
  final String unidad;
  final double gastoDiario;
  final double gastoSemanal;
}

/// GET gasto-calorico: plan de actividades de una fecha y el gasto que resulta.
class PlanGasto {
  const PlanGasto({
    required this.fecha,
    required this.fechaFin,
    required this.nombre,
    required this.estadoEvaluacion,
    required this.actividades,
    required this.fechas,
    required this.planes,
    required this.horasActividad,
    required this.horasRestantes,
    required this.gastoBasalDiario,
    required this.gastoActividadesDiario,
    required this.totalDiario,
    required this.totalSemanal,
    required this.sinGasto,
    required this.tieneEvaluacion,
    this.mensaje,
    this.bloqueo,
  });

  factory PlanGasto.desdeJson(Json j) => PlanGasto(
    fecha: j['fechaGasto'] as String?,
    fechaFin: j['fechaFin'] as String?,
    nombre: (j['nombreGCD'] as String? ?? '').trim(),
    estadoEvaluacion: j['estadoEvaluacion'] as String? ?? '',
    actividades: [for (final a in _lista(j['lstActividades'])) Actividad.desdeJson(a)],
    fechas: [for (final f in _lista(j['lstFechas'])) Opcion(f['fecha'] as String, f['nombre'] as String? ?? '')],
    planes: [for (final p in _lista(j['lstPlanes'])) Opcion(p['co_planc'] as String, p['nombre'] as String? ?? '')],
    horasActividad: numero(j['horasActividad']),
    horasRestantes: numero(j['horasRestantes']),
    gastoBasalDiario: numero(j['gastoBasalDiario']),
    gastoActividadesDiario: numero(j['gastoDiarioActividades']),
    totalDiario: numero(j['totalDiario']),
    totalSemanal: numero(j['totalSemanal']),
    sinGasto: j['sinGasto'] as bool? ?? true,
    tieneEvaluacion: j['tieneEvaluacion'] as bool? ?? false,
    mensaje: j['mensaje'] as String?,
    bloqueo: _motivoBloqueo(j['bloqueo']),
  );

  final String? fecha;
  final String? fechaFin;
  final String nombre;
  final String estadoEvaluacion;
  final List<Actividad> actividades;

  /// Fechas con plan guardado (valor = fecha, texto = nombre del plan).
  final List<Opcion> fechas;

  /// Planes predefinidos (valor = código, texto = nombre).
  final List<Opcion> planes;
  final double horasActividad;
  final double horasRestantes;
  final double gastoBasalDiario;
  final double gastoActividadesDiario;
  final double totalDiario;
  final double totalSemanal;
  final bool sinGasto;
  final bool tieneEvaluacion;
  final String? mensaje;
  final String? bloqueo;
}
