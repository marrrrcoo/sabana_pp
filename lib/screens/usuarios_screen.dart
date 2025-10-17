import 'package:flutter/material.dart';
import '../models/usuario.dart';
import '../models/departamento.dart';
import '../models/puesto.dart';
import '../services/api_service.dart';

/// Opciones de rol válidas (deben coincidir con backend/DB)
const kRoles = <String>['admin', 'viewer', 'user'];

enum RoleFilter { todos, admin, viewer, user }

class UsuariosScreen extends StatefulWidget {
  final int adminRpe; // necesario para crear/editar/eliminar

  const UsuariosScreen({super.key, required this.adminRpe});

  @override
  State<UsuariosScreen> createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends State<UsuariosScreen> {
  final api = ApiService();

  RoleFilter _filter = RoleFilter.todos;
  List<Usuario> _usuarios = [];
  bool _loading = true;

  // catálogos para el formulario
  List<Departamento> _deps = [];
  List<Puesto> _puestos = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final users = await api.getUsuarios();
      final deps = await api.getDepartamentos();
      final puestos = await api.getPuestos();
      setState(() {
        _usuarios = users;
        _deps = deps;
        _puestos = puestos;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando datos: $e')),
        );
      }
    }
  }

  /// Devuelve el rol "normalizado" para mostrar.
  /// admin -> "Admin", viewer -> "Visualizador", user/null/otro -> "Usuario"
  String _roleDisplay(Usuario u) {
    final r = (u.rol ?? '').toLowerCase().trim();
    if (r == 'admin') return 'Admin';
    if (r == 'viewer') return 'Visualizador';
    return 'Usuario';
  }

  List<Usuario> get _filtered {
    switch (_filter) {
      case RoleFilter.todos:
        return _usuarios;
      case RoleFilter.admin:
        return _usuarios.where((u) => (u.rol ?? '').toLowerCase() == 'admin').toList();
      case RoleFilter.viewer:
        return _usuarios.where((u) => (u.rol ?? '').toLowerCase() == 'viewer').toList();
      case RoleFilter.user:
        return _usuarios.where((u) {
          final r = (u.rol ?? '').toLowerCase();
          return r.isEmpty || r == 'user';
        }).toList();
    }
  }

  int get _countAdmin =>
      _usuarios.where((u) => (u.rol ?? '').toLowerCase() == 'admin').length;
  int get _countViewer =>
      _usuarios.where((u) => (u.rol ?? '').toLowerCase() == 'viewer').length;
  int get _countUser =>
      _usuarios.where((u) {
        final r = (u.rol ?? '').toLowerCase();
        return r.isEmpty || r == 'user';
      }).length;

  Future<void> _confirmDelete(Usuario u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar usuario'),
        content: Text('¿Eliminar a ${u.nombre}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton.tonal(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await api.eliminarUsuario(u.rpe, widget.adminRpe);
      await _loadAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuario eliminado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _openUserForm({Usuario? editing}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _UserFormSheet(
        adminRpe: widget.adminRpe,
        deps: _deps,
        puestos: _puestos,
        editing: editing,
      ),
    );
    await _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadAll,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: _FiltersBar(
                  total: _usuarios.length,
                  admin: _countAdmin,
                  viewer: _countViewer,
                  userCount: _countUser,
                  selected: _filter,
                  onChanged: (f) => setState(() => _filter = f),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              sliver: SliverList.separated(
                itemCount: _filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final u = _filtered[i];
                  final roleDisp = _roleDisplay(u);
                  return Card
                    (
                    elevation: 0,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      title: Text(u.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            Expanded(child: Text(u.correo ?? '—')),
                            const SizedBox(width: 12),
                            _RoleBadge(role: roleDisp),
                          ],
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Editar',
                            icon: const Icon(Icons.edit_rounded),
                            onPressed: () => _openUserForm(editing: u),
                          ),
                          IconButton(
                            tooltip: 'Eliminar',
                            icon: Icon(Icons.delete_rounded, color: cs.error),
                            onPressed: () => _confirmDelete(u),
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
      ),
      floatingActionButton: _loading
          ? null
          : FloatingActionButton(
        onPressed: () => _openUserForm(),
        tooltip: 'Nuevo usuario',
        child: const Icon(Icons.add),
      ),
    );

  }
}

/* ---------- UI helpers ---------- */

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Color bg;
    Color fg;
    switch (role) {
      case 'Admin':
        bg = cs.primaryContainer;
        fg = cs.onPrimaryContainer;
        break;
      case 'Visualizador':
        bg = cs.tertiaryContainer;
        fg = cs.onTertiaryContainer;
        break;
      default: // Usuario u otros
        bg = cs.secondaryContainer;
        fg = cs.onSecondaryContainer;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(role, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _FiltersBar extends StatelessWidget {
  final int total, admin, viewer, userCount;
  final RoleFilter selected;
  final ValueChanged<RoleFilter> onChanged;

  const _FiltersBar({
    required this.total,
    required this.admin,
    required this.viewer,
    required this.userCount,
    required this.selected,
    required this.onChanged,
  });

  Widget _chip(BuildContext ctx, String label, int count, RoleFilter me) {
    final sel = selected == me;
    final cs = Theme.of(ctx).colorScheme;

    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: sel ? cs.onPrimary : cs.surfaceVariant,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: sel ? cs.primary : cs.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
      selected: sel,
      onSelected: (_) => onChanged(me),
      selectedColor: cs.primary,
      labelStyle: TextStyle(color: sel ? cs.onPrimary : null),
      shape: StadiumBorder(side: BorderSide(color: cs.outlineVariant)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _chip(context, 'Todos', total, RoleFilter.todos),
        _chip(context, 'Admin', admin, RoleFilter.admin),
        _chip(context, 'Visualizador', viewer, RoleFilter.viewer),
        _chip(context, 'Usuario', userCount, RoleFilter.user),
      ],
    );
  }
}

/* ---------- Bottom sheet: Crear/Editar ---------- */

class _UserFormSheet extends StatefulWidget {
  final int adminRpe;
  final List<Departamento> deps;
  final List<Puesto> puestos;
  final Usuario? editing;

  const _UserFormSheet({
    required this.adminRpe,
    required this.deps,
    required this.puestos,
    this.editing,
  });

  @override
  State<_UserFormSheet> createState() => _UserFormSheetState();
}

class _UserFormSheetState extends State<_UserFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final api = ApiService();

  late TextEditingController _rpe;
  late TextEditingController _nombre;
  late TextEditingController _correo;
  late TextEditingController _password;

  int? _depId;
  int? _puestoId;
  String? _rolSel; // dropdown de rol

  bool get _isEdit => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    _rpe = TextEditingController(text: e?.rpe.toString() ?? '');
    _nombre = TextEditingController(text: e?.nombre ?? '');
    _correo = TextEditingController(text: e?.correo ?? '');
    _password = TextEditingController(text: e?.password ?? '');

    _depId = e?.departamentoId;
    _puestoId = e?.puestoId;

    // rol inicial: respeta el existente o default 'user'
    final rolActual = (e?.rol ?? '').toLowerCase().trim();
    _rolSel = kRoles.contains(rolActual) ? rolActual : 'user';
  }

  @override
  void dispose() {
    _rpe.dispose();
    _nombre.dispose();
    _correo.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final u = Usuario(
        rpe: int.parse(_rpe.text),
        nombre: _nombre.text,
        departamentoId: _depId!,
        puestoId: _puestoId!,
        correo: _correo.text,
        password: _password.text,
        rol: _rolSel ?? 'user',
      );

      if (_isEdit) {
        await api.editarUsuario(u, widget.adminRpe);
      } else {
        await api.crearUsuario(u, widget.adminRpe);
      }

      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEdit ? 'Usuario actualizado' : 'Usuario creado')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
                const SizedBox(width: 4),
                Text(
                  _isEdit ? 'Editar usuario' : 'Nuevo usuario',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nombre,
                    decoration: const InputDecoration(labelText: 'Nombre completo'),
                    validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _correo,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _rpe,
                          decoration: const InputDecoration(labelText: 'RPE'),
                          keyboardType: TextInputType.number,
                          validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _depId,
                          items: widget.deps
                              .map((d) => DropdownMenuItem(value: d.id, child: Text(d.nombre)))
                              .toList(),
                          onChanged: (v) => setState(() => _depId = v),
                          decoration: const InputDecoration(labelText: 'Departamento'),
                          validator: (v) => v == null ? 'Selecciona' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: _puestoId,
                    items: widget.puestos
                        .map((p) => DropdownMenuItem(value: p.id, child: Text(p.nombre)))
                        .toList(),
                    onChanged: (v) => setState(() => _puestoId = v),
                    decoration: const InputDecoration(labelText: 'Puesto'),
                    validator: (v) => v == null ? 'Selecciona' : null,
                  ),
                  const SizedBox(height: 12),

                  // Dropdown de Rol (nuevo)
                  DropdownButtonFormField<String>(
                    value: _rolSel,
                    items: kRoles
                        .map((r) => DropdownMenuItem<String>(
                      value: r,
                      child: Text(
                        r == 'admin'
                            ? 'Admin'
                            : r == 'viewer'
                            ? 'Visualizador'
                            : 'Usuario',
                      ),
                    ))
                        .toList(),
                    onChanged: (v) => setState(() => _rolSel = v),
                    decoration: const InputDecoration(labelText: 'Rol'),
                    validator: (v) => v == null || v.isEmpty ? 'Selecciona' : null,
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _password,
                    decoration: const InputDecoration(labelText: 'Contraseña'),
                    obscureText: true,
                    validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('CANCELAR'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _submit,
                          child: const Text('GUARDAR'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
