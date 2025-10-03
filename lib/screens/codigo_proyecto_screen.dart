import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class CodigoProyectoScreen extends StatefulWidget {
  const CodigoProyectoScreen({super.key});

  @override
  State<CodigoProyectoScreen> createState() => _CodigoProyectoScreenState();
}

class _CodigoProyectoScreenState extends State<CodigoProyectoScreen> {
  final _baseUrl = 'http://10.0.2.2:3000';
  late Future<List<Map<String, dynamic>>> _future;
  List<Map<String, dynamic>> _all = [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final resp = await http.get(Uri.parse('$_baseUrl/codigo_proyecto'));
    if (resp.statusCode != 200) {
      throw Exception('Error al obtener los códigos (${resp.statusCode})');
    }
    final list = (jsonDecode(resp.body) as List).cast<Map<String, dynamic>>();
    setState(() => _all = list);
    return list;
    // Espera estructura: [{id, codigo_proyecto_sii, ano, fecha_creacion?}, ...]
  }

  List<Map<String, dynamic>> get _filtered {
    if (_query.isEmpty) return _all;
    final q = _query.toLowerCase();
    return _all.where((e) {
      final code = (e['codigo_proyecto_sii'] ?? '').toString().toLowerCase();
      final year = (e['ano'] ?? '').toString().toLowerCase();
      return code.contains(q) || year.contains(q);
    }).toList();
  }

  String _fmtDate(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '—';
    return DateFormat('dd/MM/yy HH:mm').format(dt);
  }

  Future<void> _createOrEdit({Map<String, dynamic>? initial}) async {
    final codeCtrl = TextEditingController(text: initial?['codigo_proyecto_sii']?.toString() ?? '');
    final yearCtrl = TextEditingController(text: initial?['ano']?.toString() ?? '');
    final isEdit = initial != null;

    final cs = Theme.of(context).colorScheme;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  isEdit ? 'Editar código' : 'Nuevo código',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: codeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Código de proyecto SII',
                  prefixIcon: Icon(Icons.tag),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: yearCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Año',
                  prefixIcon: Icon(Icons.calendar_today),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        final code = codeCtrl.text.trim();
                        final year = int.tryParse(yearCtrl.text.trim());
                        if (code.isEmpty || year == null) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Completa código y año válidos')),
                          );
                          return;
                        }

                        try {
                          if (isEdit) {
                            final id = initial!['id'];
                            final resp = await http.put(
                              Uri.parse('$_baseUrl/codigo_proyecto/$id'),
                              headers: {'Content-Type': 'application/json'},
                              body: jsonEncode({
                                'codigo_proyecto_sii': code,
                                'ano': year,
                              }),
                            );
                            if (resp.statusCode != 200) {
                              throw Exception('Error al editar (${resp.statusCode})');
                            }
                          } else {
                            final resp = await http.post(
                              Uri.parse('$_baseUrl/codigo_proyecto'),
                              headers: {'Content-Type': 'application/json'},
                              body: jsonEncode({
                                'codigo_proyecto_sii': code,
                                'ano': year,
                              }),
                            );
                            if (resp.statusCode != 201) {
                              throw Exception('Error al crear (${resp.statusCode})');
                            }
                          }
                          // éxito
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        } catch (e) {
                          if (!ctx.mounted) return;
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              backgroundColor: cs.error,
                              content: Text('Error: $e', style: TextStyle(color: cs.onError)),
                            ),
                          );
                        }
                      },
                      child: Text(isEdit ? 'Guardar' : 'Crear'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (result == true) setState(() => _future = _load());
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar código'),
        content: Text('¿Eliminar “${item['codigo_proyecto_sii']}”?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );

    if (ok != true) return;

    final id = item['id'];
    final resp = await http.delete(Uri.parse('$_baseUrl/codigo_proyecto/$id'));
    if (resp.statusCode != 200) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo eliminar (${resp.statusCode})')),
      );
      return;
    }
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Códigos de proyecto'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createOrEdit(),
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          if (_all.isEmpty) {
            return const Center(child: Text('No hay códigos registrados'));
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
                        hintText: 'Buscar por código o año…',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  sliver: SliverList.separated(
                    itemCount: data.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      final item = data[i];
                      final code = (item['codigo_proyecto_sii'] ?? '').toString();
                      final year = item['ano']?.toString() ?? '—';
                      final created = _fmtDate(item['fecha_creacion']?.toString());

                      return Card(
                        elevation: 0,
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: cs.outlineVariant),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                          child: Row(
                            children: [
                              // Icono
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: cs.secondaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.tag, color: cs.onSecondaryContainer),
                              ),
                              const SizedBox(width: 12),
                              // Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(code,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700, fontSize: 16)),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: [
                                        _pill(
                                          context,
                                          icon: Icons.calendar_today,
                                          label: 'Año $year',
                                        ),
                                        _pill(
                                          context,
                                          icon: Icons.schedule_rounded,
                                          label: 'Creado: $created',
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Acciones
                              IconButton(
                                tooltip: 'Editar',
                                onPressed: () => _createOrEdit(initial: item),
                                icon: const Icon(Icons.edit_rounded),
                              ),
                              IconButton(
                                tooltip: 'Eliminar',
                                onPressed: () => _delete(item),
                                icon: const Icon(Icons.delete_outline_rounded),
                              ),
                            ],
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

  Widget _pill(BuildContext context, {required IconData icon, required String label}) {
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
}
