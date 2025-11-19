// screens/proyectos_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/proyecto.dart';
import '../services/api_service.dart';
import 'ProyectoFormScreen.dart';
import 'proyecto_details_screen.dart';

enum ProjFilter { todos, pendientes, porVencer, vencidos, completados }

const int ABASTECIMIENTOS_ID = 10;
// TODO: Ajusta este ID al real del departamento DIAM en tu BD
const int DIAM_DEPT_ID = 9;

class ProyectosScreen extends StatefulWidget {
  final int rpe;
  final String nombre;
  final int departamentoId;
  final String rol;

  const ProyectosScreen({
    super.key,
    required this.rpe,
    required this.nombre,
    required this.departamentoId,
    required this.rol,
  });

  @override
  State<ProyectosScreen> createState() => _ProyectosScreenState();
}

class _ProyectosScreenState extends State<ProyectosScreen> {
  late final ApiService api = ApiService(actorRpe: widget.rpe, actorRol: widget.rol);

  // filtros/client
  ProjFilter _filter = ProjFilter.todos;
  String _query = '';
  String? _estadoSel;
  String? _centroSel;

  // NUEVO (DIAM): único chip "Previo"
  bool _filterPrevio = false;

  // data + paginación
  final _scroll = ScrollController();
  final List<Proyecto> _items = [];
  bool _loadingFirst = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  int _pageSize = 20; // selector 10/20

  // Envíos en curso por proyecto (para deshabilitar botón individual)
  final Set<int> _sendingIds = <int>{};

  bool get isAdmin => widget.rol == 'admin';
  bool get isViewer => widget.rol == 'viewer';
  bool get isDiamUser => widget.departamentoId == DIAM_DEPT_ID;
  bool get isAbastUser => widget.departamentoId == ABASTECIMIENTOS_ID;
  bool get canCreate => !isViewer && !isDiamUser && !isAbastUser;
  bool get canEditTipoProcedimiento =>
      isAdmin || widget.departamentoId == ABASTECIMIENTOS_ID;

  // Requisito: admins y viewers pueden enviar el correo
  bool get _canNotifyRole => isAdmin || isViewer;

  @override
  void initState() {
    super.initState();
    _loadFirstPage();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _loadingFirst = true;
      _items.clear();
      _page = 1;
      _hasMore = true;
    });
    try {
      final pageData = await _fetchPage(_page);
      setState(() {
        _items.addAll(pageData);
        _loadingFirst = false;
        _hasMore = pageData.length == _pageSize;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingFirst = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<List<Proyecto>> _fetchPage(int page) {
    // MODIFICADO: DIAM y Abastecimientos ven solo proyectos de su etapa
    if (isAdmin || isViewer) {
      return api.getTodosProyectosPaged(page: page, limit: _pageSize, order: 'vencimiento');
    } else if (isDiamUser) {
      return api.getProyectosPorEtapaPaged(etapa: 'DIAM', page: page, limit: _pageSize, order: 'vencimiento');
    } else if (isAbastUser) {
      return api.getProyectosPorEtapaPaged(etapa: 'Abastecimientos', page: page, limit: _pageSize, order: 'vencimiento');
    } else {
      return api.getProyectosPorDepartamentoPaged(
        widget.departamentoId, page: page, limit: _pageSize, order: 'vencimiento',
      );
    }
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loadingFirst) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final next = _page + 1;
      final pageData = await _fetchPage(next);
      setState(() {
        _page = next;
        _items.addAll(pageData);
        _hasMore = pageData.length == _pageSize;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _refresh() => _loadFirstPage();

  // ============ Helpers de fechas y estados ============
  DateTime _asYMD(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _isVencido(Proyecto p) {
    final s = p.fechaEstudioNecesidades;
    if (s == null || s.isEmpty) return false;
    final f = DateTime.tryParse(s);
    if (f == null) return false;
    final hoy = _asYMD(DateTime.now());
    final fh = _asYMD(f);
    return hoy.isAfter(fh);
  }

  bool _isVencidoSinSubir(Proyecto p) => _isVencido(p) && !p.entregaSubida;

  // Días (enteros) de hoy hasta la fecha de estudio; negativo si ya venció
  int? _daysUntil(Proyecto p) {
    final s = p.fechaEstudioNecesidades;
    if (s == null || s.isEmpty) return null;
    final f = DateTime.tryParse(s);
    if (f == null) return null;
    final hoy = _asYMD(DateTime.now());
    final fh = _asYMD(f);
    return fh.difference(hoy).inDays;
  }

  // NUEVO: regla "Por vencer" (0 a 3 días, no entregado y no vencido)
  bool _isPorVencer(Proyecto p) {
    if (p.entregaSubida) return false;
    final d = _daysUntil(p);
    if (d == null) return false;
    return d >= 0 && d <= 3;
  }

  // NUEVO: helper para leer fecha_icm (acepta camel o snake case)
  String? _fechaIcmOf(Proyecto p) {
    try {
      final d = p as dynamic;
      final raw = d.fechaIcm ?? d.fecha_icm;
      return raw?.toString();
    } catch (_) {
      return null;
    }
  }

  // NUEVO: regla "Previo" (fecha_icm nula/vacía)
  bool _isPrevio(Proyecto p) {
    final v = _fechaIcmOf(p);
    return v == null || v.trim().isEmpty;
  }

  String _fmtDate(String? iso) {
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

  String? _centroClaveOf(Proyecto p) {
    try {
      final d = p as dynamic;
      final raw = d.centroClave ?? d.centro_clave;
      return raw?.toString();
    } catch (_) {
      return null;
    }
  }

  // opciones para dropdowns (de lo cargado)
  List<String> get _estadosDisponibles {
    final s = _items
        .map((p) => (p.estado ?? '').trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return s;
  }

  List<String> get _centrosDisponibles {
    final s = _items
        .map((p) => (_centroClaveOf(p) ?? '').trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return s;
  }

  // Orden: no completados con fecha más cercana (o vencidos) primero; completos al final
  int _score(Proyecto p) {
    if (p.entregaSubida) return 1000000000; // completados al final
    final iso = p.fechaEstudioNecesidades;
    if (iso == null || iso.isEmpty) return 500000000; // sin fecha: cerca del final (pero antes de completos)
    final dt = DateTime.tryParse(iso);
    if (dt == null) return 500000000;
    final days = _asYMD(dt).difference(_asYMD(DateTime.now())).inDays; // negativo = vencido
    // más pequeño => antes (vencidos muy negativos primero, luego próximos a vencer)
    return days;
  }

  List<Proyecto> get _filtered {
    Iterable<Proyecto> list = _items;

    // búsqueda libre
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((p) {
        final centro = (_centroClaveOf(p) ?? '').toLowerCase();
        return p.nombre.toLowerCase().contains(q) ||
            (p.departamento ?? '').toLowerCase().contains(q) ||
            (p.tipoProcedimientoNombre ?? '').toLowerCase().contains(q) ||
            (p.estado ?? '').toLowerCase().contains(q) ||
            centro.contains(q) ||
            (p.creadoPorNombre ?? '').toLowerCase().contains(q);
      });
    }

    // chips globales:
    // - si es DIAM: solo usamos el chip "Previo" (fecha_icm NULL)
    // - si NO es DIAM: usamos chips normales + "Por vencer"
    if (isDiamUser) {
      if (_filterPrevio) {
        list = list.where(_isPrevio);
      }
    } else {
      switch (_filter) {
        case ProjFilter.todos:
          break;
        case ProjFilter.pendientes:
          list = list.where((p) => !p.entregaSubida && !_isVencido(p));
          break;
        case ProjFilter.porVencer:
          list = list.where(_isPorVencer);
          break;
        case ProjFilter.vencidos:
          list = list.where(_isVencidoSinSubir);
          break;
        case ProjFilter.completados:
          list = list.where((p) => p.entregaSubida);
          break;
      }
    }

    // dropdown de estado
    if (_estadoSel != null && _estadoSel!.isNotEmpty) {
      final sel = _estadoSel!.toLowerCase();
      list = list.where((p) => (p.estado ?? '').toLowerCase() == sel);
    }

    // dropdown de centro
    if (_centroSel != null && _centroSel!.isNotEmpty) {
      final sel = _centroSel!.toLowerCase();
      list = list.where((p) => (_centroClaveOf(p) ?? '').toLowerCase() == sel);
    }

    final sorted = list.toList()..sort((a, b) => _score(a).compareTo(_score(b)));
    return sorted;
  }

  int get _countPend => _items.where((p) => !p.entregaSubida && !_isVencido(p)).length;
  int get _countPorVenc => _items.where(_isPorVencer).length; // NUEVO
  int get _countVenc => _items.where(_isVencidoSinSubir).length;
  int get _countComp => _items.where((p) => p.entregaSubida).length;

  // NUEVO: contador para el chip "Previo" (DIAM)
  int get _countPrevio => _items.where(_isPrevio).length;

  // ====================== Notificación por vencimiento ======================
  Future<void> _confirmAndSendAviso(Proyecto p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enviar aviso por vencimiento'),
        content: Text(
          'Se enviará un correo al creador del proyecto:\n\n'
              '• ${p.nombre}\n'
              '• Entrega comprometida: ${_fmtDate(p.fechaEstudioNecesidades)}\n\n'
              '¿Deseas continuar?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCELAR')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ENVIAR')),
        ],
      ),
    );

    if (ok != true) return;
    await _sendAviso(p.id);
  }

  Future<void> _sendAviso(int proyectoId) async {
    if (_sendingIds.contains(proyectoId)) return;
    setState(() => _sendingIds.add(proyectoId));
    try {
      await api.notificarVencimiento(proyectoId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Correo de aviso enviado')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al enviar aviso: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _sendingIds.remove(proyectoId));
      }
    }
  }
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      floatingActionButton: canCreate
          ? FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProyectoFormScreen(
                rpe: widget.rpe,
                nombre: widget.nombre,
                rol: widget.rol,
                departamentoId: widget.departamentoId,
              ),
            ),
          ).then((_) => _refresh());
        },
        child: const Icon(Icons.add),
      )
          : null,
      body: _loadingFirst
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          controller: _scroll,
          slivers: [
            // Buscador + selector page size
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText:
                          'Buscar por nombre, depto, procedimiento, estado, centro o creador…',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onChanged: (v) => setState(() => _query = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<int>(
                      value: _pageSize,
                      items: const [
                        DropdownMenuItem(value: 10, child: Text('10')),
                        DropdownMenuItem(value: 20, child: Text('20')),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _pageSize = v);
                        _loadFirstPage();
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Chips resumen + dropdown-chips
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (isDiamUser) ...[
                      // ÚNICO chip para DIAM: "Previo"
                      _chipPrevio('Previo', _countPrevio),
                    ]else if (isAbastUser) ...[
                      // Para Abastecimientos, mostramos chips normales (como áreas técnicas)
                      _chip('Todos', _items.length, ProjFilter.todos),
                      _chip('Pendientes', _countPend, ProjFilter.pendientes),
                      _chip('Por vencer', _countPorVenc, ProjFilter.porVencer),
                      _chip('Vencidos', _countVenc, ProjFilter.vencidos,
                          highlight: cs.errorContainer, onHighlight: cs.onErrorContainer),
                      _chip('Completados', _countComp, ProjFilter.completados),
                    ] else ...[
                      _chip('Todos', _items.length, ProjFilter.todos),
                      _chip('Pendientes', _countPend, ProjFilter.pendientes),
                      _chip('Por vencer', _countPorVenc, ProjFilter.porVencer), // NUEVO
                      _chip('Vencidos', _countVenc, ProjFilter.vencidos,
                          highlight: cs.errorContainer, onHighlight: cs.onErrorContainer),
                      _chip('Completados', _countComp, ProjFilter.completados),
                    ],
                    _menuChip(
                      context: context,
                      icon: Icons.flag_outlined,
                      title: 'Estado',
                      value: _estadoSel,
                      options: _estadosDisponibles,
                      onChanged: (v) => setState(() => _estadoSel = v),
                    ),
                    _menuChip(
                      context: context,
                      icon: Icons.domain_outlined,
                      title: 'Centro',
                      value: _centroSel,
                      options: _centrosDisponibles,
                      onChanged: (v) => setState(() => _centroSel = v),
                    ),
                  ],
                ),
              ),
            ),

            // Lista
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              sliver: SliverList.separated(
                itemCount: _filtered.length + (_loadingMore ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  if (_loadingMore && i == _filtered.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final p = _filtered[i];
                  final vencidoSinSubir = _isVencidoSinSubir(p);
                  final cardColor = vencidoSinSubir
                      ? Colors.yellow.shade100.withOpacity(
                      Theme.of(context).brightness == Brightness.dark ? 0.2 : 1.0)
                      : Theme.of(context).colorScheme.surfaceContainerHighest;

                  final centroClave = _centroClaveOf(p);
                  final sending = _sendingIds.contains(p.id);

                  // Mostrar botón sólo si cumple regla y el rol puede notificar
                  final showNotifyBtn = vencidoSinSubir && _canNotifyRole;

                  return Card(
                    elevation: 0,
                    color: cardColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: vencidoSinSubir ? Colors.amber.shade700 : Colors.transparent,
                        width: vencidoSinSubir ? 1.2 : 0.0,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProyectoDetailsScreen(
                              proyecto: p,
                              canEdit: widget.rol != 'viewer',
                              actorRpe: widget.rpe,
                              actorRol: widget.rol,
                              canEditTipoProcedimiento: canEditTipoProcedimiento,
                              actorDepartamentoId: widget.departamentoId,
                            ),
                          ),
                        ).then((_) => _refresh());
                      },
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    p.nombre,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                  ),
                                ),
                                if (vencidoSinSubir)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800),
                                  ),
                                if (showNotifyBtn)
                                  Tooltip(
                                    message: 'Enviar aviso por vencimiento',
                                    child: SizedBox(
                                      height: 36,
                                      child: FilledButton.tonalIcon(
                                        onPressed: sending ? null : () => _confirmAndSendAviso(p),
                                        icon: sending
                                            ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                            : const Icon(Icons.email_outlined, size: 18),
                                        label: const Text('Aviso'),
                                        style: FilledButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 10),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${p.etapa ?? "—"}',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _pill(
                                  icon: Icons.work_outline_rounded,
                                  label: p.tipoProcedimientoNombre ?? '—',
                                  context: context,
                                ),
                                // Para DIAM: mostrar fecha ICM o "no fecha ICM"
                                if (isDiamUser)
                                  _pill(
                                    icon: Icons.event_rounded,
                                    label:
                                    'ICM: ${_fechaIcmOf(p) == null || _fechaIcmOf(p)!.isEmpty ? "no fecha ICM" : _fmtDate(_fechaIcmOf(p))}',
                                    context: context,
                                  )
                                else
                                  _pill(
                                    icon: Icons.event_rounded,
                                    label: 'Entrega: ${_fmtDate(p.fechaEstudioNecesidades)}',
                                    context: context,
                                  ),

                                _pill(
                                  icon: Icons.payments_outlined,
                                  label: _fmtMoney(p.presupuestoEstimado),
                                  context: context,
                                ),
                                _pill(
                                  icon: Icons.flag_outlined,
                                  label: p.estado ?? '—',
                                  context: context,
                                ),
                                if (centroClave != null && centroClave.isNotEmpty)
                                  _pill(
                                    icon: Icons.domain_outlined,
                                    label: centroClave,
                                    context: context,
                                  ),
                                if (p.departamento?.isNotEmpty == true)
                                  _pill(
                                    icon: Icons.apartment_outlined,
                                    label: p.departamento!,
                                    context: context,
                                  ),
                                if ((p.creadoPorNombre ?? '').isNotEmpty)
                                  _pill(
                                    icon: Icons.person_outline,
                                    label: 'Creado por ${p.creadoPorNombre}',
                                    context: context,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }

  // ---------- UI helpers ----------
  Widget _menuChip({
    required BuildContext context,
    required IconData icon,
    required String title,
    required List<String> options,
    required String? value,
    required ValueChanged<String?> onChanged,
  }) {
    final cs = Theme.of(context).colorScheme;
    return PopupMenuButton<String>(
      tooltip: 'Filtrar por $title',
      onSelected: (val) => onChanged(val == '__ALL__' ? null : val),
      itemBuilder: (ctx) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(value: '__ALL__', child: Text('Todos')),
        ...options.map((o) => PopupMenuItem<String>(
          value: o,
          child: Row(children: [
            if (value == o) ...[const Icon(Icons.check, size: 18), const SizedBox(width: 6)],
            Expanded(child: Text(o)),
          ]),
        )),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: cs.secondaryContainer, borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: cs.onSecondaryContainer),
          const SizedBox(width: 6),
          Text(value ?? title, style: TextStyle(color: cs.onSecondaryContainer, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(width: 2),
          Icon(Icons.keyboard_arrow_down, size: 16, color: cs.onSecondaryContainer),
        ]),
      ),
    );
  }

  Widget _pill({required IconData icon, required String label, required BuildContext context}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: cs.secondaryContainer, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: cs.onSecondaryContainer),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: cs.onSecondaryContainer, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _chip(String text, int count, ProjFilter me, {Color? highlight, Color? onHighlight}) {
    final sel = _filter == me;
    final cs = Theme.of(context).colorScheme;
    final selBg = highlight ?? cs.primary;
    final selFg = onHighlight ?? cs.onPrimary;
    return ChoiceChip(
      label: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(text),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: sel ? selFg : cs.surfaceVariant, borderRadius: BorderRadius.circular(999)),
          child: Text('$count', style: TextStyle(color: sel ? selBg : cs.onSurfaceVariant, fontWeight: FontWeight.w700, fontSize: 12)),
        ),
      ]),
      selected: sel,
      onSelected: (_) => setState(() => _filter = me),
      selectedColor: selBg,
      labelStyle: TextStyle(color: sel ? selFg : null),
      shape: StadiumBorder(side: BorderSide(color: cs.outlineVariant)),
    );
  }

  // NUEVO: chip "Previo" (solo DIAM)
  Widget _chipPrevio(String text, int count) {
    final cs = Theme.of(context).colorScheme;
    final sel = _filterPrevio;
    final selBg = cs.primary;
    final selFg = cs.onPrimary;
    return ChoiceChip(
      label: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(text),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: sel ? selFg : cs.surfaceVariant, borderRadius: BorderRadius.circular(999)),
          child: Text('$count',
              style: TextStyle(color: sel ? selBg : cs.onSurfaceVariant, fontWeight: FontWeight.w700, fontSize: 12)),
        ),
      ]),
      selected: sel,
      onSelected: (_) => setState(() => _filterPrevio = !_filterPrevio),
      selectedColor: selBg,
      labelStyle: TextStyle(color: sel ? selFg : null),
      shape: StadiumBorder(side: BorderSide(color: cs.outlineVariant)),
    );
  }
}
