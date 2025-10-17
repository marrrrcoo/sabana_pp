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

  // NUEVO: para distinguir AT / DIAM / Abastecimientos
  final int? actorDepartamentoId;

  // Si el usuario pertenece a Abastecimientos (controla edición del “tipo de procedimiento”)
  final bool canEditTipoProcedimiento;

  const ProyectoDetailsScreen({
    super.key,
    required this.proyecto,
    this.canEdit = true,
    this.actorRpe,
    this.actorRol,
    this.actorDepartamentoId, // <-- NUEVO
    this.canEditTipoProcedimiento = false,
  });

  @override
  State<ProyectoDetailsScreen> createState() => _ProyectoDetailsScreenState();
}

class _ProyectoDetailsScreenState extends State<ProyectoDetailsScreen> {
  // ====== CONFIG (pon el ID real de DIAM si quieres usarlo en UI) ======
  static const int DIAM_DEPT_ID = 9; // <-- alinea con backend
  static const int ABASTECIMIENTOS_ID = 10;

  late String? _observaciones;
  String _creadoPor(Proyecto p) {
    final nom = (p.creadoPorNombre ?? '').trim();
    if (nom.isNotEmpty) return nom;
    if (p.creadorRpe != null) return 'RPE ${p.creadorRpe}';
    return '—';
  }

  // Tipo de procedimiento
  int? _tipoProcId;
  String? _tipoProcNombre;

  // Fecha real en BD
  String? _fechaEstudioNecesidades;

  // Proyección (local)
  DateTime? _simEntregaBase;
  bool _pacHabilitado = false;
  bool _mostrarProyeccion = false;

  // Estado/Etapa visibles
  String? _estadoNombre;
  String? _etapaNombre;

  // === IDs y nombres de estados ===
  int? _estadoIdActual; // id real de estados_proyectos (1..N)
  Map<int, String> _nombresEstados = {}; // id -> nombre

  // AT y DIAM sets según presupuesto
  bool get presupuestoAlto =>
      (widget.proyecto.presupuestoEstimado ?? 0) > 15000000;
  List<int> get _techStates => const [2, 3, 4];
  List<int> get _diamStates => presupuestoAlto ? const [7, 8] : const [5, 6];
  List<int> get _orderedStates => [..._techStates, ..._diamStates];

  // Roles
  bool get isAdmin => (widget.actorRol == 'admin');
  bool get isViewer => (widget.actorRol == 'viewer');
  bool get isDiamUser => widget.actorDepartamentoId == DIAM_DEPT_ID;
  bool get isAbastUser => widget.actorDepartamentoId == ABASTECIMIENTOS_ID;
  bool get isAreaTecnicaUser => !(isDiamUser || isAbastUser) && !isAdmin;

  late final ApiService _api;

  @override
  void initState() {
    super.initState();

    _observaciones = widget.proyecto.observaciones;
    _tipoProcId = widget.proyecto.tipoProcedimientoId;
    _tipoProcNombre = widget.proyecto.tipoProcedimientoNombre;
    _fechaEstudioNecesidades = widget.proyecto.fechaEstudioNecesidades;

    _estadoNombre = widget.proyecto.estado; // del join
    _etapaNombre = widget.proyecto.etapa; // del join

    _api = ApiService(actorRpe: widget.actorRpe, actorRol: widget.actorRol);

    _cargarCatalogoEstados(); // llena nombres + detecta id actual
  }

  // ====== Estados helpers UI ======
  Future<void> _cargarCatalogoEstados() async {
    try {
      final list = await _api.catGetEstados(); // [{id,nombre},...]
      final map = <int, String>{};
      for (final it in list) {
        map[(it['id'] as num).toInt()] = it['nombre'].toString();
      }

      // intenta tomar el id real del modelo si existe
      int? idActual = (widget.proyecto as dynamic).estadoId;
      if (idActual == null) {
        final nombreActual =
        (widget.proyecto.estado ?? '').toLowerCase().trim();
        if (nombreActual.isNotEmpty) {
          final found = map.entries.firstWhere(
                (e) => e.value.toLowerCase().trim() == nombreActual,
            orElse: () => const MapEntry(-1, ''),
          );
          if (found.key != -1) idActual = found.key;
        }
      }

      setState(() {
        _nombresEstados = map;
        _estadoIdActual = idActual ?? 1; // 1 = 00...
      });
    } catch (_) {}
  }

  int _rank(int estadoId) => _orderedStates.indexOf(estadoId);
  bool _isInTech(int id) => _techStates.contains(id);
  bool _isInDiam(int id) => _diamStates.contains(id);

  Future<void> _updateEstado(int targetId) async {
    if (_estadoIdActual == null) return;
    if (isViewer) return;

    final curr = _estadoIdActual!;
    final currRank = _rank(curr);
    final nextRank = _rank(targetId);
    final retroceso =
    (nextRank != -1 && currRank != -1) ? nextRank < currRank : targetId < curr;
    final advancing = !retroceso;

    // permisos UX (backend también valida)
    if (advancing && !isAdmin) {
      final tryingTech = _isInTech(targetId);
      final tryingDiam = _isInDiam(targetId);
      final canAdvance =
          (isAreaTecnicaUser && tryingTech) || (isDiamUser && tryingDiam);
      if (!canAdvance) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No tienes permiso para avanzar a este estado')),
        );
        return;
      }
    }

    String? motivo;
    String? numeroIcm;
    String? fechaIcmISO;

    if (retroceso) {
      motivo = await _pedirMotivo();
      if (motivo == null || motivo.trim().isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('El motivo es obligatorio para retroceder')),
        );
        return;
      }
    } else {
      // AVANCE: si usuario DIAM activa el primer estado DIAM (5 ó 7), pedir ICM
      final firstDiam = _diamStates.first;
      final advancingToFirstDiam = (isDiamUser && targetId == firstDiam);
      if (advancingToFirstDiam) {
        final icm = await _pedirDatosICM();
        if (icm == null) return; // canceló
        numeroIcm = icm['numero'] as String;
        fechaIcmISO = icm['fechaISO'] as String;
      }
    }

    try {
      final resp = await _api.actualizarEstado(
        proyectoId: widget.proyecto.id,
        estadoId: targetId,
        motivo: motivo,
        numeroIcm: numeroIcm,
        fechaIcmISO: fechaIcmISO,
      );

      setState(() {
        _estadoIdActual = (resp['estado_id'] as num?)?.toInt() ?? targetId;
        _estadoNombre = (resp['estado_nombre'] ?? _estadoNombre)?.toString();
        _etapaNombre = (resp['etapa_nombre'] ?? _etapaNombre)?.toString();
      });

      if (!mounted) return;
      final shown =
          _estadoNombre ?? _nombresEstados[targetId] ?? 'Estado $targetId';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Estado actualizado a $shown')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error al actualizar estado: $e')));
    }
  }

  Future<String?> _pedirMotivo() async {
    final ctrl = TextEditingController();
    String? err;
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setS) {
          return AlertDialog(
            title: const Text('Motivo del retroceso'),
            content: TextField(
              controller: ctrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Describe por qué regresa el estado',
                errorText: err,
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: const Text('CANCELAR')),
              FilledButton(
                onPressed: () {
                  final t = ctrl.text.trim();
                  if (t.isEmpty) {
                    setS(() => err = 'Ingresa un motivo');
                    return;
                  }
                  Navigator.pop(ctx, t);
                },
                child: const Text('GUARDAR'),
              ),
            ],
          );
        });
      },
    );
  }

  Future<Map<String, String>?> _pedirDatosICM() async {
    final numCtrl = TextEditingController();
    DateTime? pickedDate;
    String? errNum;
    String? errDate;

    return showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setS) {
          Future<void> pickDate() async {
            final now = DateTime.now();
            final d = await showDatePicker(
              context: ctx,
              initialDate: now,
              firstDate: DateTime(now.year - 1, 1, 1),
              lastDate: DateTime(now.year + 2, 12, 31),
              helpText: 'Fecha de entrega de ICM',
              confirmText: 'SELECCIONAR',
              cancelText: 'CANCELAR',
              locale: const Locale('es', 'MX'),
            );
            if (d != null) setS(() => pickedDate = d);
          }

          String _fmt(DateTime? d) =>
              d == null ? 'Selecciona fecha' : DateFormat('dd/MM/yy').format(d);

          return AlertDialog(
            title: const Text('Datos de ICM'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: numCtrl,
                  decoration: InputDecoration(
                    labelText: 'No. de ICM',
                    hintText: 'Ej. ICM-12345',
                    errorText: errNum,
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: pickDate,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Fecha de entrega de ICM',
                      errorText: errDate,
                      border: const OutlineInputBorder(),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_fmt(pickedDate)),
                        const Icon(Icons.event),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: const Text('CANCELAR')),
              FilledButton(
                onPressed: () {
                  final n = numCtrl.text.trim();
                  if (n.isEmpty) {
                    setS(() => errNum = 'Ingresa el No. de ICM');
                    return;
                  }
                  if (pickedDate == null) {
                    setS(() => errDate = 'Selecciona la fecha');
                    return;
                  }
                  final iso = DateFormat('yyyy-MM-dd').format(pickedDate!);
                  Navigator.pop(ctx, {'numero': n, 'fechaISO': iso});
                },
                child: const Text('GUARDAR'),
              ),
            ],
          );
        });
      },
    );
  }

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
                  IconButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      icon: const Icon(Icons.close)),
                  const SizedBox(width: 4),
                  Text('Editar observaciones',
                      style: Theme.of(ctx)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
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
                          child: const Text('CANCELAR'))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('GUARDAR'))),
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
          proyectoId: widget.proyecto.id, observaciones: nuevo);
      setState(() => _observaciones = nuevo);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Observaciones actualizadas')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _mostrarHistorialObs() async {
    await showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) =>
          _HistorialSheet(proyectoId: widget.proyecto.id, api: _api),
    );
  }

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
    String? errorText;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return AlertDialog(
              title: const Text('Confirmar cambio de fecha'),
              content: TextField(
                controller: motivoCtrl,
                autofocus: true,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Motivo (obligatorio)',
                  hintText: 'Breve nota del porqué del cambio',
                  errorText: errorText,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('CANCELAR'),
                ),
                FilledButton(
                  onPressed: () {
                    final mot = motivoCtrl.text.trim();
                    if (mot.isEmpty) {
                      setStateDialog(() => errorText = 'Ingresa el motivo');
                      return;
                    }
                    Navigator.pop(ctx, true);
                  },
                  child: const Text('GUARDAR'),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok != true) return;

    final iso = DateFormat('yyyy-MM-dd').format(picked);
    final motivo = motivoCtrl.text.trim();

    try {
      await _api.actualizarFechaEntrega(
        proyectoId: widget.proyecto.id,
        fechaISO: iso,
        motivo: motivo,
      );
      setState(() => _fechaEstudioNecesidades = iso);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fecha de entrega actualizada')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _mostrarHistorialFechas() async {
    await showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) =>
          _HistorialFechasSheet(proyectoId: widget.proyecto.id, api: _api),
    );
  }

  Future<void> _editarTipoProcedimiento() async {
    List<dynamic> tipos = [];
    try {
      tipos = await _api.catGetTipos(); // [{id,nombre},...]
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error cargando tipos: $e')));
      return;
    }

    int? selId = _tipoProcId;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      icon: const Icon(Icons.close)),
                  const SizedBox(width: 4),
                  Text('Cambiar tipo de procedimiento',
                      style: Theme.of(ctx)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: selId,
                items: tipos
                    .map<DropdownMenuItem<int>>(
                      (t) => DropdownMenuItem<int>(
                      value: t['id'] as int,
                      child: Text(t['nombre'].toString())),
                )
                    .toList(),
                onChanged: (v) => selId = v,
                decoration:
                const InputDecoration(labelText: 'Tipo de procedimiento'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('CANCELAR'))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('GUARDAR'))),
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Tipo de procedimiento actualizado')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ====== PROYECCIÓN local ======
  Future<void> _pickSimFechaBase() async {
    DateTime initial = _simEntregaBase ??
        (DateTime.tryParse(_fechaEstudioNecesidades ?? '') ?? DateTime.now());
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
    final base = _simEntregaBase ??
        DateTime.tryParse(_fechaEstudioNecesidades ?? '');
    if (base == null) return {};
    final presupuesto = (widget.proyecto.presupuestoEstimado ?? 0).toDouble();

    final solicitudIcm = base.add(const Duration(days: 20));
    final icmValidada =
    solicitudIcm.add(Duration(days: presupuesto > 15000000 ? 90 : 30));
    DateTime? pac;
    if (_pacHabilitado) pac = icmValidada.add(const Duration(days: 30));
    final publicacion =
    icmValidada.add(Duration(days: 15 + (_pacHabilitado ? 30 : 0)));
    final firma = publicacion.add(const Duration(days: 30));
    final plazo = widget.proyecto.plazoEntregaDias ?? 0;
    final entregaFinal = firma.add(Duration(days: 1 + (plazo > 0 ? plazo : 0)));

    return {
      'solic_icm': solicitudIcm,
      'icm_validada': icmValidada,
      'pac': pac,
      'publicacion': publicacion,
      'firma': firma,
      'entrega': entregaFinal,
    };
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
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
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 18),
                          ),
                        ),
                        if (_fechaEstudioNecesidades != null &&
                            DateTime.tryParse(_fechaEstudioNecesidades!) !=
                                null)
                          if (DateTime.now()
                              .isAfter(DateTime.parse(_fechaEstudioNecesidades!)))
                            Icon(Icons.warning_amber_rounded,
                                color: Colors.amber.shade800),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_etapaNombre ?? "—"}  ·  ${_estadoNombre ?? "—"}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color:
                          Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _pill(
                            context: context,
                            icon: Icons.work_outline_rounded,
                            label: _tipoProcNombre ?? '—'),
                        _pill(
                            context: context,
                            icon: Icons.category_outlined,
                            label: _labelTipoContratacion(p.tipoContratacion)),
                        _pill(
                            context: context,
                            icon: Icons.event_rounded,
                            label:
                            'Entrega: ${_fmtDdMmYy(_fechaEstudioNecesidades)}'),
                        _pill(
                            context: context,
                            icon: Icons.payments_outlined,
                            label: _fmtMoney(p.presupuestoEstimado)),
                        if (p.departamento?.isNotEmpty == true)
                          _pill(
                              context: context,
                              icon: Icons.apartment_outlined,
                              label: p.departamento!),
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Observaciones',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(
                        (_observaciones?.isNotEmpty == true)
                            ? _observaciones!
                            : '—',
                        style: const TextStyle(height: 1.3)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (widget.canEdit)
                          FilledButton.icon(
                              onPressed: _editarObservaciones,
                              icon: const Icon(Icons.edit_rounded),
                              label: const Text('Editar')),
                        OutlinedButton.icon(
                            onPressed: _mostrarHistorialObs,
                            icon: const Icon(Icons.history_rounded),
                            label: const Text('Historial de observaciones')),
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Datos generales',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    _kv('Departamento', p.departamento ?? '—'),
                    _kv('Creado por', _creadoPor(p)),
                    _kv('Etapa', _etapaNombre ?? '—'),
                    _kv('Estado', _estadoNombre ?? '—'),
                    if ((p as dynamic).codigoProyectoSii != null)
                      _kv('Código SII', (p as dynamic).codigoProyectoSii ?? '—'),
                    if ((p as dynamic).centroClave != null)
                      _kv('Centro', (p as dynamic).centroClave ?? '—'),

                    // Tipo de procedimiento (editable)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                              width: 180,
                              child: Text('Mecanismo de contratación',
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant))),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(_tipoProcNombre ?? '—',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis)),
                          if (widget.canEditTipoProcedimiento)
                            IconButton(
                                tooltip: 'Editar tipo de procedimiento',
                                icon: const Icon(Icons.edit_rounded),
                                onPressed: _editarTipoProcedimiento),
                        ],
                      ),
                    ),

                    // Entrega de especificaciones (REAL, con historial)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                              width: 180,
                              child: Text('Entrega de especificaciones',
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant))),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(_fmtDdMmYy(_fechaEstudioNecesidades),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis)),
                          if (widget.canEdit)
                            IconButton(
                                tooltip: 'Cambiar fecha de entrega',
                                icon: const Icon(Icons.event_outlined),
                                onPressed: _editarFechaEntrega),
                        ],
                      ),
                    ),

                    Row(
                      children: [
                        OutlinedButton.icon(
                            onPressed: _mostrarHistorialFechas,
                            icon: const Icon(Icons.history),
                            label: const Text('Historial de fechas')),
                      ],
                    ),

                    if (p.numeroSolcon != null)
                      _kv('Núm. SolCon', p.numeroSolcon!),
                    _kv('Plazo de entrega (días)',
                        (p.plazoEntregaDias?.toString() ?? '—')),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // PROYECCIÓN
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Proyección de eventos',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text('Calcula la fecha de entrega aproximada.',
                        style: TextStyle(
                            color: cs.onSurfaceVariant, fontSize: 12)),
                    const SizedBox(height: 10),

                    // Fecha base (simulada)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                              width: 180,
                              child: Text(
                                  'Entrega de especificación (simulada)',
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant))),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(
                                  _fmtDdMmYyFromDate(_simEntregaBase ??
                                      DateTime.tryParse(
                                          _fechaEstudioNecesidades ?? '')),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis)),
                          IconButton(
                              tooltip: 'Elegir fecha simulada',
                              icon: const Icon(Icons.event),
                              onPressed: _pickSimFechaBase),
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
                            Checkbox(
                                value: _pacHabilitado,
                                onChanged: (v) =>
                                    setState(() => _pacHabilitado = v ?? false)),
                            const Text('Habilitar PAC'),
                          ],
                        ),
                        TextButton.icon(
                            onPressed: () =>
                                setState(() => _simEntregaBase = null),
                            icon: const Icon(Icons.restart_alt),
                            label: const Text('Restablecer fecha')),
                        FilledButton.icon(
                            onPressed: () =>
                                setState(() => _mostrarProyeccion = true),
                            icon: const Icon(Icons.calculate_outlined),
                            label: const Text('Calcular proyección')),
                      ],
                    ),

                    const SizedBox(height: 8),

                    if (_mostrarProyeccion)
                      Builder(
                        builder: (_) {
                          final m = _calcProyeccion();
                          final entregaFinal = m['entrega'];

                          // --- INICIO DE LA LÓGICA DE VALIDACIÓN (ACTUALIZADA) ---
                          bool excedeFechaFin = false;
                          if (entregaFinal != null &&
                              p.codigoProyectoAnoFin != null) {
                            final fechaFinProyecto =
                            DateTime.tryParse(p.codigoProyectoAnoFin!);
                            if (fechaFinProyecto != null) {
                              // Compara la fecha completa, ignorando la hora
                              final entregaSinHora = DateTime(entregaFinal.year,
                                  entregaFinal.month, entregaFinal.day);
                              if (entregaSinHora.isAfter(fechaFinProyecto)) {
                                excedeFechaFin = true;
                              }
                            }
                          }
                          // --- FIN DE LA LÓGICA DE VALIDACIÓN ---

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Divider(height: 22),
                              _kv('Solicitud de ICM',
                                  _fmtDdMmYyFromDate(m['solic_icm'])),
                              _kv('ICM validada',
                                  _fmtDdMmYyFromDate(m['icm_validada'])),
                              if (_pacHabilitado)
                                _kv('PAC', _fmtDdMmYyFromDate(m['pac'])),
                              _kv('Publicación',
                                  _fmtDdMmYyFromDate(m['publicacion'])),
                              _kv('Firma de contrato',
                                  _fmtDdMmYyFromDate(m['firma'])),
                              _kv(
                                'Fecha de entrega',
                                _fmtDdMmYyFromDate(entregaFinal),
                                valueColor: excedeFechaFin ? Colors.red : null,
                              ),
                            ],
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ------------- Avance por ESTADOS (IDs reales) -------------
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Avance por estados',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),

                    // Grupo Áreas Técnicas: 2,3,4
                    _estadoGroup(
                      title: 'Áreas Técnicas',
                      estados: _techStates,
                      enabledForAdvance:
                      isAdmin || isAreaTecnicaUser, // avanzar solo AT/admin
                    ),

                    const Divider(height: 22),

                    // Grupo DIAM: (5,6) ó (7,8) según presupuesto
                    _estadoGroup(
                      title: 'DIAM',
                      estados: _diamStates,
                      enabledForAdvance:
                      isAdmin || isDiamUser, // avanzar solo DIAM/admin
                    ),

                    const SizedBox(height: 6),
                    OutlinedButton.icon(
                      onPressed: _mostrarHistorialEstados,
                      icon: const Icon(Icons.history_edu_outlined),
                      label: const Text('Historial de cambios de estado'),
                    )
                  ],
                ),
              ),
            ),

            // Aviso por vencimiento (si aplica)
            if (_fechaEstudioNecesidades != null &&
                DateTime.tryParse(_fechaEstudioNecesidades!) != null &&
                DateTime.now()
                    .isAfter(DateTime.parse(_fechaEstudioNecesidades!)))
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: cs.errorContainer,
                      borderRadius: BorderRadius.circular(12)),
                  child: Text('La fecha de entrega de especificaciones ya venció.',
                      style: TextStyle(color: cs.onErrorContainer)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _mostrarHistorialEstados() async {
    await showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) =>
          _HistorialEstadosSheet(proyectoId: widget.proyecto.id, api: _api),
    );
  }

  Widget _pill(
      {required BuildContext context,
        required IconData icon,
        required String label}) {
    final cs = Theme.of(context).colorScheme;
    final maxW = MediaQuery.of(context).size.width - 48;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxW),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: cs.secondaryContainer,
            borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: cs.onSecondaryContainer),
            const SizedBox(width: 6),
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: cs.onSecondaryContainer,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  // ====== UI helpers ======
  Widget _estadoGroup({
    required String title,
    required List<int> estados,
    required bool enabledForAdvance,
  }) {
    final curr = _estadoIdActual ?? 1;
    final currIdx = _orderedStates.indexOf(curr);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(title,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
        ...estados.map((eid) {
          final idx = _orderedStates.indexOf(eid);
          final checked =
          (idx != -1 && currIdx != -1) ? idx <= currIdx : eid <= curr;

          Future<void> onChange(bool? v) async {
            if (isViewer) return;
            final val = v ?? false;

            if (val) {
              // AVANZAR hasta 'eid'
              if (!enabledForAdvance && !isAdmin) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('No tienes permiso para avanzar aquí')),
                );
                return;
              }
              await _updateEstado(eid);
            } else {
              // RETROCEDER al anterior de la secuencia global
              final all = _orderedStates;
              final pos = all.indexOf(eid);
              final target =
              (pos > 0) ? all[pos - 1] : 1; // si desmarcan el primero, vuelve a 00
              await _updateEstado(target);
            }
          }

          return CheckboxListTile(
            tristate: false,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(_nombresEstados[eid] ?? 'Estado $eid'),
            value: checked,
            onChanged: (widget.canEdit && !isViewer) ? onChange : null,
          );
        }),
      ],
    );
  }

  Widget _kv(String k, String v, {Color? valueColor}) {
    final hint = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 180, child: Text(k, style: TextStyle(color: hint))),
          const SizedBox(width: 8),
          Expanded(
              child: Text(v,
                  style: TextStyle(color: valueColor),
                  softWrap: true,
                  overflow: TextOverflow.visible)),
        ],
      ),
    );
  }
}

/* -------------- Historial de Observaciones -------------- */
/* -------------- Historial de Observaciones (con scroll y sin overflow) -------------- */
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
    final maxH =
        MediaQuery.of(context).size.height * 0.88; // alto “modal” grande

    return SafeArea(
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header fijo
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                  child: Row(
                    children: [
                      IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close)),
                      const SizedBox(width: 4),
                      Text('Historial de observaciones',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const Spacer(),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Lista scrollable
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: api.getHistorialObservaciones(proyectoId),
                    builder: (ctx, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(
                            child: Padding(
                                padding: EdgeInsets.all(24),
                                child: CircularProgressIndicator()));
                      }
                      if (snap.hasError) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text('Error: ${snap.error}'),
                        );
                      }
                      final data = snap.data ?? [];
                      if (data.isEmpty) {
                        return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('Sin registros de historial'),
                            ));
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: data.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final it = data[i];
                          final obs = (it['observacion'] ?? '').toString();
                          final rpe =
                          (it['cambiado_por_rpe'] ?? '').toString();
                          final fecha = _fmt((it['created_at'] ?? '').toString());
                          final estado =
                          (it['estado_al_crear'] ?? '').toString();
                          // también soporta sólo id, si por alguna razón no viene el nombre:
                          final estadoId =
                          (it['estado_id_al_crear'] ?? '').toString();

                          return Card(
                            elevation: 0,
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            child: Padding(
                              padding:
                              const EdgeInsets.fromLTRB(12, 10, 12, 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(spacing: 8, runSpacing: 8, children: [
                                    _chip(ctx, Icons.schedule, fecha),
                                    if (rpe.isNotEmpty)
                                      _chip(ctx, Icons.badge_outlined,
                                          'RPE $rpe'),
                                    if (estado.isNotEmpty)
                                      _chip(ctx, Icons.flag_outlined,
                                          'Estado: $estado')
                                    else if (estadoId.isNotEmpty)
                                      _chip(ctx, Icons.flag_outlined,
                                          'Estado ID: $estadoId'),
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(BuildContext ctx, IconData icon, String label) {
    final cs = Theme.of(ctx).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: cs.secondaryContainer,
          borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: cs.onSecondaryContainer),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                color: cs.onSecondaryContainer,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ]),
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
    try {
      final dt = DateTime.parse(iso);
      return DateFormat('dd/MM/yy').format(dt);
    } catch (_) {
      return iso;
    }
  }

  String _fmtDT(String iso) {
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
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close)),
              const SizedBox(width: 4),
              Text('Historial de fechas de entrega',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: api.getHistorialFechas(proyectoId),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()));
              }
              if (snap.hasError) {
                return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Error: ${snap.error}'));
              }
              final data = snap.data ?? [];
              if (data.isEmpty) {
                return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Sin registros de historial'));
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
                  final ts = (it['created_at'] ?? '').toString();

                  return Card(
                    elevation: 0,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            _chip(ctx, Icons.schedule, _fmtDT(ts)),
                            if (rpe.isNotEmpty)
                              _chip(ctx, Icons.badge_outlined, 'RPE $rpe'),
                          ]),
                          const SizedBox(height: 8),
                          Text('Anterior: ${_fmtD(fa)}  →  Nueva: ${_fmtD(fn)}'),
                          if (mot.isNotEmpty)
                            Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text('Motivo: $mot')),
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
      decoration: BoxDecoration(
          color: cs.secondaryContainer,
          borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: cs.onSecondaryContainer),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: cs.onSecondaryContainer,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/* -------------- Historial de ESTADOS -------------- */
class _HistorialEstadosSheet extends StatelessWidget {
  final int proyectoId;
  final ApiService api;

  const _HistorialEstadosSheet({required this.proyectoId, required this.api});

  String _fmtDT(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return DateFormat('dd/MM/yy HH:mm').format(dt);
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxH =
        MediaQuery.of(context).size.height * 0.85; // alto máximo del bottom sheet
    return SizedBox(
      height: maxH,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close)),
                const SizedBox(width: 4),
                Text('Historial de cambios de estado',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              // <- clave: el listado ocupa el resto y scrollea
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: api.getHistorialEstados(proyectoId),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Error: ${snap.error}'),
                    );
                  }
                  final data = snap.data ?? [];
                  if (data.isEmpty) {
                    return const Center(
                        child: Text('Sin registros de historial'));
                  }

                  return ListView.separated(
                    itemCount: data.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final it = data[i];
                      final ts = (it['created_at'] ?? '').toString();
                      final rpe = (it['cambiado_por_rpe'] ?? '').toString();
                      final ea = (it['estado_anterior'] ?? '—').toString();
                      final en = (it['estado_nuevo'] ?? '—').toString();
                      final mot = (it['motivo'] ?? '').toString();

                      return Card(
                        elevation: 0,
                        color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(spacing: 8, runSpacing: 8, children: [
                                _chip(ctx, Icons.schedule, _fmtDT(ts)),
                                if (rpe.isNotEmpty)
                                  _chip(ctx, Icons.badge_outlined, 'RPE $rpe'),
                              ]),
                              const SizedBox(height: 8),
                              Text('De: $ea'),
                              Text('A:  $en'),
                              if (mot.isNotEmpty)
                                Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text('Motivo: $mot')),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext ctx, IconData icon, String label) {
    final cs = Theme.of(ctx).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: cs.secondaryContainer,
          borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: cs.onSecondaryContainer),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                color: cs.onSecondaryContainer,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }
}