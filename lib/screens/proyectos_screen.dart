import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/proyecto.dart';
import '../services/api_service.dart';
import 'ProyectoFormScreen.dart';
import 'proyecto_details_screen.dart';

enum ProjFilter { todos, pendientes, vencidos, completados }

class ProyectosScreen extends StatefulWidget {
  final int rpe;
  final String nombre;
  final int departamentoId;
  final String rol; // <-- nuevo

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
  late final ApiService api =
  ApiService(actorRpe: widget.rpe, actorRol: widget.rol);

  ProjFilter _filter = ProjFilter.todos;
  String _query = '';

  late Future<List<Proyecto>> _future;
  List<Proyecto> _all = [];

  bool get isAdmin => widget.rol == 'admin';
  bool get isViewer => widget.rol == 'viewer';
  bool get canCreate => !isViewer; // viewer NO puede crear

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Proyecto>> _load() async {
    final data = isAdmin || isViewer
        ? await api.getTodosProyectos()
        : await api.getProyectosPorDepartamento(widget.departamentoId);
    setState(() => _all = data);
    return data;
  }

  void _refreshAfterPop(_) {
    setState(() => _future = _load());
  }

  bool _isVencido(Proyecto p) {
    final s = p.fechaEstudioNecesidades;
    if (s == null || s.isEmpty) return false;
    final f = DateTime.tryParse(s);
    if (f == null) return false;
    final hoy = DateTime.now();
    final fh = DateTime(f.year, f.month, f.day);
    final hh = DateTime(hoy.year, hoy.month, hoy.day);
    return hh.isAfter(fh);
  }

  bool _isVencidoSinSubir(Proyecto p) => _isVencido(p) && !p.entregaSubida;

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

  List<Proyecto> get _filtered {
    Iterable<Proyecto> list = _all;

    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((p) =>
      p.nombre.toLowerCase().contains(q) ||
          (p.departamento ?? '').toLowerCase().contains(q) ||
          (p.tipoProcedimientoNombre ?? '').toLowerCase().contains(q));
    }

    switch (_filter) {
      case ProjFilter.todos:
        break;
      case ProjFilter.pendientes:
        list = list.where((p) => !p.entregaSubida && !_isVencido(p));
        break;
      case ProjFilter.vencidos:
        list = list.where(_isVencidoSinSubir);
        break;
      case ProjFilter.completados:
        list = list.where((p) => p.entregaSubida);
        break;
    }

    final sorted = list.toList()
      ..sort((a, b) {
        final av = _isVencidoSinSubir(a) ? 0 : 1;
        final bv = _isVencidoSinSubir(b) ? 0 : 1;
        final byVenc = av.compareTo(bv);
        if (byVenc != 0) return byVenc;

        final ad = DateTime.tryParse(a.fechaEstudioNecesidades ?? '');
        final bd = DateTime.tryParse(b.fechaEstudioNecesidades ?? '');
        if (ad == null && bd == null) return 0;
        if (ad == null) return 1;
        if (bd == null) return -1;
        return ad.compareTo(bd);
      });

    return sorted;
  }

  int get _countPend => _all.where((p) => !p.entregaSubida && !_isVencido(p)).length;
  int get _countVenc => _all.where(_isVencidoSinSubir).length;
  int get _countComp => _all.where((p) => p.entregaSubida).length;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Proyectos — ${widget.nombre}'),
      ),
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
                // no pasamos rol aquí; con ocultar FAB basta
              ),
            ),
          ).then(_refreshAfterPop);
        },
        child: const Icon(Icons.add),
      )
          : null, // viewer no ve FAB
      body: FutureBuilder<List<Proyecto>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          if (_all.isEmpty) {
            return const Center(child: Text('No hay proyectos'));
          }

          final data = _filtered;

          return RefreshIndicator(
            onRefresh: _load,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Buscar por nombre, depto o procedimiento…',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _chip('Todos', _all.length, ProjFilter.todos),
                        _chip('Pendientes', _countPend, ProjFilter.pendientes),
                        _chip('Vencidos', _countVenc, ProjFilter.vencidos,
                            highlight: cs.errorContainer, onHighlight: cs.onErrorContainer),
                        _chip('Completados', _countComp, ProjFilter.completados),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  sliver: SliverList.separated(
                    itemCount: data.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      final p = data[i];
                      final vencidoSinSubir = _isVencidoSinSubir(p);

                      final cardColor = vencidoSinSubir
                          ? Colors.yellow.shade100.withOpacity(
                          Theme.of(context).brightness == Brightness.dark ? 0.2 : 1.0)
                          : Theme.of(context).colorScheme.surfaceContainerHighest;

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
                                  // el viewer no puede editar; admin/user según backend (admin o creador)
                                  canEdit: widget.rol != 'viewer',
                                  // pasa el actor para que se envíen x-rol / x-rpe
                                  actorRpe: widget.rpe,
                                  actorRol: widget.rol, // 'admin' | 'user' | 'viewer'
                                ),
                              ),
                            ).then(_refreshAfterPop);
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
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    if (vencidoSinSubir)
                                      Icon(Icons.warning_amber_rounded,
                                          color: Colors.amber.shade800),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${p.etapa ?? "—"}  ·  ${p.estado ?? "—"}',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
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
                                    if (p.departamento?.isNotEmpty == true)
                                      _pill(
                                        icon: Icons.apartment_outlined,
                                        label: p.departamento!,
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
          );
        },
      ),
    );
  }

  Widget _pill({
    required IconData icon,
    required String label,
    required BuildContext context,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: cs.onSecondaryContainer),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: cs.onSecondaryContainer,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, int count, ProjFilter me,
      {Color? highlight, Color? onHighlight}) {
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
          decoration: BoxDecoration(
            color: sel ? selFg : cs.surfaceVariant,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: sel ? selBg : cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ]),
      selected: sel,
      onSelected: (_) => setState(() => _filter = me),
      selectedColor: selBg,
      labelStyle: TextStyle(color: sel ? selFg : null),
      shape: StadiumBorder(side: BorderSide(color: cs.outlineVariant)),
    );
  }
}
