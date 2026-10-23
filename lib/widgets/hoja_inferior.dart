import 'package:flutter/material.dart';

import '../theme/eq_tokens.dart';

/// Abre [hoja] como hoja inferior al 90 % de la pantalla (los popups de la app React).
Future<T?> abrirHoja<T>(BuildContext context, Widget hoja) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => Padding(
      // Sube la hoja por encima del teclado
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FractionallySizedBox(heightFactor: 0.9, child: hoja),
    ),
  );
}

/// Pie de las hojas de creación: aviso de validación encima del botón principal.
class PieFormulario extends StatelessWidget {
  const PieFormulario({super.key, required this.texto, required this.onPressed, this.error});

  final String texto;

  /// null mientras se envía, para no mandar dos veces.
  final VoidCallback? onPressed;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (error != null) ...[
          Text(
            error!,
            style: EqText.bodySm.copyWith(color: EqColors.error),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: EqSpace.sm),
        ],
        FilledButton.icon(onPressed: onPressed, icon: const Icon(Icons.check), label: Text(texto)),
      ],
    );
  }
}

class HojaInferior extends StatelessWidget {
  const HojaInferior({super.key, required this.titulo, required this.child, this.subtitulo, this.pie});

  final String titulo;
  final String? subtitulo;
  final Widget child;
  final Widget? pie;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: EqSpace.sm),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(color: EqColors.borderLight, borderRadius: BorderRadius.circular(2)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(EqSpace.lg, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: EqText.h3),
                    if (subtitulo != null) Text(subtitulo!, style: EqText.bodySm),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
                color: EqColors.textMuted,
                tooltip: 'Cerrar',
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(child: child),
        if (pie != null)
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: EqColors.borderLight)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(padding: const EdgeInsets.all(EqSpace.md), child: pie),
            ),
          ),
      ],
    );
  }
}
