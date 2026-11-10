import 'package:flutter/material.dart';

import '../data/analisis.dart';
import '../data/api.dart';
import '../data/cambios.dart';
import '../data/models.dart';
import '../theme/eq_tokens.dart';
import '../widgets/analisis_nutricional.dart';
import '../widgets/boton_crear.dart';
import '../widgets/boton_optimizar.dart';
import '../widgets/comida_bloque.dart';
import '../widgets/editar_item.dart';
import '../widgets/eq_basicos.dart';
import '../widgets/eq_top_bar.dart';
import '../widgets/fecha_libre.dart';
import '../widgets/popup_buscar.dart';
import '../widgets/progreso_ajuste.dart';
import '../widgets/hoja_inferior.dart';
import 'crear_dieta_screen.dart';

/// Dónde quedan los cambios del ajuste automático; se elige antes de optimizar.
enum _Destino { sobrescribir, fechaNueva }

/// Pestaña "Mis dietas": la ingesta de una fecha (GET ingesta) por tiempos de comida.
class VerDietaScreen extends StatefulWidget {
  const VerDietaScreen({super.key});

  @override
  State<VerDietaScreen> createState() => _VerDietaScreenState();
}

class _VerDietaScreenState extends State<VerDietaScreen> {
  Ingesta? _ingesta;

  /// Análisis del día completo de [_ingesta]; da la satisfacción de la tarjeta
  /// y se reutiliza en "Ver más".
  AnalisisNutricional? _analisis;
  String? _error;
  var _cargando = true;
  var _ocupado = false;
  final _seleccionados = <int>{};

  @override
  void initState() {
    super.initState();
    Cambios.version.addListener(_recargar);
    _cargar();
  }

  @override
  void dispose() {
    Cambios.version.removeListener(_recargar);
    super.dispose();
  }

  void _recargar() {
    final fecha = Cambios.fechaIngesta ?? _ingesta?.fecha;
    Cambios.fechaIngesta = null;
    _cargar(fecha);
  }

  Future<void> _cargar([String? fecha]) async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      var ingesta = Ingesta.desdeJson(
        await Api.get('ingesta', {'fecha': fecha}) as Json,
      );
      // Sin fecha la API abre la de hoy; si hoy no hay dieta se abre la más reciente.
      if (fecha == null && ingesta.vacia && ingesta.dietas.isNotEmpty) {
        ingesta = Ingesta.desdeJson(
          await Api.get('ingesta', {'fecha': fechaDietaMasReciente(ingesta.dietas)})
              as Json,
        );
      }
      if (!mounted) return;
      setState(() {
        _ingesta = ingesta;
        _seleccionados.removeWhere(
          (id) => !ingesta.comidas.any((c) => c.items.any((i) => i.id == id)),
        );
      });
      Cambios.ingestaActual.value = ingesta;
      _cargarAnalisis(ingesta);
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.detalle);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  /// Pide el análisis del día para la tarjeta; si falla, la tarjeta queda sin número.
  Future<void> _cargarAnalisis(Ingesta ingesta) async {
    setState(() => _analisis = null);
    if (ingesta.vacia || ingesta.totalItems == 0) return;
    try {
      final datos = await Api.get('analisis', {
        'fecha': ingesta.fecha,
        'tipo': 'DIA-COMPLETO',
      }) as Json;
      if (mounted && identical(_ingesta, ingesta)) {
        setState(() => _analisis = AnalisisNutricional.desdeJson(datos));
      }
    } on ApiError {
      // Sin análisis la tarjeta muestra "—"; "Ver más" lo vuelve a intentar.
    }
  }

  void _toggle(ItemIngesta item) {
    setState(() {
      if (!_seleccionados.remove(item.id)) _seleccionados.add(item.id);
    });
  }

  /// Tocar el nombre de la comida marca todos sus alimentos, o los desmarca
  /// si ya estaban todos marcados.
  void _toggleComida(ComidaIngesta comida) {
    final ids = comida.items.map((i) => i.id);
    setState(() {
      if (ids.every(_seleccionados.contains)) {
        _seleccionados.removeAll(ids);
      } else {
        _seleccionados.addAll(ids);
      }
    });
  }

  List<ItemIngesta> get _seleccion => [
    for (final c in _ingesta!.comidas)
      ...c.items.where((i) => _seleccionados.contains(i.id)),
  ];

  /// Llama a la API una vez por alimento (no hay operaciones en lote) y recarga.
  Future<void> _porCada<T>(
    List<T> elementos,
    Future<void> Function(T) llamada,
    String hecho,
  ) async {
    setState(() => _ocupado = true);
    var bien = 0;
    ApiError? fallo;
    for (final e in elementos) {
      try {
        await llamada(e);
        bien++;
      } on ApiError catch (error) {
        fallo = error;
        break;
      }
    }
    if (!mounted) return;
    setState(() {
      _ocupado = false;
      _seleccionados.clear();
    });
    final n = bien == 1 ? '1 alimento' : '$bien alimentos';
    mostrarMensaje(
      context,
      fallo == null
          ? '$n $hecho'
          : '${bien > 0 ? '$n $hecho. ' : ''}${fallo.detalle}',
    );
    await _cargar(_ingesta?.fecha);
  }

  Future<void> _agregar(ComidaIngesta comida) async {
    final nuevos = await mostrarBuscadorParaAgregar(context, comida.nombre);
    if (nuevos == null || nuevos.isEmpty || !mounted) return;
    final fecha = _ingesta!.fecha;
    await _porCada(
      nuevos,
      (a) => Api.post('ingesta/alimentos', {
        'codigo': a.codigo,
        'tipo': a.tipoIngesta,
        'comida': comida.nombre,
        'fecha': fecha,
      }),
      'agregados a ${comida.nombre}',
    );
  }

  Future<void> _editar(ItemIngesta item) async {
    final guardado = await editarItem(context, _ingesta!.fecha, item);
    if (guardado != true || !mounted) return;
    mostrarMensaje(context, '${item.nombre} actualizado');
    await _cargar(_ingesta?.fecha);
  }

  Future<void> _eliminar() async {
    final seleccion = _seleccion;
    final si = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar alimentos'),
        content: Text(
          seleccion.length == 1
              ? 'Se quitará ${seleccion.first.nombre} de la dieta.'
              : 'Se quitarán ${seleccion.length} alimentos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (si != true) return;
    final fecha = _ingesta!.fecha;
    await _porCada(
      seleccion,
      (i) => Api.delete('ingesta/alimentos/${i.id}', {'fecha': fecha}),
      'eliminados',
    );
  }

  Future<void> _eliminarDieta() async {
    final ingesta = _ingesta!;
    final si = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar dieta'),
        content: Text(
          'Se eliminará toda la dieta del ${fechaVista(ingesta.fecha)}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (si != true || !mounted) return;
    try {
      await Api.delete('ingesta/dietas', {'fecha': ingesta.fecha});
      if (!mounted) return;
      mostrarMensaje(context, Api.ultimoMensaje ?? 'Dieta eliminada');
      Cambios.avisar();
    } on ApiError catch (e) {
      if (mounted) mostrarMensaje(context, e.detalle);
    }
  }

  Future<void> _mover() async {
    final destino = await _elegirComida('Mover a');
    if (destino == null || !mounted) return;
    final fecha = _ingesta!.fecha;
    await _porCada(
      _seleccion.where((i) => i.comida != destino.nombre).toList(),
      (i) => Api.post('ingesta/alimentos/${i.id}/mover', {
        'fecha': fecha,
        'nuevaComida': destino.nombre,
      }),
      'movidos a ${destino.nombre}',
    );
  }

  Future<ComidaIngesta?> _elegirComida(String titulo) {
    final n = _seleccionados.length;
    return showModalBottomSheet<ComidaIngesta>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: EqSpace.sm),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: EqColors.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  EqSpace.lg,
                  EqSpace.md,
                  EqSpace.lg,
                  EqSpace.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: EqText.h3),
                    Text(
                      n == 1
                          ? '1 alimento seleccionado'
                          : '$n alimentos seleccionados',
                      style: EqText.bodySm,
                    ),
                  ],
                ),
              ),
              for (final c in _ingesta!.comidas)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: EqSpace.lg,
                  ),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: EqColors.acentoFondo,
                      borderRadius: BorderRadius.circular(EqRadius.md),
                    ),
                    child: Icon(
                      Icons.restaurant,
                      color: EqColors.acento,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    c.nombre,
                    style: EqText.label.copyWith(fontSize: 16),
                  ),
                  subtitle: Text(
                    '${c.items.length} alimentos',
                    style: EqText.bodySm.copyWith(fontSize: 13),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: EqColors.textFaint,
                  ),
                  onTap: () => Navigator.of(context).pop(c),
                ),
              const SizedBox(height: EqSpace.md),
            ],
          ),
        ),
      ),
    );
  }

  /// Nutrientes solo de los alimentos marcados (GET analisis por ids de fila).
  /// En el servidor PLATO y ALIMENTO filtran igual por id, así que va una sola llamada.
  Future<void> _verNutrientes() async {
    final ingesta = _ingesta!;
    final seleccion = _seleccion;
    if (seleccion.isEmpty) return;
    setState(() => _ocupado = true);
    try {
      final datos = await Api.get('analisis', {
        'fecha': ingesta.fecha,
        'tipo': 'ALIMENTO',
        'ids': seleccion.map((i) => i.id).join(','),
      }) as Json;
      if (!mounted) return;
      await verAnalisis(
        context,
        seleccion.length == 1 ? seleccion.first.nombre : '${seleccion.length} alimentos',
        AnalisisNutricional.desdeJson(datos),
        titulo: 'Ver nutrientes',
      );
    } on ApiError catch (e) {
      if (mounted) mostrarMensaje(context, e.detalle);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _verAnalisis() async {
    final ingesta = _ingesta!;
    setState(() => _ocupado = true);
    try {
      final analisis =
          _analisis ??
          AnalisisNutricional.desdeJson(
            await Api.get('analisis', {
                  'fecha': ingesta.fecha,
                  'tipo': 'DIA-COMPLETO',
                })
                as Json,
          );
      if (!mounted) return;
      final nombre = ingesta.nombre.isEmpty
          ? fechaVista(ingesta.fecha)
          : ingesta.nombre;
      await verAnalisis(
        context,
        nombre,
        analisis,
        objetivos: ingesta.objetivos,
      );
    } on ApiError catch (e) {
      if (mounted) mostrarMensaje(context, e.detalle);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  /// Antes de optimizar: permitir reemplazos y dónde guardar el resultado.
  /// Devuelve null si se canceló.
  Future<({bool intercambio, String? nuevaFecha})?> _pedirOpciones() {
    final ocupadas = _ingesta!.dietas.map((d) => d.fecha).toList();
    var intercambio = false;
    var destino = _Destino.sobrescribir;
    DateTime? dia;
    return showDialog<({bool intercambio, String? nuevaFecha})>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogo) {
          Future<void> elegirFecha() async {
            final elegido = await elegirFechaLibre(
              context,
              ocupadas: ocupadas,
              inicial:
                  dia ??
                  primerDiaLibre(
                    ocupadas,
                    DateTime.now().add(const Duration(days: 1)),
                  ),
            );
            if (elegido == null) return;
            setDialogo(() {
              dia = elegido;
              destino = _Destino.fechaNueva;
            });
          }

          Widget opcion(
            _Destino valor,
            String titulo,
            String? subtitulo,
            VoidCallback onTap,
          ) {
            final marcada = destino == valor;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                marcada ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: marcada ? EqColors.acento : EqColors.textFaint,
              ),
              title: Text(titulo),
              subtitle: subtitulo == null ? null : Text(subtitulo),
              onTap: onTap,
            );
          }

          final elegida = dia;
          final listo = destino == _Destino.sobrescribir || elegida != null;
          return AlertDialog(
            title: const Text('Optimizar dieta'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Equilibra ajustará las cantidades para acercar la dieta a tus objetivos. Usa el cupo de ajuste automático de tu plan.',
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: intercambio,
                    onChanged: (v) => setDialogo(() => intercambio = v),
                    title: const Text('Permitir reemplazar alimentos'),
                  ),
                  const SizedBox(height: EqSpace.sm),
                  Text('¿Dónde guardar el resultado?', style: EqText.label),
                  opcion(
                    _Destino.sobrescribir,
                    'Sobrescribir esta dieta',
                    null,
                    () => setDialogo(() => destino = _Destino.sobrescribir),
                  ),
                  opcion(
                    _Destino.fechaNueva,
                    'Guardar en una fecha nueva',
                    elegida == null
                        ? 'Toca para elegir la fecha'
                        : fechaVista(fechaApi(elegida)),
                    elegirFecha,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: listo
                    ? () => Navigator.pop(context, (
                        intercambio: intercambio,
                        nuevaFecha: destino == _Destino.fechaNueva
                            ? fechaApi(elegida!)
                            : null,
                      ))
                    : null,
                child: const Text('Optimizar'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Ajusta la dieta y aplica los cambios sobre ella misma.
  /// Devuelve null si se canceló o no hubo nada que cambiar.
  Future<Json?> _optimizarAqui(String fecha, bool intercambio) async {
    await Api.post('ajuste/automatico', {
      'fecha': fecha,
      'permitirIntercambio': intercambio,
      'origen': 'app-movil',
    });
    if (!mounted) return null;
    final resultado = await esperarAjuste(
      context,
      tipo: TipoAjuste.automatico,
      fecha: fecha,
    );
    if (!mounted) return null;
    if (resultado == null) {
      mostrarMensaje(context, 'Optimización cancelada');
      return null;
    }
    // El ajuste deja los cambios pendientes: la dieta solo cambia al aplicarlos.
    final pendientes = (resultado['cantidadCambiosPendientes'] as num?) ?? 0;
    if (pendientes <= 0) {
      mostrarMensaje(
        context,
        (resultado['mensaje'] as String?) ??
            'Tu dieta ya está lo más cerca posible de tus objetivos.',
      );
      return null;
    }
    setState(() => _ocupado = true);
    try {
      await Api.post('ajuste/guiado', {
        'fecha': fecha,
        'decision': 'APLICAR_CAMBIOS',
      });
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
    return resultado;
  }

  /// Crea la dieta ajustada en [nueva]; la original queda como estaba.
  /// El servidor corre el ajuste, crea la dieta y descarta los pendientes.
  Future<Json?> _optimizarEnFecha(
    String fecha,
    String nueva,
    bool intercambio,
  ) async {
    final ingesta = _ingesta!;
    final base = ingesta.nombre.trim().isEmpty ? 'Dieta' : ingesta.nombre.trim();
    final nombre = '$base ajustada';
    await Api.post('ajuste/dieta-ajustada', {
      'fechaOriginal': fecha,
      'nuevaFecha': nueva,
      'nombre': nombre.length > 120 ? nombre.substring(0, 120) : nombre,
      'permitirIntercambio': intercambio,
    });
    if (!mounted) return null;
    return esperarAjuste(context, tipo: TipoAjuste.dietaAjustada, fecha: fecha);
  }

  Future<void> _optimizar() async {
    final opciones = await _pedirOpciones();
    if (opciones == null || !mounted) return;
    final fecha = _ingesta!.fecha;
    final nueva = opciones.nuevaFecha;
    try {
      final resultado = nueva == null
          ? await _optimizarAqui(fecha, opciones.intercambio)
          : await _optimizarEnFecha(fecha, nueva, opciones.intercambio);
      if (resultado == null || !mounted) return;
      mostrarMensaje(
        context,
        nueva == null
            ? 'Dieta optimizada'
            : 'Dieta ajustada guardada el ${fechaVista(nueva)}',
      );
      Cambios.avisar(fechaIngesta: nueva ?? fecha);
    } on ApiError catch (e) {
      if (mounted) mostrarMensaje(context, e.detalle);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ingesta = _ingesta;
    final editable =
        ingesta != null &&
        !ingesta.vacia &&
        ingesta.bloqueo == null &&
        !_ocupado;
    return Scaffold(
      appBar: const EqTopBar(),
      body: ConBotonCrear(
        encima: editable && ingesta.totalItems > 0
            ? BotonOptimizar(onPressed: _optimizar)
            : null,
        acciones: [
          AccionMenu(
            icono: Icons.add,
            etiqueta: 'Crear dieta',
            onTap: () => abrirHoja<void>(context, const CrearDietaScreen()),
          ),
          AccionMenu(
            icono: Icons.delete_outline,
            etiqueta: 'Eliminar dieta',
            color: EqColors.error,
            habilitada: editable,
            onTap: _eliminarDieta,
          ),
        ],
        seleccionados: editable ? _seleccionados.length : 0,
        accionesSeleccion: [
          AccionFlotante(
            icono: Icons.visibility_outlined,
            etiqueta: 'Ver nutrientes',
            color: EqColors.primary,
            insignia: _seleccionados.length,
            onTap: _verNutrientes,
          ),
          AccionFlotante(
            icono: Icons.drive_file_move_outline,
            etiqueta: 'Mover',
            color: EqColors.indigo,
            onTap: _mover,
          ),
          AccionFlotante(
            icono: Icons.delete_outline,
            etiqueta: 'Eliminar',
            color: EqColors.error,
            onTap: _eliminar,
          ),
        ],
        child: RefreshIndicator(
          onRefresh: () => _cargar(ingesta?.fecha),
          child: _contenido(editable),
        ),
      ),
    );
  }

  Widget _contenido(bool editable) {
    final ingesta = _ingesta;
    if (_cargando && ingesta == null) return const Cargando();
    if (_error != null && ingesta == null)
      return ErrorCarga(_error!, onReintentar: _cargar);
    if (ingesta == null) return const SizedBox.shrink();
    final dietas = ingesta.dietas;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        EqSpace.md,
        EqSpace.lg,
        EqSpace.md,
        EqSpace.xl,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 140),
          child: Text('Ingesta diaria', style: EqText.h2),
        ),
        const SizedBox(height: EqSpace.md),
        if (_cargando || _ocupado) const LinearProgressIndicator(),
        if (dietas.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 72),
            child: EqField(
              etiqueta: 'Dieta',
              child: DropdownButtonFormField<String>(
                key: ValueKey(ingesta.fecha),
                initialValue: dietas.any((d) => d.fecha == ingesta.fecha)
                    ? ingesta.fecha
                    : null,
                hint: Text('${fechaVista(ingesta.fecha)} · sin dieta'),
                isExpanded: true,
                items: [
                  for (final d in dietas)
                    DropdownMenuItem(
                      value: d.fecha,
                      child: Text(d.etiqueta, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (f) {
                  _seleccionados.clear();
                  _cargar(f);
                },
              ),
            ),
          ),
        const SizedBox(height: EqSpace.md),
        if (ingesta.vacia)
          EqAviso(
            dietas.isEmpty
                ? 'Todavía no tienes dietas. Abre el menú para crear tu primera ingesta.'
                : 'No hay dieta el ${fechaVista(ingesta.fecha)}. Elige otra o abre el menú para crearla.',
            icono: Icons.restaurant_menu,
          )
        else ...[
          if (ingesta.bloqueo != null) ...[
            EqAviso(ingesta.bloqueo!, icono: Icons.lock_outline),
            const SizedBox(height: EqSpace.md),
          ],
          _Resumen(
            satisfaccion: _analisis?.satisfaccion,
            onVerMas: _ocupado || ingesta.totalItems == 0 ? null : _verAnalisis,
          ),
          for (final comida in ingesta.comidas) ...[
            const SizedBox(height: EqSpace.md),
            ComidaBloque(
              bloque: comida,
              seleccionados: _seleccionados,
              editable: editable,
              onToggle: _toggle,
              onToggleComida: () => _toggleComida(comida),
              onAgregar: () => _agregar(comida),
              onEditar: _editar,
            ),
          ],
        ],
      ],
    );
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen({required this.satisfaccion, required this.onVerMas});

  /// null mientras carga o si no se pudo calcular.
  final double? satisfaccion;
  final VoidCallback? onVerMas;

  @override
  Widget build(BuildContext context) {
    final s = satisfaccion;
    return EqHero(
      onTap: onVerMas,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SATISFACCIÓN GENERAL',
            style: EqText.caption.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: EqSpace.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                s == null ? '—' : '${fmtNum(s, 1)} %',
                style: EqText.h1.copyWith(color: Colors.white),
              ),
              const Spacer(),
              TextButton(
                onPressed: onVerMas,
                style: TextButton.styleFrom(
                  foregroundColor: EqColors.primarySoft,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Ver más'),
                    Icon(Icons.chevron_right, size: 18),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: s == null ? null : (s / 100).clamp(0, 1).toDouble(),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
            color: EqColors.primarySoft,
            backgroundColor: Colors.white24,
          ),
        ],
      ),
    );
  }
}
