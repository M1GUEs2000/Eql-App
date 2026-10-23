import 'api.dart';
import 'models.dart';

/// Resultado de GET analisis: tarjetas resumen y una fila por nutriente.
class AnalisisNutricional {
  const AnalisisNutricional({
    required this.titulo,
    required this.estado,
    required this.satisfaccion,
    required this.macronutrientes,
    required this.vitaminas,
    required this.minerales,
    required this.nutrientes,
  });

  factory AnalisisNutricional.desdeJson(Json j) {
    final tarjetas = {
      for (final t in (j['tarjetas'] as List?) ?? const [])
        _clave((t as Json)['label'] as String? ?? ''): numero(t['pct']),
    };
    return AnalisisNutricional(
      titulo: j['titulo'] as String? ?? '',
      estado: j['estado'] as String? ?? '',
      satisfaccion: tarjetas['satisfaccion'] ?? 0,
      macronutrientes: tarjetas['macro'] ?? 0,
      vitaminas: tarjetas['vitaminas'] ?? 0,
      minerales: tarjetas['minerales'] ?? 0,
      nutrientes: [for (final f in (j['filas'] as List?) ?? const []) Nutriente.desdeJson(f as Json)],
    );
  }

  // "Satisfacción" → "satisfaccion"
  static String _clave(String etiqueta) => etiqueta
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u');

  final String titulo;

  /// Fase del motor: "Estado Preventivo", "Estado Ajuste Final 1"...
  final String estado;
  final double satisfaccion;
  final double macronutrientes;
  final double vitaminas;
  final double minerales;
  final List<Nutriente> nutrientes;
}

enum GrupoNutriente {
  macronutrientes('Macronutrientes'),
  vitaminas('Vitaminas'),
  minerales('Minerales');

  const GrupoNutriente(this.nombre);
  final String nombre;
}

class Nutriente {
  const Nutriente({
    required this.sec,
    required this.nombre,
    required this.campo,
    required this.cualitativo,
    required this.cuantitativo,
    required this.objetivo,
    required this.cantidad,
    this.zona,
  });

  factory Nutriente.desdeJson(Json j) => Nutriente(
    sec: numero(j['ordenTipo']),
    nombre: j['nombre'] as String? ?? '',
    campo: j['nombreCampo'] as String? ?? '',
    cualitativo: numero(j['cualitativo']),
    cuantitativo: numero(j['cuantitativo']),
    objetivo: numero(j['objetivo']),
    cantidad: numero(j['cantidad']),
    zona: j['zonaTexto'] as String?,
  );

  /// Sección del motor: 1,xx macronutrientes, 2,xx vitaminas, 3,xx minerales.
  final double sec;
  final String nombre;
  final String campo;
  final double cualitativo;
  final double cuantitativo;
  final double objetivo;
  final double cantidad;

  /// % de zona de crecimiento tal como lo da el motor ("268.25%").
  final String? zona;

  GrupoNutriente get grupo => GrupoNutriente.values[(sec.floor() - 1).clamp(0, 2)];

  /// La API no manda unidades; son las de la tabla de nutrientes de la web.
  String get unidad => _unidades[campo] ?? '';

  /// Positivo: falta para llegar al objetivo. Negativo: exceso.
  double get excDef => objetivo - cantidad;
}

const _unidades = {
  'KCALS': 'kcal',
  'PROTS': 'g',
  'CHO': 'g',
  'AZUCART': 'g',
  'FIBRA': 'g',
  'GRASA': 'g',
  'GRASAMINSA': 'g',
  'GRASAPINSA': 'g',
  'GRASASAT': 'g',
  'COLEST': 'mg',
  'OMEGA3': 'mg',
  'VITAA': 'UI',
  'VITAC': 'mg',
  'VITAD': 'mcg',
  'VITAB6': 'mg',
  'VITAB12': 'mcg',
  'VITAE': 'mg_ATE',
  'TIAMINA': 'mg',
  'RIBOFLAVIN': 'mg',
  'NIACINA': 'mg',
  'FOLATO': 'mcg',
  'HIERRO': 'mg',
  'CALCIO': 'mg',
  'FOSFORO': 'mg',
  'SODIO': 'mg',
  'POTASIO': 'mg',
  'MAGNESIO': 'mg',
  'ZINC': 'mg',
  'SELENIO': 'mcg',
};
