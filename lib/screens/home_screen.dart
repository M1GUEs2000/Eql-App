import 'package:flutter/material.dart';

import '../data/sesion.dart';
import '../theme/eq_tokens.dart';
import '../widgets/eq_top_bar.dart';
import '../widgets/hoja_inferior.dart';
import '../widgets/opcion_card.dart';
import 'crear_dieta_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onIrAPestana});

  final ValueChanged<int> onIrAPestana;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const EqTopBar(),
      body: ListView(
        children: [
          const _Bienvenida(),
          Padding(
            padding: const EdgeInsets.fromLTRB(EqSpace.md, EqSpace.lg, EqSpace.md, EqSpace.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Funcionalidades de Equilibra', style: EqText.h3),
                const SizedBox(height: EqSpace.md),
                OpcionCard(
                  icono: Icons.restaurant_menu,
                  titulo: 'Ver mis dietas',
                  descripcion: 'Consulta las dietas que has guardado anteriormente',
                  onTap: () => onIrAPestana(1),
                ),
                const SizedBox(height: 12),
                OpcionCard(
                  icono: Icons.edit_calendar_outlined,
                  titulo: 'Crear nueva dieta',
                  descripcion: 'Empieza una nueva planificación nutricional desde cero',
                  onTap: () => abrirHoja<void>(context, const CrearDietaScreen()),
                ),
                const SizedBox(height: 12),
                OpcionCard(
                  icono: Icons.local_fire_department_outlined,
                  titulo: 'Ver mi gasto calórico',
                  descripcion: 'Revisa tu balance energético y el cálculo de calorías',
                  onTap: () => onIrAPestana(3),
                ),
                const SizedBox(height: 12),
                OpcionCard(
                  icono: Icons.search,
                  titulo: 'Buscar alimentos',
                  descripcion: 'Explora y añade alimentos o platos a tus dietas',
                  onTap: () => onIrAPestana(2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bienvenida extends StatelessWidget {
  const _Bienvenida();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: EqGradients.hero),
      padding: const EdgeInsets.fromLTRB(EqSpace.lg, 28, EqSpace.lg, EqSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('HOLA, ${Sesion.nombre.toUpperCase()}', style: EqText.caption.copyWith(color: Colors.white70)),
          const SizedBox(height: EqSpace.sm),
          Text.rich(
            TextSpan(
              style: EqText.h1.copyWith(color: Colors.white, fontSize: 28),
              children: const [
                TextSpan(text: 'Tu '),
                TextSpan(
                  text: 'equilibrio',
                  style: TextStyle(color: EqColors.primarySoft),
                ),
                TextSpan(text: ' empieza hoy'),
              ],
            ),
          ),
          const SizedBox(height: EqSpace.sm),
          Text(
            'Planifica tus comidas y sigue tu progreso.',
            style: EqText.body.copyWith(color: Colors.white.withValues(alpha: 0.82)),
          ),
        ],
      ),
    );
  }
}
