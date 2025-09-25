import 'package:flutter/material.dart';
import 'usuarios_screen.dart';
import 'proyectos_screen.dart';
import '../widgets/logout_button.dart';

class DashboardScreen extends StatefulWidget {
  final int rpe;
  final String nombre;
  final int departamentoId;
  final bool isAdmin;

  const DashboardScreen({
    super.key,
    required this.rpe,
    required this.nombre,
    required this.departamentoId,
    required this.isAdmin,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  List<Widget> _screens() {
    if (widget.isAdmin) {
      return [
        UsuariosScreen(adminRpe: widget.rpe),
        ProyectosScreen(
          rpe: widget.rpe,
          nombre: widget.nombre,
          departamentoId: widget.departamentoId,
          showLogout: false,
          isAdmin: true,
        ),
      ];
    } else {
      return [
        ProyectosScreen(
          rpe: widget.rpe,
          nombre: widget.nombre,
          departamentoId: widget.departamentoId,
          showLogout: true,
          isAdmin: false,
        ),
      ];
    }
  }

  List<BottomNavigationBarItem> _navItems() {
    if (widget.isAdmin) {
      return const [
        BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Usuarios'),
        BottomNavigationBarItem(icon: Icon(Icons.folder), label: 'Proyectos'),
      ];
    } else {
      return const [
        BottomNavigationBarItem(icon: Icon(Icons.folder), label: 'Proyectos'),
      ];
    }
  }

  List<String> _titles() {
    if (widget.isAdmin) {
      return ['Usuarios', 'Proyectos'];
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
      bottomNavigationBar: _navItems().length >= 2
          ? BottomNavigationBar(
        currentIndex: _selectedIndex,
        items: _navItems(),
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      )
          : null,
    );
  }
}
