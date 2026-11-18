import 'package:flutter/material.dart';

import '../theme/eq_tokens.dart';
import '../widgets/tutorial_barra.dart';
import 'buscar_alimentos_screen.dart';
import 'evaluaciones_screen.dart';
import 'gasto_calorico_screen.dart';
import 'home_screen.dart';
import 'ver_dieta_screen.dart';

/// Contenedor con la barra inferior (BottomNavbar de la app React).
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key, this.tutorial = false});

  /// Muestra el recorrido por la barra inferior (al terminar el registro guiado).
  final bool tutorial;

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

const _pasosTutorial = [
  PasoTutorial(
    1,
    Icons.assignment,
    'Aquí haces tus dietas',
    'Crea, revisa y optimiza tus dietas.',
  ),
  PasoTutorial(
    2,
    Icons.search,
    'Aquí buscas alimentos',
    'Consulta las calorías y nutrientes de cualquier alimento.',
  ),
  PasoTutorial(
    3,
    Icons.local_fire_department,
    'Aquí está tu gasto calórico',
    'Crea, edita o elimina tus planes de gasto calórico.',
  ),
  PasoTutorial(
    4,
    Icons.fact_check,
    'Aquí están tus evaluaciones',
    'Revisa tu evaluación nutricional y cómo vas avanzando.',
  ),
];

class _ShellScreenState extends State<ShellScreen> {
  int _pestana = 0;
  final _barra = GlobalKey();
  var _enTutorial = false;

  @override
  void initState() {
    super.initState();
    // Tras el primer frame la barra ya tiene tamaño y se puede ubicar cada pestaña.
    if (widget.tutorial) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _enTutorial = true);
      });
    }
  }

  void _ir(int pestana) => setState(() => _pestana = pestana);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _contenido(),
        if (_enTutorial)
          Positioned.fill(
            child: TutorialBarra(
              barra: _barra,
              pestanas: 5,
              pasos: _pasosTutorial,
              onTerminar: () => setState(() => _enTutorial = false),
            ),
          ),
      ],
    );
  }

  Widget _contenido() {
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
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: EqColors.borderLight)),
          // Sombra suave hacia arriba que separa la barra del contenido.
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: EqColors.oscuro ? 0.4 : 0.07,
              ),
              offset: const Offset(0, -2),
              blurRadius: 12,
            ),
          ],
        ),
        child: NavigationBar(
          key: _barra,
          selectedIndex: _pestana,
          onDestinationSelected: _ir,
          // Solo íconos; el label queda como tooltip y para el lector de pantalla.
          labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
          height: 64,
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
