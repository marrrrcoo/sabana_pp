import 'package:flutter/material.dart';
import 'usuarios_screen.dart';
import 'proyectos_screen.dart';
import 'catalogos_screen.dart';
import '../widgets/logout_button.dart';

class DashboardScreen extends StatefulWidget {
  final int rpe;
  final String nombre;
  final int departamentoId;
  final String rol; // <-- ahora usamos rol

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

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  bool get isAdmin => widget.rol == 'admin';
  bool get isViewer => widget.rol == 'viewer';

  List<Widget> _screens() {
    if (isAdmin) {
      return [
        UsuariosScreen(adminRpe: widget.rpe),
        ProyectosScreen(
          rpe: widget.rpe,
          nombre: widget.nombre,
          departamentoId: widget.departamentoId,
          rol: widget.rol,
        ),
        CatalogosScreen(adminRpe: widget.rpe),
      ];
    } else if (isViewer) {
      return [
        ProyectosScreen(
          rpe: widget.rpe,
          nombre: widget.nombre,
          departamentoId: widget.departamentoId,
          rol: widget.rol,
        ),
      ];
    } else {
      // user normal
      return [
        ProyectosScreen(
          rpe: widget.rpe,
          nombre: widget.nombre,
          departamentoId: widget.departamentoId,
          rol: widget.rol,
        ),
      ];
    }
  }

  List<BottomNavigationBarItem> _navItems() {
    if (isAdmin) {
      return const [
        BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Usuarios'),
        BottomNavigationBarItem(icon: Icon(Icons.folder), label: 'Proyectos'),
        BottomNavigationBarItem(icon: Icon(Icons.library_books_outlined), label: 'Catálogos'),

      ];
    } else {
      return const [
        BottomNavigationBarItem(icon: Icon(Icons.folder), label: 'Proyectos'),
      ];
    }
  }

  List<String> _titles() {
    if (isAdmin) {
      return ['Usuarios', 'Proyectos', 'Catálogos'];
    } else {
      return ['Proyectos'];
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = _screens();
    final navItems = _navItems();
    final titles = _titles();

    return Scaffold(
      appBar: AppBar(
        title: Text('${titles[_selectedIndex]} - ${widget.nombre}'),
        actions: const [LogoutButton()],
      ),
      body: screens[_selectedIndex],
      bottomNavigationBar: navItems.length >= 2
          ? BottomNavigationBar(
        currentIndex: _selectedIndex,
        items: navItems,
        onTap: (index) => setState(() => _selectedIndex = index),
      )
          : null,
    );
  }
}
