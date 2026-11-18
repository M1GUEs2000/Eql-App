import 'package:flutter/material.dart';

import '../data/api.dart';
import '../data/models.dart';
import '../theme/eq_tokens.dart';
import 'hoja_inferior.dart';

/// Campo que muestra la dieta abierta; al tocarlo abre la hoja para elegir otra.
/// Devuelve por [onElegir] la fecha de la dieta elegida.
class CampoDieta extends StatelessWidget {
  const CampoDieta({super.key, required this.ingesta, required this.onElegir});

  final Ingesta ingesta;
  final ValueChanged<String> onElegir;

  Future<void> _abrir(BuildContext context) async {
    final fecha = await abrirHoja<String>(context, _HojaDietas(ingesta));
    if (fecha != null && fecha != ingesta.fecha) onElegir(fecha);
  }

  @override
  Widget build(BuildContext context) {
    final nombre = ingesta.vacia ? 'Sin dieta' : _nombre(ingesta.nombre);
    final forma = BorderRadius.circular(EqRadius.md);
    return Semantics(
      button: true,
      label: 'Dieta: $nombre, ${fechaVista(ingesta.fecha)}. Cambiar dieta',
      child: Material(
        color: EqColors.surface,
        borderRadius: forma,
        child: InkWell(
          borderRadius: forma,
          onTap: () => _abrir(context),
          child: Container(
            padding: const EdgeInsets.fromLTRB(EqSpace.md, 10, 12, 10),
            decoration: BoxDecoration(
              borderRadius: forma,
              border: Border.all(color: EqColors.borderLight),
            ),
            child: Row(
              children: [
                const _IconoDieta(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        style: EqText.label.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        fechaVista(ingesta.fecha),
                        style: EqText.bodySm.copyWith(fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.unfold_more, color: EqColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _nombre(String titulo) =>
    titulo.trim().isEmpty ? 'Dieta sin nombre' : titulo.trim();

class _IconoDieta extends StatelessWidget {
  const _IconoDieta({this.activo = false});

  final bool activo;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: activo
            ? EqColors.primary
            : EqColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(EqRadius.md),
      ),
      child: Icon(
        Icons.restaurant_menu,
        size: 20,
        color: activo ? Colors.white : EqColors.primary,
      ),
    );
  }
}

/// Hoja con todas las dietas guardadas. Tocar una la despliega con sus datos
/// (fecha, alimentos, kcal); el botón del pie la abre.
class _HojaDietas extends StatefulWidget {
  const _HojaDietas(this.actual);

  final Ingesta actual;

  @override
  State<_HojaDietas> createState() => _HojaDietasState();
}

class _HojaDietasState extends State<_HojaDietas> {
  late final List<DietaGuardada> _dietas = [...widget.actual.dietas]
    ..sort((a, b) => b.fecha.compareTo(a.fecha));
  late String _elegida = widget.actual.fecha;

  /// Detalle ya pedido por fecha; la actual viene de la pantalla.
  late final Map<String, Future<Ingesta>> _detalles = {
    if (!widget.actual.vacia) widget.actual.fecha: Future.value(widget.actual),
  };

  Future<Ingesta> _detalle(String fecha) => _detalles.putIfAbsent(
    fecha,
    () async =>
        Ingesta.desdeJson(await Api.get('ingesta', {'fecha': fecha}) as Json),
  );

  @override
  Widget build(BuildContext context) {
    final cambia = _elegida != widget.actual.fecha;
    return HojaInferior(
      titulo: 'Mis dietas',
      subtitulo: _dietas.length == 1
          ? '1 dieta guardada'
          : '${_dietas.length} dietas guardadas',
      pie: FilledButton.icon(
        onPressed: cambia ? () => Navigator.of(context).pop(_elegida) : null,
        icon: const Icon(Icons.check),
        label: Text(cambia ? 'Ver esta dieta' : 'Ya estás viendo esta dieta'),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.all(EqSpace.md),
        itemCount: _dietas.length,
        separatorBuilder: (_, _) => const SizedBox(height: EqSpace.sm),
        itemBuilder: (_, i) {
          final d = _dietas[i];
          final elegida = d.fecha == _elegida;
          return _TarjetaDieta(
            dieta: d,
            elegida: elegida,
            actual: d.fecha == widget.actual.fecha,
            detalle: elegida ? _detalle(d.fecha) : null,
            onTap: () => setState(() => _elegida = d.fecha),
          );
        },
      ),
    );
  }
}

class _TarjetaDieta extends StatelessWidget {
  const _TarjetaDieta({
    required this.dieta,
    required this.elegida,
    required this.actual,
    required this.detalle,
    required this.onTap,
  });

  final DietaGuardada dieta;
  final bool elegida;
  final bool actual;
  final Future<Ingesta>? detalle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final forma = BorderRadius.circular(EqRadius.lg);
    return Semantics(
      selected: elegida,
      button: true,
      child: Material(
        color: elegida
            ? EqColors.primary.withValues(alpha: 0.06)
            : EqColors.surface,
        borderRadius: forma,
        child: InkWell(
          borderRadius: forma,
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: forma,
              border: Border.all(
                color: elegida ? EqColors.primary : EqColors.borderLight,
                width: elegida ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _IconoDieta(activo: elegida),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _nombre(dieta.titulo),
                        style: EqText.label.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (actual) ...[
                      const SizedBox(width: EqSpace.sm),
                      const _Chip('Abierta'),
                    ],
                    SizedBox(
                      width: 40,
                      child: Icon(
                        elegida
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: elegida ? EqColors.primary : EqColors.textFaint,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: detalle == null
                      ? const SizedBox(width: double.infinity)
                      : _Detalle(dieta.fecha, detalle!),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: EqColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        texto,
        style: EqText.caption.copyWith(
          color: EqColors.primary,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

/// Datos de la dieta desplegada: fecha, alimentos, comidas con alimentos y kcal.
class _Detalle extends StatelessWidget {
  const _Detalle(this.fecha, this.futuro);

  final String fecha;
  final Future<Ingesta> futuro;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: FutureBuilder<Ingesta>(
        future: futuro,
        builder: (context, snap) {
          final ing = snap.data;
          final cargando = snap.connectionState != ConnectionState.done;
          String valor(String Function(Ingesta) f) =>
              ing == null ? (cargando ? '…' : '—') : f(ing);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Divider(height: 1, color: EqColors.borderFaint),
              const SizedBox(height: 12),
              _Dato(Icons.event_outlined, 'Fecha', fechaVista(fecha)),
              _Dato(
                Icons.restaurant_outlined,
                'Alimentos',
                valor(
                  (i) => i.totalItems == 1
                      ? '1 alimento'
                      : '${i.totalItems} alimentos',
                ),
              ),
              _Dato(
                Icons.schedule_outlined,
                'Comidas',
                valor((i) {
                  final n = i.comidas.where((c) => c.items.isNotEmpty).length;
                  return n == 1 ? '1 con alimentos' : '$n con alimentos';
                }),
              ),
              _Dato(
                Icons.local_fire_department_outlined,
                'Energía',
                valor((i) {
                  final o = i.objetivos;
                  return o.objKcal > 0
                      ? '${o.kcal.round()} de ${o.objKcal.round()} kcal'
                      : '${o.kcal.round()} kcal';
                }),
              ),
              if (snap.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'No se pudo cargar el detalle',
                    style: EqText.bodySm.copyWith(color: EqColors.error),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato(this.icono, this.etiqueta, this.valor);

  final IconData icono;
  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icono, size: 18, color: EqColors.textMuted),
          const SizedBox(width: EqSpace.sm),
          Text(etiqueta, style: EqText.bodySm),
          const Spacer(),
          Text(
            valor,
            style: EqText.label.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
