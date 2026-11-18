import 'package:flutter/material.dart';

import '../data/analisis.dart';
import '../data/api.dart';
import '../data/cambios.dart';
import '../data/cache_dietas.dart';
import '../data/models.dart';
import '../data/ultima_dieta.dart';
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
import '../widgets/selector_dieta.dart';
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

  /// Agua, costo e índice glucémico del día (GET ingesta/objetivos); la tarjeta
  /// muestra "—" mientras llegan.
  ObjetivosDia? _objetivos;
  String? _error;
  var _cargando = true;
  var _ocupado = false;
  final _seleccionados = <int>{};

  /// Alimentos que tocó la última optimización de la dieta abierta.
  var _marcas = <int, TipoCambio>{};

  /// Datos para calcular [_marcas] cuando se recargue la dieta optimizada.
  ({String fecha, Map<int, String> antes, List<Json> cambios})? _porMarcar;

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

  /// [desdeCache] solo al deslizar: usa la vecina ya pedida. El resto de
  /// recargas (tras editar u optimizar) piden la fecha fresca al servidor.
  Future<void> _cargar([String? fecha, bool desdeCache = false]) async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      if (fecha != null && !desdeCache) CacheDietas.olvidar(fecha);
      var ingesta = fecha == null
          ? Ingesta.desdeJson(await Api.get('ingesta') as Json)
          : await CacheDietas.ingesta(fecha);
      // Sin fecha la API abre la de hoy; se abre la última dieta editada
      // (o, si no hay, la más reciente).
      if (fecha == null && ingesta.dietas.isNotEmpty) {
        final elegida = await fechaDietaAMostrar(ingesta.dietas);
        if (elegida != ingesta.fecha) {
          CacheDietas.olvidar(elegida);
          ingesta = await CacheDietas.ingesta(elegida);
        }
      }
      if (!mounted) return;
      setState(() {
        if (_porMarcar case final p? when p.fecha == ingesta.fecha) {
          _marcas = _calcularMarcas(ingesta, p.antes, p.cambios);
          _porMarcar = null;
        } else if (_ingesta?.fecha != ingesta.fecha) {
          _marcas = {};
        }
        _ingesta = ingesta;
        _seleccionados.removeWhere(
          (id) => !ingesta.comidas.any((c) => c.items.any((i) => i.id == id)),
        );
      });
      Cambios.ingestaActual.value = ingesta;
      // Guarda esta y pide por adelantado la anterior y la siguiente.
      CacheDietas.mantener('dietas', ingesta);
      _cargarAnalisis(ingesta);
      _cargarObjetivos(ingesta);
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
      final analisis = await CacheDietas.analisis(ingesta);
      if (mounted && identical(_ingesta, ingesta)) {
        setState(() => _analisis = analisis);
      }
    } on ApiError {
      // Sin análisis la tarjeta muestra "—"; "Ver más" lo vuelve a intentar.
    }
  }

  /// Pide agua, costo e índice glucémico para la tarjeta; si falla muestra "—".
  Future<void> _cargarObjetivos(Ingesta ingesta) async {
    setState(() => _objetivos = null);
    if (ingesta.vacia || ingesta.totalItems == 0) return;
    try {
      final datos =
          await Api.get('ingesta/objetivos', {'fecha': ingesta.fecha}) as Json;
      if (mounted && identical(_ingesta, ingesta)) {
        setState(() => _objetivos = ObjetivosDia.desdeJson(datos));
      }
    } on ApiError {
      // Sin esto la tarjeta muestra "—".
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

  Future<void> _eliminar([List<ItemIngesta>? items]) async {
    final seleccion = items ?? _seleccion;
    if (seleccion.isEmpty) return;
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
        seleccion.length == 1
            ? seleccion.first.nombre
            : '${seleccion.length} alimentos',
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
            }) as Json,
          );
      if (!mounted) return;
      final nombre = ingesta.nombre.isEmpty
          ? fechaVista(ingesta.fecha)
          : ingesta.nombre;
      await verAnalisis(
        context,
        nombre,
        analisis,
        objetivos: _objetivos ?? ingesta.objetivos,
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
                marcada
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
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
  /// Compara la dieta antes y después de optimizar. Un id que ya existía con
  /// otro alimento es un intercambio; un id nuevo es intercambio si el ajuste
  /// reporta un INTERCAMBIO con ese alimento, si no es nuevo. Los que solo
  /// cambiaron de cantidad no se marcan.
  Map<int, TipoCambio> _calcularMarcas(
    Ingesta despues,
    Map<int, String> antes,
    List<Json> cambios,
  ) {
    final intercambiados = {
      for (final c in cambios)
        if ((c['tipo'] as String? ?? '').toUpperCase() == 'INTERCAMBIO')
          c['codPlatoAlimento'] as String? ?? '',
    };
    return {
      for (final comida in despues.comidas)
        for (final item in comida.items)
          if (!antes.containsKey(item.id))
            item.id: intercambiados.contains(item.codigo)
                ? TipoCambio.intercambio
                : TipoCambio.nuevo
          else if (antes[item.id] != item.codigo)
            item.id: TipoCambio.intercambio,
    };
  }

  /// Análisis de [fecha] ya con los cambios aplicados; null si no se pudo traer
  /// (el diálogo de optimización se cierra entonces sin animar el resultado).
  Future<AnalisisNutricional?> _analisisFinal(String fecha) async {
    try {
      return AnalisisNutricional.desdeJson(
        await Api.get('analisis', {'fecha': fecha, 'tipo': 'DIA-COMPLETO'})
            as Json,
      );
    } on ApiError {
      return null;
    }
  }

  Future<Json?> _optimizarAqui(String fecha, bool intercambio) async {
    final antes = {
      for (final c in _ingesta!.comidas)
        for (final i in c.items) i.id: i.codigo,
    };
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
      satisfaccionInicial: _analisis?.satisfaccion,
      nutrientesIniciales: _analisis?.nutrientes,
      // Dentro del mismo diálogo: aplica los cambios y trae el análisis final.
      alCompletar: (resultado) async {
        // El ajuste deja los cambios pendientes: la dieta solo cambia al aplicarlos.
        final pendientes =
            (resultado['cantidadCambiosPendientes'] as num?) ?? 0;
        if (pendientes <= 0) return null;
        await Api.post('ajuste/guiado', {
          'fecha': fecha,
          'decision': 'APLICAR_CAMBIOS',
        });
        _porMarcar = (
          fecha: fecha,
          antes: antes,
          cambios: [
            for (final c in resultado['cambiosAplicados'] as List? ?? const [])
              c as Json,
          ],
        );
        return _analisisFinal(fecha);
      },
    );
    if (!mounted) return null;
    if (resultado == null) {
      mostrarMensaje(context, 'Optimización cancelada');
      return null;
    }
    final pendientes = (resultado['cantidadCambiosPendientes'] as num?) ?? 0;
    if (pendientes <= 0) {
      mostrarMensaje(
        context,
        (resultado['mensaje'] as String?) ??
            'Tu dieta ya está lo más cerca posible de tus objetivos.',
      );
      return null;
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
    final base = ingesta.nombre.trim().isEmpty
        ? 'Dieta'
        : ingesta.nombre.trim();
    final nombre = '$base ajustada';
    await Api.post('ajuste/dieta-ajustada', {
      'fechaOriginal': fecha,
      'nuevaFecha': nueva,
      'nombre': nombre.length > 120 ? nombre.substring(0, 120) : nombre,
      'permitirIntercambio': intercambio,
    });
    if (!mounted) return null;
    return esperarAjuste(
      context,
      tipo: TipoAjuste.dietaAjustada,
      fecha: fecha,
      satisfaccionInicial: _analisis?.satisfaccion,
      nutrientesIniciales: _analisis?.nutrientes,
      alCompletar: (_) => _analisisFinal(nueva),
    );
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
      extendBodyBehindAppBar: true,
      appBar: EqTopBar(
        flotante: true,
        acciones: [
          if (editable && ingesta.totalItems > 0)
            BotonOptimizar(onPressed: _optimizar),
          BotonCircular(
            icono: Icons.add,
            tooltip: 'Crear nueva dieta',
            onPressed: () => abrirHoja<void>(context, const CrearDietaScreen()),
          ),
          BotonCircular(
            icono: Icons.delete_outline,
            tooltip: 'Eliminar dieta',
            relleno: false,
            color: EqColors.error,
            onPressed: editable ? _eliminarDieta : null,
          ),
        ],
      ),
      body: ConBotonCrear(
        seleccionados: editable ? _seleccionados.length : 0,
        onCancelarSeleccion: () => setState(_seleccionados.clear),
        accionesSeleccion: [
          AccionFlotante(
            icono: Icons.visibility_outlined,
            etiqueta: 'Ver nutrientes',
            color: EqColors.primary,
            insignia: _seleccionados.length,
            onTap: _verNutrientes,
          ),
          // Editar es de a un alimento: solo aparece con uno seleccionado.
          if (_seleccionados.length == 1)
            AccionFlotante(
              icono: Icons.edit_outlined,
              etiqueta: 'Editar',
              color: EqColors.primary,
              onTap: () => _editar(_seleccion.single),
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
          onRefresh: () {
            CacheDietas.limpiar();
            return _cargar(ingesta?.fecha);
          },
          child: _contenido(editable),
        ),
      ),
    );
  }

  Widget _contenido(bool editable) {
    final ingesta = _ingesta;
    if (_cargando && ingesta == null) return const Cargando();
    if (_error != null && ingesta == null) {
      return ErrorCarga(_error!, onReintentar: _cargar);
    }
    if (ingesta == null) return const SizedBox.shrink();
    final dietas = ingesta.dietas;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        EqSpace.md,
        EqSpace.lg + espacioBarra(context),
        EqSpace.md,
        EqSpace.xl,
      ),
      children: [
        Text('Ingesta diaria', style: EqText.h2),
        const SizedBox(height: EqSpace.md),
        if (_cargando || _ocupado) const LinearProgressIndicator(),
        if (dietas.isNotEmpty)
          EqField(
            etiqueta: 'Dieta',
            child: CampoDieta(
              ingesta: ingesta,
              onElegir: (f) {
                _seleccionados.clear();
                _cargar(f);
              },
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
            objetivos: _objetivos,
            calorias: _analisis?.nutrientes
                .where((n) => n.campo == 'KCALS')
                .firstOrNull,
            onVerMas: _ocupado || ingesta.totalItems == 0 ? null : _verAnalisis,
          ),
          for (final comida in ingesta.comidas) ...[
            const SizedBox(height: EqSpace.md),
            ComidaBloque(
              bloque: comida,
              seleccionados: _seleccionados,
              editable: editable,
              onToggle: _toggle,
              onEditar: _editar,
              onEliminar: (item) => _eliminar([item]),
              onToggleComida: () => _toggleComida(comida),
              onAgregar: () => _agregar(comida),
              marcas: _marcas,
            ),
          ],
        ],
      ],
    );
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen({
    required this.satisfaccion,
    required this.objetivos,
    required this.calorias,
    required this.onVerMas,
  });

  /// null mientras carga o si no se pudo calcular.
  final double? satisfaccion;

  /// Agua, costo e índice glucémico del día; null mientras cargan.
  final ObjetivosDia? objetivos;

  /// Fila KCALS del análisis (objetivo y cantidad); null mientras carga.
  final Nutriente? calorias;
  final VoidCallback? onVerMas;

  @override
  Widget build(BuildContext context) {
    final o = objetivos;
    return EqHero(
      onTap: onVerMas,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnilloSatisfaccion(satisfaccion),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: [
                    _DatoDia(
                      'Agua',
                      o == null || o.agua <= 0 ? '—' : '${o.agua.round()} ml',
                      fraccion: o == null ? 0 : o.agua / 2000,
                      color: o == null || o.agua <= 0
                          ? null
                          : _colorAgua(o.agua),
                    ),
                    const SizedBox(height: 12),
                    _DatoDia(
                      'Costo',
                      o == null || o.costo <= 0
                          ? '—'
                          : '\$${o.costo.toStringAsFixed(2)}',
                      fraccion: o == null ? 0 : o.costo / 10,
                      color: o == null || o.costo <= 0
                          ? null
                          : _colorCosto(o.costo),
                    ),
                    const SizedBox(height: 12),
                    _DatoDia(
                      'Índice glucémico',
                      o == null || o.indiceGlucemico <= 0
                          ? '—'
                          : fmtNum(o.indiceGlucemico),
                      fraccion: o == null ? 0 : o.indiceGlucemico / 100,
                      color: o == null || o.indiceGlucemico <= 0
                          ? null
                          : _colorIg(o.indiceGlucemico),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (calorias case final k?) ...[
            const SizedBox(height: EqSpace.md),
            const Divider(height: 1, color: Colors.white24),
            const SizedBox(height: EqSpace.md),
            _CaloriasResumen(k),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onVerMas,
              style: TextButton.styleFrom(
                foregroundColor: EqColors.primarySoft,
                visualDensity: VisualDensity.compact,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Ver análisis'),
                  Icon(Icons.chevron_right, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Un dato del día (agua, costo, índice glucémico) sobre el fondo oscuro del resumen.
/// Colores de las barras, con las mismas pautas de la web: agua rojo <1000 ml,
/// naranja <1500, amarillo <2000, verde desde 2000; costo verde ≤6, amarillo ≤10,
/// rojo por encima; índice glucémico (menos es mejor) verde ≤55, amarillo ≤69,
/// rojo desde 70.
const _verde = Color(0xFF8FD6A4);
const _amarillo = Color(0xFFF5D76E);
const _naranja = Color(0xFFFFB066);
const _rojo = Color(0xFFFFA39B);

Color _colorAgua(double ml) => ml >= 2000
    ? _verde
    : ml >= 1500
    ? _amarillo
    : ml >= 1000
    ? _naranja
    : _rojo;

Color _colorCosto(double c) => c > 10
    ? _rojo
    : c > 6
    ? _amarillo
    : _verde;

Color _colorIg(double ig) => ig <= 55
    ? _verde
    : ig <= 69
    ? _amarillo
    : _rojo;

class _DatoDia extends StatelessWidget {
  const _DatoDia(this.nombre, this.valor, {this.fraccion = 0, this.color});

  final String nombre;
  final String valor;

  /// Largo de la barra (0..1).
  final double fraccion;

  /// null deja la barra vacía y gris (sin dato).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                nombre,
                style: EqText.caption.copyWith(
                  color: Colors.white70,
                  letterSpacing: 0,
                ),
              ),
            ),
            Text(
              valor,
              style: EqText.label.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: fraccion.clamp(0.0, 1.0),
            minHeight: 4,
            color: color ?? Colors.white24,
            backgroundColor: Colors.white24,
          ),
        ),
      ],
    );
  }
}

/// Calorías de la dieta contra el objetivo, sobre el fondo oscuro del resumen.
class _CaloriasResumen extends StatelessWidget {
  const _CaloriasResumen(this.n);

  final Nutriente n;

  @override
  Widget build(BuildContext context) {
    final color = colorPorcentajeOscuro(n.cuantitativo);
    final diferencia = (n.objetivo - n.cantidad).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'CALORÍAS',
              style: EqText.caption.copyWith(color: Colors.white70),
            ),
            const Spacer(),
            Text(
              '${fmtNum(n.cuantitativo)} %',
              style: EqText.label.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: EqSpace.xs),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '${n.cantidad.round()}'),
              TextSpan(
                text: ' / ${n.objetivo.round()} kcal',
                style: EqText.bodySm.copyWith(color: Colors.white70),
              ),
            ],
          ),
          style: EqText.h2.copyWith(color: Colors.white, height: 1.1),
        ),
        const SizedBox(height: EqSpace.sm),
        LinearProgressIndicator(
          value: n.objetivo <= 0
              ? 0
              : (n.cantidad / n.objetivo).clamp(0, 1).toDouble(),
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
          color: color,
          backgroundColor: Colors.white24,
        ),
        const SizedBox(height: 6),
        Text(
          diferencia >= 0
              ? 'Faltan $diferencia kcal para el objetivo'
              : 'Te pasas por ${-diferencia} kcal del objetivo',
          style: EqText.bodySm.copyWith(color: Colors.white70),
        ),
      ],
    );
  }
}
