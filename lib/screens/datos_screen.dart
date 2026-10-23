import 'package:flutter/material.dart';

import '../theme/eq_tokens.dart';
import '../widgets/eq_top_bar.dart';
import '../widgets/opcion_card.dart';
import '../widgets/popup_datos.dart';

class DatosScreen extends StatelessWidget {
  const DatosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const EqTopBar(titulo: 'Datos del usuario'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          EqSpace.md,
          EqSpace.lg,
          EqSpace.md,
          EqSpace.xl,
        ),
        children: [
          Text('Tu ficha', style: EqText.h2),
          const SizedBox(height: EqSpace.xs),
          Text(
            'Con estos datos Equilibra calcula tu evaluación nutricional. Empieza por los antropométricos.',
            style: EqText.bodySm,
          ),
          const SizedBox(height: EqSpace.lg),
          OpcionCard(
            icono: Icons.straighten,
            titulo: 'Datos antropométricos',
            descripcion: 'Fecha de nacimiento, sexo, estatura, peso, medidas y nivel de actividad',
            onTap: () => editarDatos(context, FichaDatos.antropometricos),
          ),
          const SizedBox(height: 12),
          OpcionCard(
            icono: Icons.monitor_heart_outlined,
            titulo: 'Datos clínicos',
            descripcion:
                'Presión arterial, diabetes, tabaquismo y antecedentes',
            onTap: () => editarDatos(context, FichaDatos.clinicos),
          ),
          const SizedBox(height: 12),
          OpcionCard(
            icono: Icons.science_outlined,
            titulo: 'Datos de laboratorio',
            descripcion: 'Glucosa, perfil lipídico, ácido úrico, hemoglobina y creatinina',
            onTap: () => editarDatos(context, FichaDatos.laboratorio),
          ),
        ],
      ),
    );
  }
}
