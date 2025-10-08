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
  late String? _observaciones;

  // Tipo de procedimiento
  int? _tipoProcId;
  String? _tipoProcNombre;

  // Fecha real en BD
  String? _fechaEstudioNecesidades;

  // -------- Proyección de eventos (todo local) ----------
  DateTime? _simEntregaBase;        // si es null, se usa la fecha real de BD
  bool _pacHabilitado = false;      // checkbox PAC
  bool _mostrarProyeccion = false;  // para mostrar/ocultar resultados

  // -------- Estados (00..03) y Etapa --------
  // Nivel actual de estado (0..3). Los checkboxes hij@s cambian esto.
  late int _estadoNivel;               // 0..3
  late String? _estadoNombre;          // nombre del estado actual
  late String? _etapaNombre;           // nombre de etapa (se pondrá "Diam" al completar 3)

  // Catálogo: mapeo 1,2,3 -> {id, nombre} desde BD (estados_proyectos)
  Map<int, Map<String, dynamic>> _estadosByNivel = {};

  // Entrega de especificaciones y anexos: se marca cuando nivel==3
  bool get _entregaCompletada => _estadoNivel >= 3;

  late final ApiService _api;

  @override
  void initState() {
    super.initState();

    _observaciones = widget.proyecto.observaciones;
    _tipoProcId = widget.proyecto.tipoProcedimientoId;
    _tipoProcNombre = widget.proyecto.tipoProcedimientoNombre;
    _fechaEstudioNecesidades = widget.proyecto.fechaEstudioNecesidades;

    // Estado/Etapa inicial visibles (del join que ya traes en GET /proyectos/:id)
    _estadoNombre = widget.proyecto.estado; // p.estado (join e.nombre)
    _etapaNombre  = widget.proyecto.etapa;  // p.etapa  (join t.nombre)

    // Derivar nivel 0..3 a partir del nombre del estado ("00 ...", "01 ...", ...)
    _estadoNivel = _inferNivelFromEstadoNombre(_estadoNombre) ?? 0;

    _api = ApiService(actorRpe: widget.actorRpe, actorRol: widget.actorRol);

    // Cargar catálogo de estados y tomar 01,02,03
    _loadEstados0123();
  }

  // ====== Helpers de estado/etapa ======
  int? _inferNivelFromEstadoNombre(String? name) {
    if (name == null) return null;
    final m = RegExp(r'^\s*0?([0-3])\b').firstMatch(name);
    if (m != null) return int.tryParse(m.group(1)!);
    return null;
  }

  Future<void> _loadEstados0123() async {
    try {
      final list = await _api.catGetEstados(); // [{id, nombre}, ...]
      final map = <int, Map<String, dynamic>>{};
      for (final it in list) {
        final nombre = (it['nombre'] ?? '').toString();
        final match = RegExp(r'^\s*0?([1-3])\b').firstMatch(nombre);
        if (match != null) {
          final lvl = int.parse(match.group(1)!); // 1..3
          map[lvl] = {'id': it['id'], 'nombre': nombre};
        }
      }
      if (mounted) {
        setState(() => _estadosByNivel = map);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron cargar estados: $e')),
      );
    }
  }

  Future<void> _setEstadoNivel(int targetNivel) async {
    if (targetNivel < 0 || targetNivel > 3) return;

    // 0 => opcional: podrías mapear al estado "00 ..." si lo deseas desde catálogo.
    if (targetNivel == 0) {
      // Busca un estado "00 ..." en catálogo (si lo agregas). Por ahora solo baja el nivel.
      setState(() {
        _estadoNivel = 0;
        // No cambiamos _estadoNombre si no tenemos catálogo 00.
      });
      // También podrías desmarcar entrega si lo decides:
      try { await _api.actualizarEntregaSubida(widget.proyecto.id, false); } catch (_) {}
      return;
    }

    final est = _estadosByNivel[targetNivel];
    if (est == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Catálogo de estados (01..03) no disponible.')),
      );
      return;
    }

    try {
      // 1) Actualiza estado en BD
      final resp = await _api.actualizarEstado(
        proyectoId: widget.proyecto.id,
        estadoId: est['id'] as int,
      );

      // 2) Si es nivel 3 → marcar entrega y mover etapa a "Diam"
      if (targetNivel >= 3) {
        try {
          await _api.actualizarEntregaSubida(widget.proyecto.id, true);
        } catch (_) {}
        try {
          final r2 = await _api.actualizarEtapaPorNombre(
            proyectoId: widget.proyecto.id,
            nombre: 'Diam',
          );
          setState(() {
            _etapaNombre = r2['etapa_nombre']?.toString() ?? 'Diam';
          });
        } catch (_) {
          // si no hay endpoint aún, solo actualizamos localmente
          setState(() => _etapaNombre = 'Diam');
        }
      } else {
        // Si bajó de 3 → desmarcar entrega
        try {
          await _api.actualizarEntregaSubida(widget.proyecto.id, false);
        } catch (_) {}
      }

      // 3) Refresca UI local
      setState(() {
        _estadoNivel = targetNivel;
        _estadoNombre = resp['estado_nombre']?.toString() ?? est['nombre']?.toString() ?? _estadoNombre;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Estado actualizado a ${_estadoNombre ?? '—'}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar estado: $e')),
      );
    }
  }

  void _toggleStep01(bool value) => _setEstadoNivel(value ? 1 : 0);
  void _toggleStep02(bool value) => _setEstadoNivel(value ? 2 : 1);
  void _toggleStep03(bool value) => _setEstadoNivel(value ? 3 : 2);

  // ====== Utilidades varias existentes ======
  String _fmtDdMmYy(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '—';
    return DateFormat('dd/MM/yy').format(dt);
  }

  String _fmtDdMmYyFromDate(DateTime? dt) {
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
                  IconButton(onPressed: () => Navigator.pop(ctx, false), icon: const Icon(Icons.close)),
                  const SizedBox(width: 4),
                  Text('Editar observaciones',
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
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
                  Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR'))),
                  const SizedBox(width: 12),
                  Expanded(child: FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('GUARDAR'))),
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
      await _api.actualizarObservaciones(proyectoId: widget.proyecto.id, observaciones: nuevo);
      setState(() => _observaciones = nuevo);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Observaciones actualizadas')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _mostrarHistorial() async {
    await showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _HistorialSheet(proyectoId: widget.proyecto.id, api: _api),
    );
  }

  // ====== editar fecha de entrega REAL (con historial) ======
  Future<void> _editarFechaEntrega() async {
    DateTime initial = DateTime.now();
    final curr = _fechaEstudioNecesidades;
    if (curr != null && curr.isNotEmpty) {
      final parsed = DateTime.tryParse(curr);
      if (parsed != null) initial = parsed;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Selecciona nueva fecha',
      confirmText: 'GUARDAR',
      cancelText: 'CANCELAR',
      locale: const Locale('es', 'MX'),
    );

    if (picked == null) return;

    final motivoCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar cambio de fecha'),
        content: TextField(
          controller: motivoCtrl,
          decoration: const InputDecoration(labelText: 'Motivo (opcional)', hintText: 'Breve nota del porqué del cambio'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('GUARDAR')),
        ],
      ),
    );

    if (ok != true) return;

    final iso = DateFormat('yyyy-MM-dd').format(picked);

    try {
      await _api.actualizarFechaEntrega(
        proyectoId: widget.proyecto.id,
        fechaISO: iso,
        motivo: motivoCtrl.text.trim().isEmpty ? null : motivoCtrl.text.trim(),
      );
      setState(() => _fechaEstudioNecesidades = iso);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fecha de entrega actualizada')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // ====== Proyección local (sin BD) ======
  Future<void> _pickSimFechaBase() async {
    DateTime initial = _simEntregaBase ?? (DateTime.tryParse(_fechaEstudioNecesidades ?? '') ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Entrega de especificación (simulada)',
      confirmText: 'ACEPTAR',
      cancelText: 'CANCELAR',
      locale: const Locale('es', 'MX'),
    );
    if (picked == null) return;
    setState(() {
      _simEntregaBase = picked;
      _mostrarProyeccion = true;
    });
  }

  Map<String, DateTime?> _calcProyeccion() {
    final base = _simEntregaBase ?? DateTime.tryParse(_fechaEstudioNecesidades ?? '');
    if (base == null) return {};
    final icm = base.add(const Duration(days: 30));
    final pmc = icm.add(const Duration(days: 30));
    DateTime? pac;
    if (_pacHabilitado) pac = pmc.add(const Duration(days: 30));
    final publicacion = (_pacHabilitado ? pac! : pmc).add(const Duration(days: 10));
    final firma = publicacion.add(const Duration(days: 30));
    final plazo = widget.proyecto.plazoEntregaDias ?? 0;
    final entregaFinal = firma.add(Duration(days: 1 + (plazo > 0 ? plazo : 0)));
    return {
      'icm': icm,
      'pmc': pmc,
      'pac': pac,
      'publicacion': publicacion,
      'firma': firma,
      'entrega': entregaFinal,
    };
  }

  Future<void> _mostrarHistorialFechas() async {
    await showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _HistorialFechasSheet(proyectoId: widget.proyecto.id, api: _api),
    );
  }

  Future<void> _editarTipoProcedimiento() async {
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
                  Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR'))),
                  const SizedBox(width: 12),
                  Expanded(child: FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('GUARDAR'))),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (ok == true && selId != null && selId != _tipoProcId) {
      try {
        final resultName = await _api.actualizarTipoProcedimiento(
          proyectoId: widget.proyecto.id,
          tipoProcedimientoId: selId!,
        );
        setState(() {
          _tipoProcId = selId;
          _tipoProcNombre = resultName ?? _tipoProcNombre;
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tipo de procedimiento actualizado')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = widget.proyecto;

    return Scaffold(
      appBar: AppBar(title: const Text('Detalles de la contratación')),
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
                          child: Text(
                            p.nombre,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                          ),
                        ),
                        // Aviso si venció
                        if (_fechaEstudioNecesidades != null &&
                            DateTime.tryParse(_fechaEstudioNecesidades!) != null)
                          if (DateTime.now().isAfter(DateTime.parse(_fechaEstudioNecesidades!)))
                            Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_etapaNombre ?? "—"}  ·  ${_estadoNombre ?? "—"}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _pill(context: context, icon: Icons.work_outline_rounded, label: _tipoProcNombre ?? '—'),
                        _pill(context: context, icon: Icons.category_outlined, label: _labelTipoContratacion(p.tipoContratacion)),
                        _pill(context: context, icon: Icons.event_rounded, label: 'Entrega: ${_fmtDdMmYy(_fechaEstudioNecesidades)}'),
                        _pill(context: context, icon: Icons.payments_outlined, label: _fmtMoney(p.presupuestoEstimado)),
                        if (p.departamento?.isNotEmpty == true)
                          _pill(context: context, icon: Icons.apartment_outlined, label: p.departamento!),
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
                    Text('Observaciones', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text((_observaciones?.isNotEmpty == true) ? _observaciones! : '—', style: const TextStyle(height: 1.3)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (widget.canEdit)
                          FilledButton.icon(onPressed: _editarObservaciones, icon: const Icon(Icons.edit_rounded), label: const Text('Editar')),
                        OutlinedButton.icon(onPressed: _mostrarHistorial, icon: const Icon(Icons.history_rounded), label: const Text('Historial de observaciones')),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Datos generales
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Datos generales', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    _kv('Departamento', p.departamento ?? '—'),
                    _kv('Etapa', _etapaNombre ?? '—'),
                    _kv('Estado', _estadoNombre ?? '—'),
                    if ((p as dynamic).codigoProyectoSii != null) _kv('Código SII', (p as dynamic).codigoProyectoSii ?? '—'),
                    if ((p as dynamic).centroClave != null) _kv('Centro', (p as dynamic).centroClave ?? '—'),

                    // Tipo de procedimiento (editable)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 180, child: Text('Mecanismo de contratación', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_tipoProcNombre ?? '—', maxLines: 2, overflow: TextOverflow.ellipsis)),
                          if (widget.canEditTipoProcedimiento)
                            IconButton(tooltip: 'Editar tipo de procedimiento', icon: const Icon(Icons.edit_rounded), onPressed: _editarTipoProcedimiento),
                        ],
                      ),
                    ),

                    // Entrega de especificaciones (REAL, con historial)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 180, child: Text('Entrega de especificaciones', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_fmtDdMmYy(_fechaEstudioNecesidades), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          if (widget.canEdit) IconButton(tooltip: 'Cambiar fecha de entrega', icon: const Icon(Icons.event_outlined), onPressed: _editarFechaEntrega),
                        ],
                      ),
                    ),

                    Row(
                      children: [
                        OutlinedButton.icon(onPressed: _mostrarHistorialFechas, icon: const Icon(Icons.history), label: const Text('Historial de fechas')),
                      ],
                    ),

                    if (p.numeroSolcon != null) _kv('Núm. SolCon', p.numeroSolcon!),
                    _kv('Plazo de entrega (días)', (p.plazoEntregaDias?.toString() ?? '—')),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ------------- PROYECCIÓN DE EVENTOS (local, sin BD) -------------
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Proyección de eventos', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text('Calcula la fecha de entrega aproximada.', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                    const SizedBox(height: 10),

                    // Fecha base (simulada)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 180, child: Text('Entrega de especificación (simulada)', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_fmtDdMmYyFromDate(_simEntregaBase ?? DateTime.tryParse(_fechaEstudioNecesidades ?? '')), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          IconButton(tooltip: 'Elegir fecha simulada', icon: const Icon(Icons.event), onPressed: _pickSimFechaBase),
                        ],
                      ),
                    ),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(value: _pacHabilitado, onChanged: (v) => setState(() => _pacHabilitado = v ?? false)),
                            const Text('Habilitar PAC'),
                          ],
                        ),
                        TextButton.icon(onPressed: () => setState(() => _simEntregaBase = null), icon: const Icon(Icons.restart_alt), label: const Text('Restablecer fecha')),
                        FilledButton.icon(onPressed: () => setState(() => _mostrarProyeccion = true), icon: const Icon(Icons.calculate_outlined), label: const Text('Calcular proyección')),
                      ],
                    ),

                    const SizedBox(height: 8),

                    if (_mostrarProyeccion)
                      Builder(
                        builder: (_) {
                          final m = _calcProyeccion();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Divider(height: 22),
                              _kv('Elaboración de ICM', _fmtDdMmYyFromDate(m['icm'])),
                              _kv('PMC', _fmtDdMmYyFromDate(m['pmc'])),
                              if (_pacHabilitado) _kv('Apertura de PAC', _fmtDdMmYyFromDate(m['pac'])),
                              _kv('Fecha de publicación', _fmtDdMmYyFromDate(m['publicacion'])),
                              _kv('Firma de contrato', _fmtDdMmYyFromDate(m['firma'])),
                              _kv('Fecha de entrega', _fmtDdMmYyFromDate(m['entrega'])),
                            ],
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ------------- Avance por ESTADOS (controla estados_proyectos) -------------
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Entrega de especificaciones y anexos', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),

                    // Padre (automático al completar 01, 02 y 03)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _entregaCompletada,
                      onChanged: null,
                      title: const Text('Completado (automático)'),
                      subtitle: const Text('Se marca cuando 01, 02 y 03 estén completos'),
                    ),

                    const Divider(height: 16),

                    // Hijos 01, 02, 03 (nombres desde catálogo si existen)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _estadoNivel >= 1,
                      onChanged: !widget.canEdit ? null : (v) => _toggleStep01(v ?? false),
                      title: Text(_estadosByNivel[1]?['nombre']?.toString() ?? 'Etapa/Estado 01'),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _estadoNivel >= 2,
                      onChanged: !widget.canEdit ? null : (v) => _toggleStep02(v ?? false),
                      title: Text(_estadosByNivel[2]?['nombre']?.toString() ?? 'Etapa/Estado 02'),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _estadoNivel >= 3,
                      onChanged: !widget.canEdit ? null : (v) => _toggleStep03(v ?? false),
                      title: Text(_estadosByNivel[3]?['nombre']?.toString() ?? 'Etapa/Estado 03'),
                    ),
                  ],
                ),
              ),
            ),

            // Aviso por vencimiento (si aplica)
            if (_fechaEstudioNecesidades != null &&
                DateTime.tryParse(_fechaEstudioNecesidades!) != null &&
                DateTime.now().isAfter(DateTime.parse(_fechaEstudioNecesidades!)))
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: cs.errorContainer, borderRadius: BorderRadius.circular(12)),
                  child: Text('La fecha de entrega de especificaciones ya venció.', style: TextStyle(color: cs.onErrorContainer)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // UI helpers
  Widget _pill({required BuildContext context, required IconData icon, required String label}) {
    final cs = Theme.of(context).colorScheme;
    final maxW = MediaQuery.of(context).size.width - 48;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxW),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: cs.secondaryContainer, borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: cs.onSecondaryContainer),
            const SizedBox(width: 6),
            Flexible(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: cs.onSecondaryContainer, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
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
          Expanded(child: Text(v, softWrap: true, overflow: TextOverflow.visible)),
        ],
      ),
    );
  }
}

/* -------------- Historial de Observaciones -------------- */

class _HistorialSheet extends StatelessWidget {
  final int proyectoId;
  final ApiService api;

  const _HistorialSheet({required this.proyectoId, required this.api});

  String _fmt(String iso) {
    try { final dt = DateTime.parse(iso); return DateFormat('dd/MM/yy HH:mm').format(dt); }
    catch (_) { return iso; }
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
              Text('Historial de observaciones', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: api.getHistorialObservaciones(proyectoId),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
              }
              if (snap.hasError) {
                return Padding(padding: const EdgeInsets.all(16), child: Text('Error: ${snap.error}'));
              }
              final data = snap.data ?? [];
              if (data.isEmpty) {
                return const Padding(padding: EdgeInsets.all(16), child: Text('Sin registros de historial'));
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
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            _chip(ctx, Icons.schedule, fecha),
                            if (rpe.isNotEmpty) _chip(ctx, Icons.badge_outlined, 'RPE $rpe'),
                          ]),
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

/* -------------- Historial de Fechas -------------- */

class _HistorialFechasSheet extends StatelessWidget {
  final int proyectoId;
  final ApiService api;

  const _HistorialFechasSheet({required this.proyectoId, required this.api});

  String _fmtD(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    try { final dt = DateTime.parse(iso); return DateFormat('dd/MM/yy').format(dt); }
    catch (_) { return iso; }
  }

  String _fmtDT(String iso) {
    try { final dt = DateTime.parse(iso); return DateFormat('dd/MM/yy HH:mm').format(dt); }
    catch (_) { return iso; }
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
              Text('Historial de fechas de entrega', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: api.getHistorialFechas(proyectoId),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
              }
              if (snap.hasError) {
                return Padding(padding: const EdgeInsets.all(16), child: Text('Error: ${snap.error}'));
              }
              final data = snap.data ?? [];
              if (data.isEmpty) {
                return const Padding(padding: EdgeInsets.all(16), child: Text('Sin registros de historial'));
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: data.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final it = data[i];
                  final fa = (it['fecha_anterior'] ?? '').toString();
                  final fn = (it['fecha_nueva'] ?? '').toString();
                  final rpe = (it['cambiado_por_rpe'] ?? '').toString();
                  final mot = (it['motivo'] ?? '').toString();
                  final ts  = (it['created_at'] ?? '').toString();

                  return Card(
                    elevation: 0,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            _chip(ctx, Icons.schedule, _fmtDT(ts)),
                            if (rpe.isNotEmpty) _chip(ctx, Icons.badge_outlined, 'RPE $rpe'),
                          ]),
                          const SizedBox(height: 8),
                          Text('Anterior: ${_fmtD(fa)}  →  Nueva: ${_fmtD(fn)}'),
                          if (mot.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Motivo: $mot')),
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
