import 'package:flutter/material.dart';

import '../theme/eq_tokens.dart';
import 'buscar_alimentos_screen.dart';
import 'evaluaciones_screen.dart';
import 'gasto_calorico_screen.dart';
import 'home_screen.dart';
import 'ver_dieta_screen.dart';

/// Contenedor con la barra inferior (BottomNavbar de la app React).
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _pestana = 0;

  void _ir(int pestana) => setState(() => _pestana = pestana);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _pestana,
        children: [
          HomeScreen(onIrAPestana: _ir),
          const VerDietaScreen(),
          const BuscarAlimentosScreen(),
          const GastoCaloricoScreen(),
          const EvaluacionesScreen(),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: EqColors.borderLight)),
        ),
        child: NavigationBar(
          selectedIndex: _pestana,
          onDestinationSelected: _ir,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Inicio',
            ),
            NavigationDestination(
              icon: Icon(Icons.assignment_outlined),
              selectedIcon: Icon(Icons.assignment),
              label: 'Mis dietas',
            ),
            NavigationDestination(
              icon: Icon(Icons.search),
              selectedIcon: Icon(Icons.search),
              label: 'Buscar',
            ),
            NavigationDestination(
              icon: Icon(Icons.local_fire_department_outlined),
              selectedIcon: Icon(Icons.local_fire_department),
              label: 'Gasto calórico',
            ),
            NavigationDestination(
              icon: Icon(Icons.fact_check_outlined),
              selectedIcon: Icon(Icons.fact_check),
              label: 'Evaluaciones',
            ),
          ],
        ),
      ),
    );
  }
}
