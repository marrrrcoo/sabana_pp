import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/proyecto.dart';
import '../services/api_service.dart';

class ProyectoDetailsScreen extends StatefulWidget {
  final Proyecto proyecto;
  final bool canEdit;

  // contexto del actor (para headers x-rol/x-rpe)
  final int? actorRpe;
  final String? actorRol;

  // Si el usuario pertenece a Abastecimientos (controla edición del “tipo de procedimiento”)
  final bool canEditTipoProcedimiento;

  const ProyectoDetailsScreen({
    super.key,
    required this.proyecto,
    this.canEdit = true,
    this.actorRpe,
    this.actorRol,
    this.canEditTipoProcedimiento = false,
  });

  @override
  State<ProyectoDetailsScreen> createState() => _ProyectoDetailsScreenState();
}

class _ProyectoDetailsScreenState extends State<ProyectoDetailsScreen> {
  late bool entregaSubida;
  late String? _observaciones;

  // cache local del tipo de procedimiento (para actualizar UI después de editar)
  int? _tipoProcId;
  String? _tipoProcNombre;

  late final ApiService _api;

  @override
  void initState() {
    super.initState();
    entregaSubida = widget.proyecto.entregaSubida;
    _observaciones = widget.proyecto.observaciones;
    _tipoProcId = widget.proyecto.tipoProcedimientoId;
    _tipoProcNombre = widget.proyecto.tipoProcedimientoNombre;

    _api = ApiService(actorRpe: widget.actorRpe, actorRol: widget.actorRol);
  }

  Future<void> _toggleEntrega(bool value) async {
    try {
      await _api.actualizarEntregaSubida(widget.proyecto.id, value);
      setState(() => entregaSubida = value);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar: $e')),
      );
    }
  }

  bool get _vencio {
    final s = widget.proyecto.fechaEstudioNecesidades;
    if (s == null || s.isEmpty) return false;
    final f = DateTime.tryParse(s);
    if (f == null) return false;
    final hoy = DateTime.now();
    final fh = DateTime(f.year, f.month, f.day);
    final hh = DateTime(hoy.year, hoy.month, hoy.day);
    return hh.isAfter(fh);
  }

  String _fmtDdMmYy(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '—';
    return DateFormat('dd/MM/yy').format(dt);
  }

  String _fmtMoney(num? v) {
    if (v == null) return '—';
    final f = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
    return f.format(v);
  }

  String _labelTipoContratacion(String? tc) {
    switch ((tc ?? '').toUpperCase()) {
      case 'AD':
        return 'Adquisición (AD)';
      case 'SE':
        return 'Servicio (SE)';
      case 'OP':
        return 'Obra (OP)';
      default:
        return '—';
    }
  }

  Future<void> _editarObservaciones() async {
    final ctrl = TextEditingController(text: _observaciones ?? '');
    final ok = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final viewInsets = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + viewInsets),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    icon: const Icon(Icons.close),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Editar observaciones',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: ctrl,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Observaciones',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('CANCELAR'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('GUARDAR'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (ok != true) return;

    try {
      final nuevo = ctrl.text.trim();
      await _api.actualizarObservaciones(
        proyectoId: widget.proyecto.id,
        observaciones: nuevo,
      );
      setState(() => _observaciones = nuevo);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Observaciones actualizadas')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _mostrarHistorial() async {
    await showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return _HistorialSheet(proyectoId: widget.proyecto.id, api: _api);
      },
    );
  }

  Future<void> _editarTipoProcedimiento() async {
    // Cargar catálogo
    List<dynamic> tipos = [];
    try {
      tipos = await _api.catGetTipos(); // [{id,nombre},...]
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error cargando tipos: $e')));
      return;
    }

    int? selId = _tipoProcId;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconButton(onPressed: () => Navigator.pop(ctx, false), icon: const Icon(Icons.close)),
                  const SizedBox(width: 4),
                  Text('Cambiar tipo de procedimiento',
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: selId,
                items: tipos
                    .map<DropdownMenuItem<int>>(
                      (t) => DropdownMenuItem<int>(value: t['id'] as int, child: Text(t['nombre'].toString())),
                )
                    .toList(),
                onChanged: (v) => selId = v,
                decoration: const InputDecoration(labelText: 'Tipo de procedimiento'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('CANCELAR'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('GUARDAR'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (ok != true || selId == null || selId == _tipoProcId) return;

    final confirmedId = selId!;

    try {
      final resultName = await _api.actualizarTipoProcedimiento(
        proyectoId: widget.proyecto.id,
        tipoProcedimientoId: confirmedId,
      );
      setState(() {
        _tipoProcId = confirmedId;
        _tipoProcNombre = resultName ?? _tipoProcNombre;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tipo de procedimiento actualizado')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = widget.proyecto;

    return Scaffold(
      appBar: AppBar(title: const Text('Detalles del Proyecto')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: ListView(
          children: [
            // Header
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(p.nombre, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                        ),
                        if (_vencio && !entregaSubida)
                          Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('${p.etapa ?? "—"}  ·  ${p.estado ?? "—"}',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _pill(context: context, icon: Icons.work_outline_rounded, label: _tipoProcNombre ?? '—'),
                        _pill(context: context, icon: Icons.category_outlined, label: _labelTipoContratacion(p.tipoContratacion)),
                        _pill(context: context, icon: Icons.event_rounded, label: 'Entrega: ${_fmtDdMmYy(p.fechaEstudioNecesidades)}'),
                        _pill(context: context, icon: Icons.payments_outlined, label: _fmtMoney(p.presupuestoEstimado)),
                        if (p.departamento?.isNotEmpty == true)
                          _pill(context: context, icon: Icons.apartment_outlined, label: p.departamento!),

                        // NUEVO: Centro como pill
                        _pill(
                          context: context,
                          icon: Icons.place_outlined,
                          label: p.centroClave ?? '—',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Observaciones
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Observaciones',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text((_observaciones?.isNotEmpty == true) ? _observaciones! : '—', style: const TextStyle(height: 1.3)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (widget.canEdit)
                          FilledButton.icon(
                            onPressed: _editarObservaciones,
                            icon: const Icon(Icons.edit_rounded),
                            label: const Text('Editar'),
                          ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _mostrarHistorial,
                          icon: const Icon(Icons.history_rounded),
                          label: const Text('Mostrar historial'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Datos generales (con edición de tipo de procedimiento si aplica)
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Datos generales',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),

                    _kv('Departamento', p.departamento ?? '—'),
                    _kv('Etapa', p.etapa ?? '—'),
                    _kv('Estado', p.estado ?? '—'),

                    // Código y Centro
                    _kv('Código SII', p.codigoProyectoSii ?? '—'),
                    _kv('Centro', p.centroClave ?? '—'),

                    // Línea editable: tipo de procedimiento
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 180,
                            child: Text('Tipo de procedimiento',
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_tipoProcNombre ?? '—')),
                          if (widget.canEditTipoProcedimiento)
                            IconButton(
                              tooltip: 'Editar tipo de procedimiento',
                              icon: const Icon(Icons.edit_rounded),
                              onPressed: _editarTipoProcedimiento,
                            ),
                        ],
                      ),
                    ),

                    _kv('Entrega de especificaciones', _fmtDdMmYy(p.fechaEstudioNecesidades)),
                    if (p.numeroSolcon != null) _kv('Núm. SolCon', p.numeroSolcon!),
                    _kv('Plazo de entrega (días)', (p.plazoEntregaDias?.toString() ?? '—')),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Toggle de entrega
            if (!_vencio && widget.canEdit)
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: Row(
                    children: [
                      const Expanded(child: Text('Entrega de Especificaciones y Anexos')),
                      Checkbox(value: entregaSubida, onChanged: (value) => _toggleEntrega(value!)),
                    ],
                  ),
                ),
              )
            else if (_vencio)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: cs.errorContainer, borderRadius: BorderRadius.circular(12)),
                child: Text('La fecha de entrega de especificaciones ya venció.', style: TextStyle(color: cs.onErrorContainer)),
              ),
          ],
        ),
      ),
    );
  }

  // UI helpers
  Widget _pill({required BuildContext context, required IconData icon, required String label}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: cs.secondaryContainer, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: cs.onSecondaryContainer),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: cs.onSecondaryContainer, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    final hint = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 180, child: Text(k, style: TextStyle(color: hint))),
          const SizedBox(width: 8),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }
}

/* -------------- Historial Sheet -------------- */

class _HistorialSheet extends StatelessWidget {
  final int proyectoId;
  final ApiService api;

  const _HistorialSheet({required this.proyectoId, required this.api});

  String _fmt(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return DateFormat('dd/MM/yy HH:mm').format(dt);
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              const SizedBox(width: 4),
              Text('Historial de observaciones',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: api.getHistorialObservaciones(proyectoId),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snap.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Error: ${snap.error}'),
                );
              }
              final data = snap.data ?? [];
              if (data.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Sin registros de historial'),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: data.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final it = data[i];
                  final obs = (it['observacion'] ?? '').toString();
                  final rpe = (it['cambiado_por_rpe'] ?? '').toString();
                  final fecha = _fmt((it['created_at'] ?? '').toString());

                  return Card(
                    elevation: 0,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _chip(ctx, Icons.schedule, fecha),
                              if (rpe.isNotEmpty) _chip(ctx, Icons.badge_outlined, 'RPE $rpe'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(obs.isNotEmpty ? obs : '—'),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext ctx, IconData icon, String label) {
    final cs = Theme.of(ctx).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: cs.secondaryContainer, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: cs.onSecondaryContainer),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: cs.onSecondaryContainer, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
