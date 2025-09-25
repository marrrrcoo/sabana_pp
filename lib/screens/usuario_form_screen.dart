import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/usuario.dart';
import '../models/departamento.dart';
import '../models/puesto.dart';

class UsuarioFormScreen extends StatefulWidget {
  final Usuario? usuario;
  final int adminRpe;

  const UsuarioFormScreen({super.key, this.usuario, required this.adminRpe});

  @override
  State<UsuarioFormScreen> createState() => _UsuarioFormScreenState();
}

class _UsuarioFormScreenState extends State<UsuarioFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService api = ApiService();

  late TextEditingController rpeController;
  late TextEditingController nombreController;
  late TextEditingController correoController;
  late TextEditingController passwordController;

  int? departamentoSeleccionadoId;
  int? puestoSeleccionadoId;

  List<Departamento> departamentos = [];
  List<Puesto> puestos = [];

  @override
  void initState() {
    super.initState();
    rpeController = TextEditingController(text: widget.usuario?.rpe.toString() ?? '');
    nombreController = TextEditingController(text: widget.usuario?.nombre ?? '');
    correoController = TextEditingController(text: widget.usuario?.correo ?? '');
    passwordController = TextEditingController(text: '');

    // Cargar dropdowns
    api.getDepartamentos().then((value) {
      setState(() => departamentos = value);
      if (widget.usuario != null) {
        departamentoSeleccionadoId = widget.usuario!.departamentoId;
      }
    });
    api.getPuestos().then((value) {
      setState(() => puestos = value);
      if (widget.usuario != null) {
        puestoSeleccionadoId = widget.usuario!.puestoId;
      }
    });
  }

  void _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    final u = Usuario(
      rpe: int.parse(rpeController.text),
      nombre: nombreController.text,
      correo: correoController.text,
      password: passwordController.text,
      departamentoId: departamentoSeleccionadoId!,
      puestoId: puestoSeleccionadoId!,
    );

    try {
      if (widget.usuario == null) {
        await api.crearUsuario(u, widget.adminRpe);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuario creado')));
      } else {
        await api.editarUsuario(u, widget.adminRpe);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuario actualizado')));
      }
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.usuario == null ? 'Crear Usuario' : 'Editar Usuario')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: rpeController,
                decoration: const InputDecoration(labelText: 'RPE'),
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? 'Ingrese RPE' : null,
              ),
              TextFormField(
                controller: nombreController,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (v) => v!.isEmpty ? 'Ingrese nombre' : null,
              ),
              TextFormField(
                controller: correoController,
                decoration: const InputDecoration(labelText: 'Correo'),
                validator: (v) => v!.isEmpty ? 'Ingrese correo' : null,
              ),
              TextFormField(
                controller: passwordController,
                decoration: const InputDecoration(labelText: 'Contraseña'),
                obscureText: true,
                validator: (v) {
                  if (widget.usuario == null && v!.isEmpty) return 'Ingrese contraseña';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: departamentoSeleccionadoId,
                decoration: const InputDecoration(labelText: 'Departamento'),
                items: departamentos.map((d) => DropdownMenuItem<int>(
                  value: d.id,
                  child: Text(d.nombre),
                )).toList(),
                onChanged: (value) => setState(() => departamentoSeleccionadoId = value),
                validator: (v) => v == null ? 'Seleccione un departamento' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: puestoSeleccionadoId,
                decoration: const InputDecoration(labelText: 'Puesto'),
                items: puestos.map((p) => DropdownMenuItem<int>(
                  value: p.id,
                  child: Text(p.nombre),
                )).toList(),
                onChanged: (value) => setState(() => puestoSeleccionadoId = value),
                validator: (v) => v == null ? 'Seleccione un puesto' : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: _guardar, child: const Text('Guardar Usuario')),
            ],
          ),
        ),
      ),
    );
  }
}
