import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'sesion.dart';

/// Avance del asistente posterior al registro, guardado en el dispositivo por
/// usuario. Si la app se cierra a medias, al volver a abrirla se retoma en el
/// mismo paso. Se borra al terminar el asistente.
abstract final class ProgresoFicha {
  static const _almacen = FlutterSecureStorage();

  static String get _clave => 'fichaGuiada:${Sesion.perfil?.usuario ?? ''}';

  /// null si el usuario no tiene un asistente pendiente.
  static Future<Map<String, dynamic>?> leer() async {
    try {
      final texto = await _almacen.read(key: _clave);
      return texto == null ? null : jsonDecode(texto) as Map<String, dynamic>;
    } on Exception {
      return null;
    }
  }

  static Future<void> guardar(Map<String, Object?> progreso) async {
    try {
      await _almacen.write(key: _clave, value: jsonEncode(progreso));
    } on Exception {
      // Sin almacenamiento el avance solo dura lo que dure la app abierta.
    }
  }

  static Future<void> borrar() async {
    try {
      await _almacen.delete(key: _clave);
    } on Exception {
      // Nada que hacer: a lo sumo el asistente se ofrecerá de nuevo.
    }
  }
}
