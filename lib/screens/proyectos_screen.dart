import 'package:flutter/material.dart';
import 'package:flutter_http_demo/screens/proyecto_details_screen.dart';
import '../services/api_service.dart';
import '../models/proyecto.dart';
import 'ProyectoFormScreen.dart';

class ProyectosScreen extends StatefulWidget {
  final int rpe;
  final String nombre;
  final int departamentoId;
  final bool showLogout;
  final bool isAdmin;

  const ProyectosScreen({
    super.key,
    required this.rpe,
    required this.nombre,
    required this.departamentoId,
    this.showLogout = true,
    this.isAdmin = false,
  });

  @override
  State<ProyectosScreen> createState() => _ProyectosScreenState();
}

class _ProyectosScreenState extends State<ProyectosScreen> {
  final ApiService api = ApiService();
  late Future<List<Proyecto>> proyectos;

  @override
  void initState() {
    super.initState();
    if (widget.isAdmin) {
      proyectos = api.getTodosProyectos(); // Admin ve todos
    } else {
      proyectos = api.getProyectosPorUsuario(widget.rpe); // Usuario normal
    }
  }

  // Función para recargar los proyectos después de ver o actualizar un proyecto
  void _recargarProyectos() {
    setState(() {
      if (widget.isAdmin) {
        proyectos = api.getTodosProyectos();
      } else {
        proyectos = api.getProyectosPorUsuario(widget.rpe);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bienvenido, ${widget.nombre}'),
      ),
      body: FutureBuilder<List<Proyecto>>(
        future: proyectos,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (snapshot.data!.isEmpty) {
            return const Center(child: Text('No hay proyectos'));
          }

          final listaProyectos = snapshot.data!;
          return ListView.builder(
            itemCount: listaProyectos.length,
            itemBuilder: (context, index) {
              final p = listaProyectos[index];
              return ListTile(
                title: Text(p.nombre),
                subtitle: Text('Etapa: ${p.etapa}, Estado: ${p.estado}'),
                trailing: Text('${p.presupuestoEstimado} ${p.monedaId}'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProyectoDetailsScreen(proyecto: p),
                    ),
                  ).then((_) {
                    _recargarProyectos();  // Recargar los proyectos después de regresar
                  });
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProyectoFormScreen(
                rpe: widget.rpe,
                nombre: widget.nombre,
                departamentoId: widget.departamentoId,
              ),
            ),
          ).then((_) => setState(() {
            if (widget.isAdmin) {
              proyectos = api.getTodosProyectos();
            } else {
              proyectos = api.getProyectosPorUsuario(widget.rpe);
            }
          }));
        },
      ),
    );
  }
}
