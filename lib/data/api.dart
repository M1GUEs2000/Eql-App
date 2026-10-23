import 'dart:convert';

import 'package:http/http.dart' as http;

/// Error de la API: código del documento (DATOS_INVALIDOS, LIMITE_PLAN...) y su mensaje.
class ApiError implements Exception {
  const ApiError(this.mensaje, {this.codigo, this.errores = const [], this.estado});

  final String mensaje;
  final String? codigo;
  final int? estado;

  /// Detalle por campo cuando el código es DATOS_INVALIDOS.
  final List<String> errores;

  bool get sinSesion => estado == 401;

  /// Mensaje y, si los hay, los errores de cada campo.
  String get detalle => errores.isEmpty ? mensaje : '$mensaje\n${errores.join('\n')}';

  @override
  String toString() => detalle;
}

/// Cliente de la API v1. Todas las respuestas vienen como {ok, mensaje, datos};
/// cada método devuelve `datos` o lanza [ApiError].
abstract final class Api {
  static const base = 'https://web-e.equilibra.ec/api/v1';
  static const _espera = Duration(seconds: 60);

  static String? token;

  /// Para el nutricionista: id del paciente con el que se trabaja (encabezado X-Paciente-Id).
  static int? pacienteId;

  /// Se llama cuando el servidor rechaza el token (401).
  static void Function()? alPerderSesion;

  /// Mensaje del último POST/PUT/DELETE correcto ("Dieta creada.", "Alimento movido."...).
  static String? ultimoMensaje;

  static Future<dynamic> get(String ruta, [Map<String, Object?> query = const {}]) =>
      _enviar('GET', ruta, query: query);

  static Future<dynamic> post(String ruta, [Object? cuerpo]) => _enviar('POST', ruta, cuerpo: cuerpo);

  static Future<dynamic> put(String ruta, Object? cuerpo) => _enviar('PUT', ruta, cuerpo: cuerpo);

  static Future<dynamic> delete(String ruta, [Map<String, Object?> query = const {}]) =>
      _enviar('DELETE', ruta, query: query);

  static Future<dynamic> _enviar(
    String metodo,
    String ruta, {
    Map<String, Object?> query = const {},
    Object? cuerpo,
  }) async {
    final parametros = {
      for (final MapEntry(:key, :value) in query.entries)
        if (value != null && '$value'.isNotEmpty) key: '$value',
    };
    final url = Uri.parse('$base/$ruta').replace(queryParameters: parametros.isEmpty ? null : parametros);
    final pedido = http.Request(metodo, url)
      ..headers.addAll({
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        if (pacienteId != null) 'X-Paciente-Id': '$pacienteId',
      });
    if (cuerpo != null) {
      // Sin escapar: el servidor no reconoce "ndCircMuñeca" si la ñ llega como ñ.
      pedido
        ..headers['Content-Type'] = 'application/json; charset=utf-8'
        ..bodyBytes = utf8.encode(jsonEncode(cuerpo));
    }

    final http.Response respuesta;
    try {
      respuesta = await http.Response.fromStream(await pedido.send().timeout(_espera));
    } on Exception {
      throw const ApiError('No se pudo conectar con Equilibra. Revisa tu conexión a Internet.');
    }

    final Object? json;
    try {
      json = jsonDecode(utf8.decode(respuesta.bodyBytes));
    } on FormatException {
      throw ApiError(_sinJson(respuesta.statusCode), estado: respuesta.statusCode);
    }

    if (json is Map<String, dynamic> && json['ok'] == true) {
      if (metodo != 'GET') ultimoMensaje = json['mensaje'] as String?;
      return json['datos'];
    }

    final error = json is Map<String, dynamic> ? json : const <String, dynamic>{};
    if (respuesta.statusCode == 401 && token != null) alPerderSesion?.call();
    throw ApiError(
      error['mensaje'] as String? ?? 'El servidor respondió con un error (${respuesta.statusCode}).',
      codigo: error['codigo'] as String?,
      estado: respuesta.statusCode,
      errores: [
        for (final e in (error['errores'] as List?) ?? const [])
          if (e is Map && e['mensaje'] != null) '${e['mensaje']}',
      ],
    );
  }

  static String _sinJson(int estado) => switch (estado) {
    // IIS responde con una página HTML cuando tiene PUT/DELETE desactivados
    405 => 'El servidor todavía no permite esta operación (HTTP 405).',
    _ => 'El servidor respondió con un error ($estado).',
  };
}

/// Fecha en el formato que usa la API: aaaa/mm/dd.
String fechaApi(DateTime fecha) {
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${fecha.year}/${dos(fecha.month)}/${dos(fecha.day)}';
}

/// "2026/10/23" → "23/10/2026".
String fechaVista(String fecha) {
  final partes = fecha.split('/');
  return partes.length == 3 ? '${partes[2]}/${partes[1]}/${partes[0]}' : fecha;
}

DateTime? leerFechaApi(String? fecha) {
  final partes = fecha?.split('/');
  if (partes == null || partes.length != 3) return null;
  final [a, m, d] = partes.map(int.tryParse).toList();
  return a == null || m == null || d == null ? null : DateTime(a, m, d);
}

/// Número de un JSON que puede llegar como int, double, texto o null.
double numero(Object? v) => switch (v) {
  num n => n.toDouble(),
  String s => double.tryParse(s.replaceAll(',', '.')) ?? 0,
  _ => 0,
};

/// Número con coma decimal y sin ceros sobrantes: 2.10 → "2,1".
String fmtNum(double v, [int decimales = 2]) {
  final s = v.toStringAsFixed(decimales).replaceFirst(RegExp(r'\.?0+$'), '');
  return s.replaceAll('.', ',');
}
