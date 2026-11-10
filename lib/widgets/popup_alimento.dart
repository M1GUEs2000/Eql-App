import 'package:flutter/material.dart';

import '../data/api.dart';
import '../data/cambios.dart';
import '../data/models.dart';
import '../theme/eq_tokens.dart';
import 'eq_basicos.dart';
import 'hoja_inferior.dart';

/// Ficha del alimento. Con [conAgregar] muestra "Agregar", que abre un diálogo
/// para elegir la dieta y la comida (POST ingesta/alimentos).
Future<void> mostrarDetalleAlimento(BuildContext context, AlimentoBusqueda alimento, {bool conAgregar = true}) =>
    abrirHoja<void>(context, _DetalleAlimento(alimento, conAgregar: conAgregar));

String _gramos(double g) => '${fmtNum(g, 1)} g';

class _DetalleAlimento extends StatelessWidget {
  const _DetalleAlimento(this.alimento, {required this.conAgregar});

  final AlimentoBusqueda alimento;
  final bool conAgregar;

  Future<void> _agregar(BuildContext context) async {
    final destino = await showDialog<_Destino>(
      context: context,
      builder: (_) => _DialogoAgregar(alimento),
    );
    if (destino == null || !context.mounted) return;
    final mensajero = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    mensajero.showSnackBar(
      SnackBar(content: Text('${alimento.descripcion} agregado a ${destino.comida} (${destino.dieta})')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = alimento;
    return HojaInferior(
      titulo: a.descripcion,
      subtitulo: '${a.nombreTipo} · valores por porción',
      pie: conAgregar ? PieFormulario(texto: 'Agregar', onPressed: () => _agregar(context)) : null,
      child: ListView(
        padding: const EdgeInsets.all(EqSpace.lg),
        children: [
          EqCard(
            sombra: false,
            color: EqColors.primary.withValues(alpha: 0.08),
            borde: EqColors.primary.withValues(alpha: 0.3),
            child: Row(
              children: [
                Icon(Icons.bolt, color: EqColors.primary),
                const SizedBox(width: EqSpace.sm),
                Text('Energía', style: EqText.label),
                const Spacer(),
                Text('${a.kcal.round()} kcal', style: EqText.h3.copyWith(color: EqColors.acento)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Macro(
                  icono: Icons.egg_alt_outlined,
                  nombre: 'Proteínas',
                  valor: _gramos(a.proteinas),
                  color: EqColors.indigo,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Macro(
                  icono: Icons.bakery_dining_outlined,
                  nombre: 'Carbohidratos',
                  valor: _gramos(a.carbohidratos),
                  color: EqColors.warningText,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Macro(
                  icono: Icons.water_drop_outlined,
                  nombre: 'Grasas',
                  valor: _gramos(a.grasa),
                  color: EqColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Dónde quedó el alimento, para el aviso final.
typedef _Destino = ({String dieta, String comida});

/// Elige dieta y comida y agrega el alimento. Las comidas y el bloqueo se leen
/// de GET ingesta de la dieta elegida.
class _DialogoAgregar extends StatefulWidget {
  const _DialogoAgregar(this.alimento);

  final AlimentoBusqueda alimento;

  @override
  State<_DialogoAgregar> createState() => _DialogoAgregarState();
}

class _DialogoAgregarState extends State<_DialogoAgregar> {
  List<DietaGuardada>? _dietas;
  Ingesta? _ingesta;
  String? _fecha;
  String? _comida;
  final _cantidad = TextEditingController(text: '1');

  /// null = la porción base que elige el servidor al agregar.
  String? _unidad;
  var _unidades = <Unidad>[];
  var _cargando = true;
  var _agregando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _iniciar();
    _cargarUnidades();
  }

  @override
  void dispose() {
    _cantidad.dispose();
    super.dispose();
  }

  Future<void> _cargarUnidades() async {
    try {
      final lista =
          await Api.get('ingesta/alimentos/${Uri.encodeComponent(widget.alimento.codigo)}/unidades') as List;
      if (mounted) setState(() => _unidades = [for (final u in lista) Unidad.desdeJson(u as Json)]);
    } on ApiError {
      // Sin el listado se puede agregar igual en porciones base.
    }
  }

  double? get _valor => double.tryParse(_cantidad.text.trim().replaceAll(',', '.'));

  /// Arranca en la dieta abierta en "Mis dietas"; si no hay, en la más reciente.
  Future<void> _iniciar() async {
    try {
      var ingesta = Cambios.ingestaActual.value;
      if (ingesta == null || ingesta.vacia) {
        ingesta = Ingesta.desdeJson(await Api.get('ingesta') as Json);
        if (ingesta.vacia && ingesta.dietas.isNotEmpty) {
          ingesta = Ingesta.desdeJson(
            await Api.get('ingesta', {'fecha': fechaDietaMasReciente(ingesta.dietas)}) as Json,
          );
        }
      }
      if (!mounted) return;
      final actual = ingesta;
      setState(() {
        _dietas = actual.dietas;
        if (!actual.vacia) _usar(actual);
      });
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.detalle);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _usar(Ingesta ingesta) {
    _ingesta = ingesta;
    _fecha = ingesta.fecha;
    final comidas = ingesta.comidas.map((c) => c.nombre);
    if (!comidas.contains(_comida)) _comida = comidas.firstOrNull;
  }

  Future<void> _elegirDieta(String? fecha) async {
    if (fecha == null || fecha == _fecha) return;
    setState(() {
      _fecha = fecha;
      _cargando = true;
      _error = null;
    });
    try {
      final ingesta = Ingesta.desdeJson(await Api.get('ingesta', {'fecha': fecha}) as Json);
      if (mounted && _fecha == fecha) setState(() => _usar(ingesta));
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.detalle);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _agregar() async {
    final ingesta = _ingesta!;
    final comida = _comida!;
    final cantidad = _valor;
    if (cantidad == null || cantidad <= 0 || cantidad > 100000) {
      setState(() => _error = 'Ingrese una cantidad mayor a 0');
      return;
    }
    setState(() {
      _agregando = true;
      _error = null;
    });
    var agregado = false;
    try {
      // La API agrega siempre 1 porción base; si se pidió otra cantidad o unidad,
      // se ajusta el registro recién creado con el PUT de edición.
      final datos = await Api.post('ingesta/alimentos', {
        'codigo': widget.alimento.codigo,
        'tipo': widget.alimento.tipoIngesta,
        'comida': comida,
        'fecha': ingesta.fecha,
      });
      agregado = true;
      final nuevo = (datos as Json?)?['ingestaDiaria'] as Json?;
      final id = nuevo?['id'] as int?;
      if (_unidad != null || cantidad != 1) {
        if (id == null) throw const ApiError('Se agregó con 1 porción; cambia la cantidad desde la dieta.');
        await Api.put('ingesta/alimentos/$id', {
          'fecha': ingesta.fecha,
          if (_unidad == null) ...{
            // En porciones base: N porciones = N veces lo que creó el servidor.
            'accion': 'ActualizarCantidad',
            'cantidad': cantidad * numero(nuevo?['cantidad'] ?? 1),
          } else ...{
            'accion': 'ActualizarCantidadYUnidad',
            'cantidad': cantidad,
            'unidad': _unidad,
          },
        });
      }
      if (!mounted) return;
      Cambios.avisar(fechaIngesta: ingesta.fecha);
      final dieta = ingesta.nombre.isEmpty ? fechaVista(ingesta.fecha) : ingesta.nombre;
      Navigator.of(context).pop<_Destino>((dieta: dieta, comida: comida));
    } on ApiError catch (e) {
      if (!mounted) return;
      if (agregado) {
        // Ya quedó en la dieta: se avisa para no duplicarlo con otro intento.
        Cambios.avisar(fechaIngesta: ingesta.fecha);
        mostrarMensaje(context, 'Se agregó, pero no se pudo ajustar la cantidad: ${e.detalle}');
        Navigator.of(context).pop();
      } else {
        setState(() => _error = e.detalle);
      }
    } finally {
      if (mounted) setState(() => _agregando = false);
    }
  }

  String _equivalencia() {
    final valor = _valor;
    final unidad = _unidades.where((u) => u.nombre == _unidad).firstOrNull;
    if (valor != null && unidad != null) return 'Equivale a ${fmtNum(valor * unidad.gramos, 1)} g';
    final a = widget.alimento;
    return valor == null || valor <= 0
        ? 'Ingresa una cantidad mayor a 0'
        : '${fmtNum(valor)} × porción ≈ ${(a.kcal * valor).round()} kcal';
  }

  @override
  Widget build(BuildContext context) {
    final dietas = _dietas;
    final ingesta = _ingesta;
    final bloqueo = ingesta?.bloqueo;
    final listo = !_cargando && !_agregando && ingesta != null && bloqueo == null && _comida != null;
    return AlertDialog(
      title: const Text('Agregar a una dieta'),
      content: SizedBox(
        width: 360,
        child: dietas == null
            ? (_error != null ? Text(_error!, style: EqText.bodySm) : const SizedBox(height: 96, child: Cargando()))
            : dietas.isEmpty
            ? Text('Aún no tienes dietas. Crea una en "Mis dietas" para agregarle alimentos.', style: EqText.bodySm)
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(widget.alimento.descripcion, style: EqText.label.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: EqSpace.md),
                  EqField(
                    etiqueta: 'Dieta',
                    child: DropdownButtonFormField<String>(
                      initialValue: _fecha,
                      isExpanded: true,
                      items: [
                        for (final d in dietas)
                          DropdownMenuItem(
                            value: d.fecha,
                            child: Text(d.etiqueta, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: _agregando ? null : _elegirDieta,
                    ),
                  ),
                  const SizedBox(height: 12),
                  EqField(
                    etiqueta: 'Comida',
                    child: DropdownButtonFormField<String>(
                      key: ValueKey(_fecha),
                      initialValue: _comida,
                      isExpanded: true,
                      items: [
                        for (final c in ingesta?.comidas ?? const <ComidaIngesta>[])
                          DropdownMenuItem(value: c.nombre, child: Text(c.nombre)),
                      ],
                      onChanged: _cargando || _agregando ? null : (c) => setState(() => _comida = c),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: EqField(
                          etiqueta: 'Cantidad',
                          child: TextField(
                            controller: _cantidad,
                            enabled: !_agregando,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: EqField(
                          etiqueta: 'Unidad',
                          child: DropdownButtonFormField<String?>(
                            initialValue: _unidad,
                            isExpanded: true,
                            items: [
                              const DropdownMenuItem<String?>(value: null, child: Text('Porción')),
                              for (final u in _unidades)
                                DropdownMenuItem<String?>(
                                  value: u.nombre,
                                  child: Text(u.nombre, overflow: TextOverflow.ellipsis),
                                ),
                            ],
                            onChanged: _agregando ? null : (u) => setState(() => _unidad = u),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: EqSpace.sm),
                  if (bloqueo != null)
                    Text(bloqueo, style: EqText.bodySm.copyWith(color: EqColors.errorText))
                  else
                    Text(
                      _equivalencia(),
                      style: EqText.caption.copyWith(letterSpacing: 0, color: EqColors.textFaint),
                    ),
                  if (_error != null) ...[
                    const SizedBox(height: EqSpace.sm),
                    Text(_error!, style: EqText.bodySm.copyWith(color: EqColors.errorText)),
                  ],
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: _agregando ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: listo ? _agregar : null,
          child: Text(_agregando ? 'Agregando…' : 'Agregar'),
        ),
      ],
    );
  }
}

class _Macro extends StatelessWidget {
  const _Macro({required this.icono, required this.nombre, required this.valor, required this.color});

  final IconData icono;
  final String nombre;
  final String valor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return EqCard(
      sombra: false,
      color: color.withValues(alpha: 0.08),
      borde: color.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: color),
          const SizedBox(height: EqSpace.sm),
          Text(nombre, style: EqText.bodySm, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(valor, style: EqText.h4.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
