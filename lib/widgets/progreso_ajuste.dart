import 'dart:async';

import 'package:flutter/material.dart';

import '../data/api.dart';
import '../data/models.dart';
import '../theme/eq_tokens.dart';

/// Operaciones que corren en segundo plano en el servidor.
enum TipoAjuste {
  automatico('aa'),
  dietaAjustada('da');

  const TipoAjuste(this.codigo);
  final String codigo;
}

/// Muestra un diálogo mientras consulta GET ajuste/estado cada pocos segundos.
/// Devuelve el resultado al completar, null si se canceló; lanza [ApiError] si
/// el servidor responde ERROR.
Future<Json?> esperarAjuste(BuildContext context, {required TipoAjuste tipo, required String fecha}) async {
  final resultado = await showDialog<_Fin>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _Progreso(tipo: tipo, fecha: fecha),
  );
  return switch (resultado) {
    _Completado(:final datos) => datos,
    _Fallo(:final error) => throw error,
    _ => null,
  };
}

sealed class _Fin {}

class _Completado extends _Fin {
  _Completado(this.datos);
  final Json datos;
}

class _Fallo extends _Fin {
  _Fallo(this.error);
  final ApiError error;
}

class _Progreso extends StatefulWidget {
  const _Progreso({required this.tipo, required this.fecha});

  final TipoAjuste tipo;
  final String fecha;

  @override
  State<_Progreso> createState() => _ProgresoState();
}

class _ProgresoState extends State<_Progreso> {
  Timer? _temporizador;
  var _mensaje = 'Equilibra está ajustando la dieta. Puede tardar un poco.';
  var _cancelando = false;

  @override
  void initState() {
    super.initState();
    _temporizador = Timer.periodic(const Duration(seconds: 3), (_) => _consultar());
  }

  @override
  void dispose() {
    _temporizador?.cancel();
    super.dispose();
  }

  Future<void> _consultar() async {
    try {
      final estado = await Api.get('ajuste/estado', {'tipo': widget.tipo.codigo, 'fecha': widget.fecha}) as Json;
      if (!mounted) return;
      switch (estado['estado']) {
        case 'COMPLETADO':
          _cerrar(_Completado((estado['resultado'] as Json?) ?? const {}));
        case 'ERROR':
          _cerrar(_Fallo(ApiError(estado['mensaje'] as String? ?? 'El ajuste no se pudo completar.')));
        case 'NO_ENCONTRADO':
          _cerrar(_Fallo(const ApiError('El servidor ya no tiene el resultado del ajuste. Recargue la dieta.')));
        default:
          if (estado['mensaje'] case final String m when m.isNotEmpty) setState(() => _mensaje = m);
      }
    } on ApiError catch (e) {
      if (mounted) _cerrar(_Fallo(e));
    }
  }

  void _cerrar(_Fin fin) {
    _temporizador?.cancel();
    Navigator.of(context).pop(fin);
  }

  Future<void> _cancelar() async {
    setState(() => _cancelando = true);
    try {
      await Api.post('ajuste/automatico/cancelar', {'fecha': widget.fecha});
    } on ApiError {
      // Si ya terminó, la próxima consulta lo dirá.
    }
    if (mounted) _cerrar(_Cancelado());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Optimizando'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LinearProgressIndicator(),
          const SizedBox(height: EqSpace.md),
          Text(_mensaje, style: EqText.bodySm),
        ],
      ),
      actions: [
        if (widget.tipo == TipoAjuste.automatico)
          TextButton(onPressed: _cancelando ? null : _cancelar, child: const Text('Cancelar')),
      ],
    );
  }
}

class _Cancelado extends _Fin {}
