import 'analisis.dart';
import 'api.dart';
import 'models.dart';
import 'ultima_dieta.dart';

/// Dietas ya pedidas, por fecha, para que deslizar entre fechas sea inmediato.
///
/// Cada pantalla ([mantener] con su nombre) conserva una ventana de tres: la
/// dieta que muestra y sus dos vecinas con dieta, que se piden por adelantado.
/// Al moverse, la que queda fuera de todas las ventanas se descarta. Cualquier
/// petición que cambie datos vacía todo ([limpiar], lo llama [Api]).
abstract final class CacheDietas {
  static final _ingestas = <String, Future<Ingesta>>{};
  static final _analisis = <String, Future<AnalisisNutricional?>>{};
  static final _ventanas = <String, Set<String>>{};

  static Future<Ingesta> ingesta(String fecha) => _guardar(
    _ingestas,
    fecha,
    () async =>
        Ingesta.desdeJson(await Api.get('ingesta', {'fecha': fecha}) as Json),
  );

  /// Análisis del día completo; null si la dieta no tiene alimentos.
  static Future<AnalisisNutricional?> analisis(Ingesta i) {
    if (i.vacia || i.totalItems == 0) return Future.value();
    return _guardar(
      _analisis,
      i.fecha,
      () async => AnalisisNutricional.desdeJson(
        await Api.get('analisis', {'fecha': i.fecha, 'tipo': 'DIA-COMPLETO'})
            as Json,
      ),
    );
  }

  /// [dueno] ahora muestra [actual]: se guarda, se piden sus vecinas y se
  /// suelta lo que ya no está cerca de ninguna pantalla.
  static void mantener(String dueno, Ingesta actual) {
    _ingestas[actual.fecha] ??= Future.value(actual);
    final vecinas = [
      for (final paso in const [-1, 1])
        ?fechaDietaVecina(actual.dietas, actual.fecha, paso),
    ];
    _ventanas[dueno] = {actual.fecha, ...vecinas};
    final vivas = _vivas();
    _ingestas.removeWhere((f, _) => !vivas.contains(f));
    _analisis.removeWhere((f, _) => !vivas.contains(f));
    for (final f in vecinas) {
      ingesta(f).then<void>((i) {
        // Si mientras llegaba ya se alejó, no se pide su análisis.
        if (_vivas().contains(f)) analisis(i).ignore();
      }, onError: (_) {});
    }
  }

  /// Descarta lo guardado de [fecha] para que el próximo pedido sea fresco
  /// (recargas, y tras un ajuste que el servidor hace en segundo plano).
  static void olvidar(String fecha) {
    _ingestas.remove(fecha);
    _analisis.remove(fecha);
  }

  static void limpiar() {
    _ingestas.clear();
    _analisis.clear();
  }

  static Set<String> _vivas() => {for (final v in _ventanas.values) ...v};

  /// Reutiliza el pedido en curso o ya resuelto; si falla, se quita para reintentar.
  static Future<T> _guardar<T>(
    Map<String, Future<T>> mapa,
    String fecha,
    Future<T> Function() pedir,
  ) {
    final existente = mapa[fecha];
    if (existente != null) return existente;
    final pedido = pedir();
    mapa[fecha] = pedido;
    pedido.then<void>(
      (_) {},
      onError: (_) {
        if (identical(mapa[fecha], pedido)) mapa.remove(fecha);
      },
    );
    return pedido;
  }
}
