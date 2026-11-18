import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api.dart';
import 'models.dart';
import 'sesion.dart';

/// Recuerda la fecha de la última dieta que se editó desde la app.
///
/// La API no guarda cuándo se modificó una dieta (tbIngesta_diaria y tbDietas
/// solo tienen la fecha del día), así que la app lo anota en el almacenamiento
/// del dispositivo, por usuario y paciente. Lo editado desde la web no se ve aquí.
abstract final class UltimaDieta {
  static const _almacen = FlutterSecureStorage();
  static final _cache = <String, String?>{};

  static String get _clave =>
      'ultimaDieta:${Sesion.perfil?.usuario ?? ''}:${Api.pacienteId ?? ''}';

  static Future<String?> leer() async {
    final clave = _clave;
    if (_cache.containsKey(clave)) return _cache[clave];
    try {
      return _cache[clave] = await _almacen.read(key: clave);
    } on Exception {
      return _cache[clave] = null;
    }
  }

  static Future<void> _guardar(String? fecha) async {
    final clave = _clave;
    _cache[clave] = fecha;
    try {
      fecha == null
          ? await _almacen.delete(key: clave)
          : await _almacen.write(key: clave, value: fecha);
    } on Exception {
      // Sin almacenamiento solo dura lo que dure la app abierta.
    }
  }

  /// Lo llama [Api] tras cada petición que cambia datos y salió bien.
  static void registrar(
    String metodo,
    String ruta,
    Map<String, Object?> query,
    Object? cuerpo,
  ) {
    if (metodo == 'GET') return;
    if (!ruta.startsWith('ingesta/') && !ruta.startsWith('ajuste/')) return;
    if (ruta == 'ajuste/automatico/cancelar') return;
    final c = cuerpo is Map ? cuerpo : const {};
    final fecha = '${c['nuevaFecha'] ?? c['fecha'] ?? query['fecha'] ?? ''}';
    if (fecha.isEmpty) return;
    if (metodo == 'DELETE' && ruta == 'ingesta/dietas') {
      // Se borró la dieta: si era la última editada, se olvida.
      if (_cache[_clave] == fecha) _guardar(null);
      return;
    }
    _guardar(fecha);
  }
}

/// La dieta que deben abrir el inicio y "Mis dietas": la última editada si
/// sigue existiendo; si no, la más reciente hasta hoy.
Future<String> fechaDietaAMostrar(List<DietaGuardada> dietas) async {
  final editada = await UltimaDieta.leer();
  if (editada != null && dietas.any((d) => d.fecha == editada)) return editada;
  return fechaDietaMasReciente(dietas);
}

/// Fecha con dieta vecina a [actual]: [paso] 1 la siguiente, -1 la anterior.
/// null si no hay más en esa dirección.
String? fechaDietaVecina(List<DietaGuardada> dietas, String actual, int paso) {
  final fechas = [for (final d in dietas) d.fecha]..sort();
  if (paso > 0) {
    for (final f in fechas) {
      if (f.compareTo(actual) > 0) return f;
    }
  } else {
    for (final f in fechas.reversed) {
      if (f.compareTo(actual) < 0) return f;
    }
  }
  return null;
}
