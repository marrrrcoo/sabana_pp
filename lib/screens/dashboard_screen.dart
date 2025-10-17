import 'package:flutter/material.dart';
import 'usuarios_screen.dart';
import 'proyectos_screen.dart';
import 'catalogos_screen.dart';
import '../widgets/logout_button.dart';

class DashboardScreen extends StatefulWidget {
  final int rpe;
  final String nombre;
  final int departamentoId;
  final String rol;

  const DashboardScreen({
    super.key,
    required this.rpe,
    required this.nombre,
    required this.departamentoId,
    required this.rol,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  int _selectedIndex = 0;

  bool get isAdmin => widget.rol == 'admin';
  bool get isViewer => widget.rol == 'viewer';

  List<Widget> get _screens => [
    if (isAdmin) UsuariosScreen(adminRpe: widget.rpe),
    ProyectosScreen(
      rpe: widget.rpe,
      nombre: widget.nombre,
      departamentoId: widget.departamentoId,
      rol: widget.rol,
    ),
    if (isAdmin) CatalogosScreen(adminRpe: widget.rpe),
  ];

  List<BottomNavigationBarItem> get _navItems => [
    if (isAdmin)
      const BottomNavigationBarItem(
          icon: Icon(Icons.people), label: 'Usuarios'),
    const BottomNavigationBarItem(
        icon: Icon(Icons.folder), label: 'Contrataciones'),
    if (isAdmin)
      const BottomNavigationBarItem(
          icon: Icon(Icons.library_books_outlined), label: 'Catálogos'),
  ];

  List<String> get _titles => [
    if (isAdmin) 'Usuarios',
    'Contrataciones',
    if (isAdmin) 'Catálogos',
  ];

  String get _roleBadge {
    switch (widget.rol) {
      case 'admin':
        return 'Admin';
      case 'viewer':
        return 'Consulta';
      default:
        return 'Usuario';
    }
  }

  Widget _appBarTitle(BuildContext context) {
    final t = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _titles[_selectedIndex],
          style:
          t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: t.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _roleBadge,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: t.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                widget.nombre,
                style: t.textTheme.bodySmall
                    ?.copyWith(color: t.colorScheme.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 12,
        surfaceTintColor: Colors.transparent,
        title: _appBarTitle(context),
        actions: const [LogoutButton()],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: _navItems.length >= 2
          ? BottomNavigationBar(
        currentIndex: _selectedIndex,
        items: _navItems,
        type: BottomNavigationBarType.fixed,
        onTap: (i) => setState(() => _selectedIndex = i),
      )
          : null,
    );
  }
}
