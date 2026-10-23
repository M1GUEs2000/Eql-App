import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api.dart';

/// Perfil del usuario dueño del token (datos.perfil de auth/login).
class Perfil {
  const Perfil({required this.usuario, required this.nombre, required this.rol, required this.esNutricionista});

  factory Perfil.desdeJson(Map<String, dynamic> j) => Perfil(
    usuario: j['usuario'] as String? ?? '',
    nombre: j['nombre'] as String? ?? '',
    rol: j['rol'] as String? ?? '',
    esNutricionista: j['esNutricionista'] as bool? ?? false,
  );

  final String usuario;
  final String nombre;
  final String rol;
  final bool esNutricionista;
}

/// Token y perfil de la sesión. El token se guarda en el almacenamiento seguro
/// del dispositivo, como pide la API.
abstract final class Sesion {
  static const _almacen = FlutterSecureStorage();
  static const _claveToken = 'token';

  static Perfil? perfil;

  static String get nombre => perfil?.nombre.isNotEmpty ?? false ? perfil!.nombre : perfil?.usuario ?? '';

  /// Recupera el token guardado y comprueba que siga vigente. false si hay que iniciar sesión.
  static Future<bool> restaurar() async {
    try {
      Api.token = await _almacen.read(key: _claveToken);
    } on Exception {
      Api.token = null;
    }
    if (Api.token == null) return false;
    try {
      perfil = Perfil.desdeJson(await Api.get('auth/sesion') as Map<String, dynamic>);
      return true;
    } on ApiError catch (e) {
      // Sin conexión no se borra el token: se reintentará al abrir de nuevo.
      if (e.sinSesion) await _olvidar();
      return false;
    }
  }

  static Future<void> iniciar(String usuario, String clave) async {
    final datos = await Api.post('auth/login', {'usuario': usuario, if (clave.isNotEmpty) 'clave': clave});
    await _guardar(datos as Map<String, dynamic>);
  }

  static Future<void> registrar(Map<String, Object?> formulario) async {
    await _guardar(await Api.post('auth/registro', formulario) as Map<String, dynamic>);
  }

  static Future<void> cerrar() async {
    try {
      await Api.post('auth/logout');
    } on ApiError {
      // El token se olvida igual aunque el servidor no responda.
    }
    await _olvidar();
  }

  static Future<void> _guardar(Map<String, dynamic> datos) async {
    Api.token = datos['token'] as String;
    perfil = Perfil.desdeJson(datos['perfil'] as Map<String, dynamic>);
    await _almacen.write(key: _claveToken, value: Api.token);
  }

  static Future<void> _olvidar() async {
    Api.token = null;
    perfil = null;
    await _almacen.delete(key: _claveToken);
  }

  /// Borra el token local sin llamar a la API (cuando el servidor ya lo rechazó).
  static Future<void> expirar() => _olvidar();
}
