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
      body: SafeArea(
        child: Column(
          children: [
            Material(
              color: cs.surface,
              child: TabBar(
                controller: _tab,
                tabs: const [
                  Tab(text: 'Proyectos'),
                  Tab(text: 'Puestos'),
                  Tab(text: 'Estados'),
                  Tab(text: 'Mecanismos'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  _CodigosTab(adminRpe: widget.adminRpe),
                  _PuestosTab(adminRpe: widget.adminRpe),
                  _EstadosTab(adminRpe: widget.adminRpe),
                  _TiposTab(adminRpe: widget.adminRpe),
                ],
              ),
            ),
          ],
        ),
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
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  // Filtros
  final _qCtrl = TextEditingController();
  final _fInicioCtrl = TextEditingController();
  final _fFinCtrl = TextEditingController();

  // Plegado/expandido de la tarjeta de filtros
  bool _filtersOpen = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _qCtrl.dispose();
    _fInicioCtrl.dispose();
    _fFinCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final q = _qCtrl.text.trim().isEmpty ? null : _qCtrl.text.trim();
      final ai = int.tryParse(_fInicioCtrl.text.trim());
      final af = int.tryParse(_fFinCtrl.text.trim());
      final data = await api.getCodigosProyecto(q: q, anoInicio: ai, anoFin: af);
      if (!mounted) return;
      setState(() {
        _items = data; // si tu ApiService devuelve List<Map<String, dynamic>>
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _limpiarFiltros() {
    _qCtrl.clear();
    _fInicioCtrl.clear();
    _fFinCtrl.clear();
    _load();
  }
  Future<void> _eliminar(int id) async {
    // Confirmación opcional
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar código'),
        content: const Text('¿Seguro que deseas eliminar este código de proyecto?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await api.eliminarCodigoProyecto(id, adminRpe: widget.adminRpe);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Código eliminado')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }


  Future<void> _openCrear() async {
    final formKey = GlobalKey<FormState>();
    final nombreCtrl = TextEditingController();
    final codigoCtrl = TextEditingController();
    final inicioCtrl = TextEditingController();
    final finCtrl = TextEditingController();

    final ok = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final insets = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + insets),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    IconButton(onPressed: () => Navigator.pop(ctx, false), icon: const Icon(Icons.close)),
                    const SizedBox(width: 4),
                    Text(
                      'Nuevo código de proyecto',
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: codigoCtrl,
                  decoration: const InputDecoration(labelText: 'Código de proyecto SII'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: inicioCtrl,
                        decoration: const InputDecoration(labelText: 'Año inicio'),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          final n = int.tryParse((v ?? '').trim());
                          return n == null ? 'Inválido' : null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: finCtrl,
                        decoration: const InputDecoration(labelText: 'Año fin'),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          final n = int.tryParse((v ?? '').trim());
                          return n == null ? 'Inválido' : null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
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
                      child: FilledButton.icon(
                        onPressed: () {
                          if (!formKey.currentState!.validate()) return;
                          final ai = int.parse(inicioCtrl.text.trim());
                          final af = int.parse(finCtrl.text.trim());
                          if (ai > af) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('Año inicio no puede ser mayor que año fin')),
                            );
                            return;
                          }
                          Navigator.pop(ctx, true);
                        },
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('GUARDAR'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (ok == true) {
      try {
        await api.crearCodigoProyecto(
          nombre: nombreCtrl.text.trim(),
          codigoProyectoSii: codigoCtrl.text.trim(),
          anoInicio: int.parse(inicioCtrl.text.trim()),
          anoFin: int.parse(finCtrl.text.trim()),
          adminRpe: widget.adminRpe,
        );
        await _load();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Código creado')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _editar(Map item) async {
    final formKey = GlobalKey<FormState>();
    final nombreCtrl = TextEditingController(text: item['nombre']?.toString() ?? '');
    final codigoCtrl = TextEditingController(text: item['codigo_proyecto_sii']?.toString() ?? '');
    final inicioCtrl = TextEditingController(text: (item['ano_inicio'] ?? '').toString());
    final finCtrl = TextEditingController(text: (item['ano_fin'] ?? '').toString());

    final ok = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final insets = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + insets),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    IconButton(onPressed: () => Navigator.pop(ctx, false), icon: const Icon(Icons.close)),
                    const SizedBox(width: 4),
                    Text(
                      'Editar código de proyecto',
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: codigoCtrl,
                  decoration: const InputDecoration(labelText: 'Código de proyecto SII'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: inicioCtrl,
                        decoration: const InputDecoration(labelText: 'Año inicio'),
                        keyboardType: TextInputType.number,
                        validator: (v) => int.tryParse((v ?? '').trim()) == null ? 'Inválido' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: finCtrl,
                        decoration: const InputDecoration(labelText: 'Año fin'),
                        keyboardType: TextInputType.number,
                        validator: (v) => int.tryParse((v ?? '').trim()) == null ? 'Inválido' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
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
                      child: FilledButton.icon(
                        onPressed: () {
                          if (!formKey.currentState!.validate()) return;
                          final ai = int.parse(inicioCtrl.text.trim());
                          final af = int.parse(finCtrl.text.trim());
                          if (ai > af) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('Año inicio no puede ser mayor que año fin')),
                            );
                            return;
                          }
                          Navigator.pop(ctx, true);
                        },
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('GUARDAR'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (ok == true) {
      try {
        await api.editarCodigoProyecto(
          id: item['id'] as int,
          nombre: nombreCtrl.text.trim(),
          codigoProyectoSii: codigoCtrl.text.trim(),
          anoInicio: int.parse(inicioCtrl.text.trim()),
          anoFin: int.parse(finCtrl.text.trim()),
        );
        await _load();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Código actualizado')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ---- helpers de UI compacta ----
  InputDecoration _dense({
    String? label,
    String? hint,
    IconData? prefixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      isDense: true,
      border: const OutlineInputBorder(),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 18) : null,
      prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }

  ButtonStyle _compactBtn(BuildContext ctx) => FilledButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    minimumSize: const Size(0, 36),
    visualDensity: VisualDensity.compact,
  );

  ButtonStyle _compactTextBtn(BuildContext ctx) => TextButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    minimumSize: const Size(0, 36),
    visualDensity: VisualDensity.compact,
  );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return _loading
        ? const Center(child: CircularProgressIndicator())
        : Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ----- Filtros plegables -----
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: _filtersOpen ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    style: _compactTextBtn(context),
                    onPressed: () => setState(() => _filtersOpen = true),
                    icon: const Icon(Icons.tune),
                    label: const Text('Mostrar filtros'),
                  ),
                  FilledButton.icon(
                    style: _compactBtn(context),
                    onPressed: _openCrear,
                    icon: const Icon(Icons.add),
                    label: const Text('Nuevo'),
                  ),
                ],
              ),
            ),
            secondChild: Card(
              elevation: 0,
              color: cs.surfaceContainerHighest,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // barra superior con "Ocultar" y acceso a "Nuevo"
                    Row(
                      children: [
                        const Icon(Icons.tune, size: 18),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text('Búsqueda y filtros', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        TextButton.icon(
                          style: _compactTextBtn(context),
                          onPressed: () => setState(() => _filtersOpen = false),
                          icon: const Icon(Icons.keyboard_arrow_up),
                          label: const Text('Ocultar'),
                        ),
                        const SizedBox(width: 6),
                        FilledButton.icon(
                          style: _compactBtn(context),
                          onPressed: _openCrear,
                          icon: const Icon(Icons.add),
                          label: const Text('Nuevo'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Contenido de filtros (compacto)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: 260,
                          child: TextField(
                            controller: _qCtrl,
                            textInputAction: TextInputAction.search,
                            decoration: _dense(
                              hint: 'Buscar por nombre o código…',
                              prefixIcon: Icons.search,
                            ),
                            onSubmitted: (_) => _load(),
                          ),
                        ),
                        SizedBox(
                          width: 110,
                          child: TextField(
                            controller: _fInicioCtrl,
                            keyboardType: TextInputType.number,
                            decoration: _dense(label: 'Año ≥'),
                            onSubmitted: (_) => _load(),
                          ),
                        ),
                        SizedBox(
                          width: 110,
                          child: TextField(
                            controller: _fFinCtrl,
                            keyboardType: TextInputType.number,
                            decoration: _dense(label: 'Año ≤'),
                            onSubmitted: (_) => _load(),
                          ),
                        ),
                        FilledButton.tonalIcon(
                          style: _compactBtn(context),
                          onPressed: _load,
                          icon: const Icon(Icons.filter_alt),
                          label: const Text('Aplicar'),
                        ),
                        TextButton.icon(
                          style: _compactTextBtn(context),
                          onPressed: _limpiarFiltros,
                          icon: const Icon(Icons.clear),
                          label: const Text('Limpiar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Lista
          Expanded(
            child: _items.isEmpty
                ? _emptyState(context)
                : ListView.separated(
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final it = _items[i];
                final nombre = it['nombre']?.toString() ?? '—';
                final codigo = it['codigo_proyecto_sii']?.toString() ?? '—';
                final ai = it['ano_inicio']?.toString() ?? '—';
                final af = it['ano_fin']?.toString() ?? '—';
                final centro = (it['centro_clave'] ?? '').toString();

                return Card(
                  elevation: 0,
                  color: cs.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    title: Text(
                      nombre,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _chip(context, Icons.confirmation_number_outlined, codigo),
                          _chip(context, Icons.calendar_today_outlined, 'Inicio $ai'),
                          _chip(context, Icons.calendar_month_outlined, 'Fin $af'),
                          if (centro.isNotEmpty) _chip(context, Icons.apartment_outlined, centro),
                        ],
                      ),
                    ),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        IconButton(
                          tooltip: 'Editar',
                          icon: const Icon(Icons.edit_rounded),
                          onPressed: () => _editar(it),
                        ),
                        IconButton(
                          tooltip: 'Eliminar',
                          icon: Icon(Icons.delete_rounded, color: cs.error),
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

  Widget _emptyState(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 56, color: cs.onSurfaceVariant),
          const SizedBox(height: 8),
          Text('Sin resultados', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Ajusta los filtros o crea un nuevo código.',
              style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _openCrear,
            icon: const Icon(Icons.add),
            label: const Text('Nuevo código'),
          ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, IconData icon, String label) {
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
