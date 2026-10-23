import 'package:flutter/foundation.dart';

import 'models.dart';

/// Las pestañas viven a la vez en un IndexedStack: cuando una hoja guarda algo
/// (una dieta, un plan de gasto, una evaluación) avisa aquí y todas se recargan.
abstract final class Cambios {
  static final version = ValueNotifier<int>(0);

  /// Fecha de la ingesta que la pestaña de dietas debe mostrar al recargarse.
  static String? fechaIngesta;

  /// Ingesta abierta en "Mis dietas": la pestaña Buscar agrega alimentos ahí.
  static final ingestaActual = ValueNotifier<Ingesta?>(null);

  static void avisar({String? fechaIngesta}) {
    if (fechaIngesta != null) Cambios.fechaIngesta = fechaIngesta;
    version.value++;
  }
}
