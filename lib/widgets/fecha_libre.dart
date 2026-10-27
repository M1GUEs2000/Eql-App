import 'package:flutter/material.dart';

import '../data/api.dart';

/// Calendario que solo deja elegir días sin dieta guardada.
/// [ocupadas] van en formato de la API (aaaa/mm/dd).
Future<DateTime?> elegirFechaLibre(
  BuildContext context, {
  required Iterable<String> ocupadas,
  DateTime? inicial,
}) {
  final usadas = ocupadas.toSet();
  bool libre(DateTime d) => !usadas.contains(fechaApi(d));

  final hoy = DateTime.now();
  return showDatePicker(
    context: context,
    // El día que abre el calendario tiene que ser elegible.
    initialDate: primerDiaLibre(usadas, inicial ?? hoy),
    firstDate: DateTime(hoy.year - 1),
    lastDate: DateTime(hoy.year + 2),
    selectableDayPredicate: libre,
    helpText: 'Elige un día sin dieta',
  );
}

/// Primer día desde [desde] (incluido) que no está en [ocupadas].
DateTime primerDiaLibre(Iterable<String> ocupadas, DateTime desde) {
  final usadas = ocupadas.toSet();
  var dia = DateTime(desde.year, desde.month, desde.day);
  while (usadas.contains(fechaApi(dia))) {
    dia = dia.add(const Duration(days: 1));
  }
  return dia;
}
