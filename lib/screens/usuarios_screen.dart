import 'package:flutter/material.dart';
import '../models/usuario.dart';
import '../services/api_service.dart';
import 'usuario_form_screen.dart';
import '../widgets/logout_button.dart';

class UsuariosScreen extends StatefulWidget {
  final int adminRpe; // RPE del usuario logueado (del departamento de programación)
  const UsuariosScreen({super.key, required this.adminRpe});

  @override
  State<UsuariosScreen> createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends State<UsuariosScreen> {
  final ApiService api = ApiService();
  late Future<List<Usuario>> usuarios;

  @override
  void initState() {
    super.initState();
    usuarios = api.getUsuarios(); // Llama al backend para obtener todos los usuarios
  }

  void _refrescarLista() {
    setState(() {
      usuarios = api.getUsuarios();
    });
  }

  void _eliminarUsuario(int rpeUsuario) async {
    try {
      await api.eliminarUsuario(rpeUsuario, widget.adminRpe);
      _refrescarLista();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuario eliminado')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administrar Usuarios'),
      ),
      body: FutureBuilder<List<Usuario>>(
        future: usuarios,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (snapshot.data!.isEmpty) {
            return const Center(child: Text('No hay usuarios'));
          }

          final listaUsuarios = snapshot.data!;
          return ListView.builder(
            itemCount: listaUsuarios.length,
            itemBuilder: (context, index) {
              final u = listaUsuarios[index];
              return ListTile(
                title: Text(u.nombre),
                subtitle: Text(u.correo),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UsuarioFormScreen(
                              usuario: u,
                              adminRpe: widget.adminRpe,
                            ),
                          ),
                        );
                        _refrescarLista();
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _eliminarUsuario(u.rpe),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UsuarioFormScreen(adminRpe: widget.adminRpe),
            ),
          );
          _refrescarLista();
        },
      ),
    );
  }
}
