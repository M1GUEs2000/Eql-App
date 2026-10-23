import 'package:flutter/material.dart';

import '../theme/eq_tokens.dart';

/// .card del design system: superficie blanca, borde suave y sombra opcional.
class EqCard extends StatelessWidget {
  const EqCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(EqSpace.md),
    this.onTap,
    this.color,
    this.borde,
    this.radio = EqRadius.md,
    this.sombra = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borde;
  final double radio;
  final bool sombra;

  @override
  Widget build(BuildContext context) {
    final esquinas = BorderRadius.circular(radio);
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: esquinas, boxShadow: sombra ? EqShadow.md : null),
      child: Material(
        color: color ?? EqColors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: esquinas,
          side: BorderSide(color: borde ?? EqColors.borderLight),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// .input-group: etiqueta encima del campo.
class EqField extends StatelessWidget {
  const EqField({super.key, required this.etiqueta, required this.child});

  final String etiqueta;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(etiqueta, style: EqText.label),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

/// .chip-filter / .chip-filter-active
class EqChip extends StatelessWidget {
  const EqChip({super.key, required this.texto, required this.activo, required this.onTap});

  final String texto;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final forma = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(EqRadius.sm),
      side: activo ? BorderSide.none : BorderSide(color: EqColors.borderLight),
    );
    return Material(
      color: activo ? EqColors.indigo : EqColors.bg,
      shape: forma,
      child: InkWell(
        onTap: onTap,
        customBorder: forma,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            texto.toUpperCase(),
            style: EqText.caption.copyWith(color: activo ? Colors.white : EqColors.primary, letterSpacing: 0.6),
          ),
        ),
      ),
    );
  }
}

enum EqTono { exito, aviso, error }

/// .chip-success / .chip-warning / .chip-error
class EqEtiqueta extends StatelessWidget {
  const EqEtiqueta(this.texto, {super.key, required this.tono});

  final String texto;
  final EqTono tono;

  @override
  Widget build(BuildContext context) {
    final (fondo, color) = switch (tono) {
      EqTono.exito => (EqColors.successBg, EqColors.successText),
      EqTono.aviso => (EqColors.warningBg, EqColors.warningText),
      EqTono.error => (EqColors.errorBg, EqColors.errorText),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(EqRadius.sm)),
      child: Text(texto.toUpperCase(), style: EqText.caption.copyWith(color: color, fontSize: 11)),
    );
  }
}

class Cargando extends StatelessWidget {
  const Cargando({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(
            'Cargando...',
            style: EqText.bodySm.copyWith(color: EqColors.primary, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

/// Aviso de una carga fallida de la API, con botón para reintentar.
class ErrorCarga extends StatelessWidget {
  const ErrorCarga(this.mensaje, {super.key, required this.onReintentar});

  final String mensaje;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(EqSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 40, color: EqColors.textFaint),
            const SizedBox(height: 12),
            Text(mensaje, textAlign: TextAlign.center, style: EqText.bodySm),
            const SizedBox(height: EqSpace.md),
            OutlinedButton.icon(
              onPressed: onReintentar,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta para estados vacíos o avisos dentro de una lista.
class EqAviso extends StatelessWidget {
  const EqAviso(this.texto, {super.key, this.icono = Icons.info_outline, this.accion});

  final String texto;
  final IconData icono;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return EqCard(
      sombra: false,
      color: EqColors.surfaceLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icono, color: EqColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(texto, style: EqText.bodySm.copyWith(color: EqColors.onSurface)),
              ),
            ],
          ),
          if (accion != null) ...[const SizedBox(height: 12), accion!],
        ],
      ),
    );
  }
}

void mostrarMensaje(BuildContext context, String texto) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texto)));
}

/// Franja verde del .page-hero, reutilizada como tarjeta destacada.
class EqHero extends StatelessWidget {
  const EqHero({
    super.key,
    required this.child,
    this.radio = EqRadius.lg,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
  });

  final Widget child;
  final double radio;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final esquinas = BorderRadius.circular(radio);
    return Container(
      decoration: BoxDecoration(gradient: EqGradients.hero, borderRadius: esquinas, boxShadow: EqShadow.md),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: esquinas,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: Colors.white24,
          highlightColor: Colors.white10,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
