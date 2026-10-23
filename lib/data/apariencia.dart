import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Modo claro u oscuro elegido en Configuración. Se guarda en el dispositivo,
/// no en la cuenta: la API no tiene preferencias de usuario.
abstract final class Apariencia {
  static const _almacen = FlutterSecureStorage();
  static const _clave = 'apariencia';

  static final modo = ValueNotifier(ThemeMode.system);

  static Future<void> cargar() async {
    try {
      final guardado = await _almacen.read(key: _clave);
      modo.value = ThemeMode.values.firstWhere(
        (m) => m.name == guardado,
        orElse: () => ThemeMode.system,
      );
    } catch (_) {
      // Sin almacenamiento disponible se sigue al dispositivo.
    }
  }

  static Future<void> elegir(ThemeMode nuevo) async {
    modo.value = nuevo;
    try {
      await _almacen.write(key: _clave, value: nuevo.name);
    } catch (_) {}
  }
}
