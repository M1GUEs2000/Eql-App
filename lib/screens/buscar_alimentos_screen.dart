import 'package:flutter/material.dart';

import '../widgets/buscador_alimentos.dart';
import '../widgets/eq_top_bar.dart';

class BuscarAlimentosScreen extends StatelessWidget {
  const BuscarAlimentosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: EqTopBar(titulo: 'Buscar alimentos'),
      body: BuscadorAlimentos(),
    );
  }
}
