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

/// Dónde quedan los cambios del ajuste automático.
enum _Destino { sobrescribir, fechaNueva, cancelar }

/// Pestaña "Mis dietas": la ingesta de una fecha (GET ingesta) por tiempos de comida.
class VerDietaScreen extends StatefulWidget {
  const VerDietaScreen({super.key});

  @override
  State<VerDietaScreen> createState() => _VerDietaScreenState();
}

class _VerDietaScreenState extends State<VerDietaScreen> {
  Ingesta? _ingesta;
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
          await Api.get('ingesta', {'fecha': _masReciente(ingesta.dietas)})
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
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.detalle);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  /// La dieta guardada más cercana a hoy sin pasarse; si todas son futuras, la primera.
  static String _masReciente(List<DietaGuardada> dietas) {
    final hoy = fechaApi(DateTime.now());
    final pasadas = [
      for (final d in dietas)
        if (d.fecha.compareTo(hoy) <= 0) d.fecha,
    ]..sort();
    return pasadas.isEmpty ? dietas.first.fecha : pasadas.last;
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

  Future<void> _verAnalisis() async {
    final ingesta = _ingesta!;
    setState(() => _ocupado = true);
    try {
      final datos = await Api.get('analisis', {
        'fecha': ingesta.fecha,
        'tipo': 'DIA-COMPLETO',
      }) as Json;
      if (!mounted) return;
      final nombre = ingesta.nombre.isEmpty
          ? fechaVista(ingesta.fecha)
          : ingesta.nombre;
      await verAnalisis(
        context,
        nombre,
        AnalisisNutricional.desdeJson(datos),
        objetivos: ingesta.objetivos,
      );
    } on ApiError catch (e) {
      if (mounted) mostrarMensaje(context, e.detalle);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  /// Muestra cuánto mejora la dieta y pregunta dónde guardar los cambios.
  Future<_Destino> _elegirDestino(Json r, int pasos) async {
    final antes = numero(r['porcentajeKgInicial']);
    final despues = numero(r['porcentajeKgFinal']);
    final destino = await showDialog<_Destino>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Optimización lista'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cumplimiento de tus objetivos',
              style: EqText.caption.copyWith(letterSpacing: 0),
            ),
            const SizedBox(height: EqSpace.xs),
            Text(
              '${fmtNum(antes, 1)} %  →  ${fmtNum(despues, 1)} %',
              style: EqText.h3.copyWith(color: EqColors.acento),
            ),
            const SizedBox(height: 12),
            Text(
              'Equilibra encontró $pasos ${pasos == 1 ? 'cambio' : 'cambios'}. '
              '¿Quieres sobrescribir esta dieta o guardarla en una fecha nueva?',
              style: EqText.bodySm,
            ),
            const SizedBox(height: EqSpace.lg),
            FilledButton(
              onPressed: () => Navigator.pop(context, _Destino.sobrescribir),
              child: const Text('Sobrescribir esta dieta'),
            ),
            const SizedBox(height: EqSpace.sm),
            OutlinedButton(
              onPressed: () => Navigator.pop(context, _Destino.fechaNueva),
              child: const Text('Guardar en una fecha nueva'),
            ),
            const SizedBox(height: EqSpace.xs),
            TextButton(
              onPressed: () => Navigator.pop(context, _Destino.cancelar),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
    return destino ?? _Destino.cancelar;
  }

  /// Crea la dieta ajustada en otra fecha y deja la original como estaba.
  Future<void> _guardarEnFechaNueva(String fecha, bool intercambio) async {
    final ingesta = _ingesta!;
    final dia = await elegirFechaLibre(
      context,
      ocupadas: ingesta.dietas.map((d) => d.fecha),
      inicial: DateTime.now().add(const Duration(days: 1)),
    );
    if (!mounted) return;
    if (dia == null) {
      // Cerró el calendario sin elegir: vuelve a las opciones.
      return _decidirAjuste(fecha, intercambio, null);
    }
    final nueva = fechaApi(dia);
    final base = ingesta.nombre.trim().isEmpty ? 'Dieta' : ingesta.nombre.trim();
    final nombre = '$base ajustada';
    await Api.post('ajuste/dieta-ajustada', {
      'fechaOriginal': fecha,
      'nuevaFecha': nueva,
      'nombre': nombre.length > 120 ? nombre.substring(0, 120) : nombre,
      'permitirIntercambio': intercambio,
    });
    if (!mounted) return;
    await esperarAjuste(context, tipo: TipoAjuste.dietaAjustada, fecha: fecha);
    // La original no cambia: se sueltan los cambios que quedaron pendientes.
    await Api.post('ajuste/guiado/descartar', {'fecha': fecha});
    if (!mounted) return;
    mostrarMensaje(context, 'Dieta guardada el ${fechaVista(nueva)}');
    Cambios.avisar(fechaIngesta: nueva);
  }

  Json? _ultimoAjuste;

  Future<void> _decidirAjuste(
    String fecha,
    bool intercambio,
    Json? resultado,
  ) async {
    final r = resultado ?? _ultimoAjuste!;
    _ultimoAjuste = r;
    final pasos = ((r['cantidadCambiosPendientes'] as num?) ?? 0).toInt();
    final destino = await _elegirDestino(r, pasos);
    if (!mounted) return;
    switch (destino) {
      case _Destino.sobrescribir:
        setState(() => _ocupado = true);
        try {
          await Api.post('ajuste/guiado', {
            'fecha': fecha,
            'decision': 'APLICAR_CAMBIOS',
          });
        } finally {
          if (mounted) setState(() => _ocupado = false);
        }
        if (!mounted) return;
        mostrarMensaje(context, 'Dieta actualizada');
        Cambios.avisar(fechaIngesta: fecha);
      case _Destino.fechaNueva:
        await _guardarEnFechaNueva(fecha, intercambio);
      case _Destino.cancelar:
        await Api.post('ajuste/guiado/descartar', {'fecha': fecha});
        if (mounted) mostrarMensaje(context, 'Tu dieta quedó como estaba');
    }
  }

  Future<void> _optimizar() async {
    var intercambio = false;
    final si = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogo) => AlertDialog(
          title: const Text('Optimizar dieta'),
          content: Column(
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
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Optimizar'),
            ),
          ],
        ),
      ),
    );
    if (si != true || !mounted) return;
    final fecha = _ingesta!.fecha;
    try {
      await Api.post('ajuste/automatico', {
        'fecha': fecha,
        'permitirIntercambio': intercambio,
        'origen': 'app-movil',
      });
      if (!mounted) return;
      final resultado = await esperarAjuste(
        context,
        tipo: TipoAjuste.automatico,
        fecha: fecha,
      );
      if (!mounted) return;
      if (resultado == null) {
        mostrarMensaje(context, 'Optimización cancelada');
        return;
      }
      // El ajuste deja los cambios pendientes: la dieta solo cambia al aplicarlos.
      final pendientes = (resultado['cantidadCambiosPendientes'] as num?) ?? 0;
      if (pendientes <= 0) {
        mostrarMensaje(
          context,
          (resultado['mensaje'] as String?) ??
              'Tu dieta ya está lo más cerca posible de tus objetivos.',
        );
        return;
      }
      await _decidirAjuste(fecha, intercambio, resultado);
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
            objetivos: ingesta.objetivos,
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
  const _Resumen({required this.objetivos, required this.onVerMas});

  final ObjetivosDia objetivos;
  final VoidCallback? onVerMas;

  @override
  Widget build(BuildContext context) {
    final o = objetivos;
    return EqHero(
      onTap: onVerMas,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CALORÍAS DEL DÍA',
            style: EqText.caption.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: EqSpace.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${o.kcal.round()}',
                style: EqText.h1.copyWith(color: Colors.white),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 6),
                child: Text(
                  o.tieneObjetivo ? 'de ${o.objKcal.round()} kcal' : 'kcal',
                  style: EqText.body.copyWith(color: EqColors.primarySoft),
                ),
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
                    Text('Análisis'),
                    Icon(Icons.chevron_right, size: 18),
                  ],
                ),
              ),
            ],
          ),
          if (o.tieneObjetivo) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: o.avance.clamp(0, 1).toDouble(),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
              color: EqColors.primarySoft,
              backgroundColor: Colors.white24,
            ),
          ],
          const SizedBox(height: EqSpace.sm),
          Text(
            [
              _macro('Prot.', o.proteinas, o.objProteinas, o.tieneObjetivo),
              _macro(
                'Carb.',
                o.carbohidratos,
                o.objCarbohidratos,
                o.tieneObjetivo,
              ),
              _macro('Grasa', o.grasa, o.objGrasa, o.tieneObjetivo),
            ].join('  ·  '),
            style: EqText.bodySm.copyWith(color: Colors.white70),
          ),
          if (!o.tieneObjetivo)
            Text(
              'Sin objetivo: guarda tu evaluación nutricional para comparar.',
              style: EqText.caption.copyWith(
                color: Colors.white60,
                letterSpacing: 0,
              ),
            ),
        ],
      ),
    );
  }

  static String _macro(
    String nombre,
    double valor,
    double objetivo,
    bool conObjetivo,
  ) => conObjetivo
      ? '$nombre ${valor.round()}/${objetivo.round()} g'
      : '$nombre ${valor.round()} g';
}
