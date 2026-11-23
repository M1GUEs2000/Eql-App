import 'package:flutter/material.dart';

import '../theme/eq_tokens.dart';
import 'eq_basicos.dart';

/// Estado vacío de una pantalla: tarjeta grande que invita a crear lo primero.
class CrearPrimeraCard extends StatelessWidget {
  const CrearPrimeraCard({
    super.key,
    required this.icono,
    required this.titulo,
    required this.descripcion,
    required this.onTap,
  });

  final IconData icono;
  final String titulo;
  final String descripcion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return EqCard(
      radio: EqRadius.xl,
      borde: EqColors.primary,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: EqSpace.lg),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: EqColors.acentoFondo,
                shape: BoxShape.circle,
              ),
              child: Icon(icono, size: 36, color: EqColors.acento),
            ),
            const SizedBox(height: EqSpace.md),
            Text(titulo, textAlign: TextAlign.center, style: EqText.h3),
            const SizedBox(height: EqSpace.xs),
            Text(
              descripcion,
              textAlign: TextAlign.center,
              style: EqText.bodySm,
            ),
            const SizedBox(height: EqSpace.lg),
            FilledButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.add),
              label: Text(titulo),
            ),
          ],
        ),
      ),
    );
  }
}

/// Equivale a ContenedorHome: tarjeta de acceso a una funcionalidad.
class OpcionCard extends StatelessWidget {
  const OpcionCard({
    super.key,
    required this.icono,
    required this.titulo,
    required this.descripcion,
    required this.onTap,
  });

  final IconData icono;
  final String titulo;
  final String descripcion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return EqCard(
      radio: EqRadius.lg,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: EqColors.acentoFondo,
              borderRadius: BorderRadius.circular(EqRadius.md),
            ),
            child: Icon(icono, color: EqColors.acento),
          ),
          const SizedBox(width: EqSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: EqText.h4.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(descripcion, style: EqText.bodySm),
              ],
            ),
          ),
          const SizedBox(width: EqSpace.sm),
          Icon(Icons.chevron_right, color: EqColors.textFaint),
        ],
      ),
    );
  }
}
