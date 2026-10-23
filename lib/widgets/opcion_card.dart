import 'package:flutter/material.dart';

import '../theme/eq_tokens.dart';
import 'eq_basicos.dart';

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
            decoration: BoxDecoration(color: EqColors.primarySoft, borderRadius: BorderRadius.circular(EqRadius.md)),
            child: Icon(icono, color: EqColors.primaryDark),
          ),
          const SizedBox(width: EqSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: EqText.h4.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(descripcion, style: EqText.bodySm),
              ],
            ),
          ),
          const SizedBox(width: EqSpace.sm),
          const Icon(Icons.chevron_right, color: EqColors.textFaint),
        ],
      ),
    );
  }
}
