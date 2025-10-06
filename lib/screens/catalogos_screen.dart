// lib/screens/catalogos_screen.dart
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class CatalogosScreen extends StatefulWidget {
  final int adminRpe; // necesario para permisos en backend

  const CatalogosScreen({super.key, required this.adminRpe});

  @override
  State<CatalogosScreen> createState() => _CatalogosScreenState();
}

class _CatalogosScreenState extends State<CatalogosScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogos'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Códigos'),
            Tab(text: 'Puestos'),
            Tab(text: 'Estados'),
            Tab(text: 'Tipos'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _CodigosTab(adminRpe: widget.adminRpe),
          _PuestosTab(adminRpe: widget.adminRpe),
          _EstadosTab(adminRpe: widget.adminRpe),
          _TiposTab(adminRpe: widget.adminRpe),
        ],
      ),
      backgroundColor: cs.surface,
    );
  }
}

/* -------------------- CÓDIGOS -------------------- */

class _CodigosTab extends StatefulWidget {
  final int adminRpe;
  const _CodigosTab({required this.adminRpe});

  @override
  State<_CodigosTab> createState() => _CodigosTabState();
}

class _CodigosTabState extends State<_CodigosTab> {
  final api = ApiService();
  List<dynamic> _items = [];
  bool _loading = true;

  final _codigoCtrl = TextEditingController();
  final _anoCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _codigoCtrl.dispose();
    _anoCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await api.getCodigosProyecto();
      setState(() {
        _items = data;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _toast('Error: $e');
    }
  }

  Future<void> _crear() async {
    if (_codigoCtrl.text.trim().isEmpty || _anoCtrl.text.trim().isEmpty) {
      _toast('Completa código y año');
      return;
    }
    try {
      await api.crearCodigoProyecto(
        codigoProyectoSii: _codigoCtrl.text.trim(),
        ano: int.parse(_anoCtrl.text.trim()),
        adminRpe: widget.adminRpe,
      );
      _codigoCtrl.clear();
      _anoCtrl.clear();
      await _load();
    } catch (e) {
      _toast('Error: $e');
    }
  }

  Future<void> _editar(Map item) async {
    final codigoCtrl = TextEditingController(text: item['codigo_proyecto_sii']);
    final anoCtrl = TextEditingController(text: item['ano'].toString());

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Editar código'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: codigoCtrl, decoration: const InputDecoration(labelText: 'Código')),
            TextField(controller: anoCtrl, decoration: const InputDecoration(labelText: 'Año'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar')),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await api.editarCodigoProyecto(
        id: item['id'] as int,
        codigoProyectoSii: codigoCtrl.text.trim(),
        ano: int.parse(anoCtrl.text.trim()),
      );
      await _load();
    } catch (e) {
      _toast('Error: $e');
    }
  }

  Future<void> _eliminar(int id) async {
    try {
      await api.eliminarCodigoProyecto(id, adminRpe: widget.adminRpe);
      await _load();
    } catch (e) {
      _toast('Error: $e');
    }
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return _loading
        ? const Center(child: CircularProgressIndicator())
        : Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _codigoCtrl,
                  decoration: const InputDecoration(labelText: 'Código de proyecto'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _anoCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Año'),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(onPressed: _crear, child: const Text('Agregar')),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final it = _items[i] as Map;
                return Card(
                  color: cs.surfaceContainerHighest,
                  child: ListTile(
                    title: Text('${it['codigo_proyecto_sii']} · Año: ${it['ano']}'),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        IconButton(icon: const Icon(Icons.edit), onPressed: () => _editar(it)),
                        IconButton(
                          icon: Icon(Icons.delete, color: cs.error),
                          onPressed: () => _eliminar(it['id'] as int),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/* -------------------- PUESTOS -------------------- */

class _PuestosTab extends StatefulWidget {
  final int adminRpe;
  const _PuestosTab({required this.adminRpe});

  @override
  State<_PuestosTab> createState() => _PuestosTabState();
}

class _PuestosTabState extends State<_PuestosTab> {
  final api = ApiService();
  List<dynamic> _items = [];
  bool _loading = true;

  final _nombreCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await api.catGetPuestos();
      setState(() {
        _items = data;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _toast('Error: $e');
    }
  }

  Future<void> _crear() async {
    if (_nombreCtrl.text.trim().isEmpty) {
      _toast('Escribe un nombre');
      return;
    }
    try {
      await api.catCrearPuesto(_nombreCtrl.text.trim(), widget.adminRpe);
      _nombreCtrl.clear();
      await _load();
    } catch (e) {
      _toast('Error: $e');
    }
  }

  Future<void> _editar(Map item) async {
    final ctrl = TextEditingController(text: item['nombre']?.toString() ?? '');
    final ok = await _promptNombre('Editar puesto', ctrl);
    if (ok != true) return;
    try {
      await api.catEditarPuesto(item['id'] as int, ctrl.text.trim(), widget.adminRpe);
      await _load();
    } catch (e) {
      _toast('Error: $e');
    }
  }

  Future<void> _eliminar(int id) async {
    try {
      await api.catEliminarPuesto(id, widget.adminRpe);
      await _load();
    } catch (e) {
      _toast('Error: $e');
    }
  }

  Future<bool?> _promptNombre(String title, TextEditingController ctrl) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Nombre')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar')),
        ],
      ),
    );
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return _loading
        ? const Center(child: CircularProgressIndicator())
        : Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nombreCtrl,
                  decoration: const InputDecoration(labelText: 'Nuevo puesto'),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(onPressed: _crear, child: const Text('Agregar')),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final it = _items[i] as Map;
                return Card(
                  color: cs.surfaceContainerHighest,
                  child: ListTile(
                    title: Text(it['nombre']?.toString() ?? ''),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        IconButton(icon: const Icon(Icons.edit), onPressed: () => _editar(it)),
                        IconButton(
                          icon: Icon(Icons.delete, color: cs.error),
                          onPressed: () => _eliminar(it['id'] as int),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/* -------------------- ESTADOS -------------------- */

class _EstadosTab extends StatefulWidget {
  final int adminRpe;
  const _EstadosTab({required this.adminRpe});

  @override
  State<_EstadosTab> createState() => _EstadosTabState();
}

class _EstadosTabState extends State<_EstadosTab> {
  final api = ApiService();
  List<dynamic> _items = [];
  bool _loading = true;
  final _nombreCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await api.catGetEstados();
      setState(() {
        _items = data;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _toast('Error: $e');
    }
  }

  Future<void> _crear() async {
    if (_nombreCtrl.text.trim().isEmpty) {
      _toast('Escribe un nombre');
      return;
    }
    try {
      await api.catCrearEstado(_nombreCtrl.text.trim(), widget.adminRpe);
      _nombreCtrl.clear();
      await _load();
    } catch (e) {
      _toast('Error: $e');
    }
  }

  Future<void> _editar(Map item) async {
    final ctrl = TextEditingController(text: item['nombre']?.toString() ?? '');
    final ok = await _promptNombre('Editar estado', ctrl);
    if (ok != true) return;
    try {
      await api.catEditarEstado(item['id'] as int, ctrl.text.trim(), widget.adminRpe);
      await _load();
    } catch (e) {
      _toast('Error: $e');
    }
  }

  Future<void> _eliminar(int id) async {
    try {
      await api.catEliminarEstado(id, widget.adminRpe);
      await _load();
    } catch (e) {
      _toast('Error: $e');
    }
  }

  Future<bool?> _promptNombre(String title, TextEditingController ctrl) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Nombre')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar')),
        ],
      ),
    );
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return _loading
        ? const Center(child: CircularProgressIndicator())
        : Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: TextField(controller: _nombreCtrl, decoration: const InputDecoration(labelText: 'Nuevo estado'))),
              const SizedBox(width: 12),
              ElevatedButton(onPressed: _crear, child: const Text('Agregar')),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final it = _items[i] as Map;
                return Card(
                  color: cs.surfaceContainerHighest,
                  child: ListTile(
                    title: Text(it['nombre']?.toString() ?? ''),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        IconButton(icon: const Icon(Icons.edit), onPressed: () => _editar(it)),
                        IconButton(
                          icon: Icon(Icons.delete, color: cs.error),
                          onPressed: () => _eliminar(it['id'] as int),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/* -------------------- TIPOS (Contratación) -------------------- */

class _TiposTab extends StatefulWidget {
  final int adminRpe;
  const _TiposTab({required this.adminRpe});

  @override
  State<_TiposTab> createState() => _TiposTabState();
}

class _TiposTabState extends State<_TiposTab> {
  final api = ApiService();
  List<dynamic> _items = [];
  bool _loading = true;
  final _nombreCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await api.catGetTipos();
      setState(() {
        _items = data;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _toast('Error: $e');
    }
  }

  Future<void> _crear() async {
    if (_nombreCtrl.text.trim().isEmpty) {
      _toast('Escribe un nombre');
      return;
    }
    try {
      await api.catCrearTipo(_nombreCtrl.text.trim(), widget.adminRpe);
      _nombreCtrl.clear();
      await _load();
    } catch (e) {
      _toast('Error: $e');
    }
  }

  Future<void> _editar(Map item) async {
    final ctrl = TextEditingController(text: item['nombre']?.toString() ?? '');
    final ok = await _promptNombre('Editar tipo', ctrl);
    if (ok != true) return;
    try {
      await api.catEditarTipo(item['id'] as int, ctrl.text.trim(), widget.adminRpe);
      await _load();
    } catch (e) {
      _toast('Error: $e');
    }
  }

  Future<void> _eliminar(int id) async {
    try {
      await api.catEliminarTipo(id, widget.adminRpe);
      await _load();
    } catch (e) {
      _toast('Error: $e');
    }
  }

  Future<bool?> _promptNombre(String title, TextEditingController ctrl) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Nombre')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar')),
        ],
      ),
    );
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return _loading
        ? const Center(child: CircularProgressIndicator())
        : Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: TextField(controller: _nombreCtrl, decoration: const InputDecoration(labelText: 'Nuevo tipo'))),
              const SizedBox(width: 12),
              ElevatedButton(onPressed: _crear, child: const Text('Agregar')),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final it = _items[i] as Map;
                return Card(
                  color: cs.surfaceContainerHighest,
                  child: ListTile(
                    title: Text(it['nombre']?.toString() ?? ''),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        IconButton(icon: const Icon(Icons.edit), onPressed: () => _editar(it)),
                        IconButton(
                          icon: Icon(Icons.delete, color: cs.error),
                          onPressed: () => _eliminar(it['id'] as int),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
