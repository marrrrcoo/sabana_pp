import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ProyectoFormScreen extends StatefulWidget {
  final int rpe;
  final String nombre;
  final int departamentoId;

  const ProyectoFormScreen({
    super.key,
    required this.rpe,
    required this.nombre,
    required this.departamentoId,
  });

  @override
  State<ProyectoFormScreen> createState() => _ProyectoFormScreenState();
}

class _ProyectoFormScreenState extends State<ProyectoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService api = ApiService();
  final TextEditingController nombreController = TextEditingController();
  final TextEditingController presupuestoController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  void _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await api.crearProyecto(
        nombre: nombreController.text,
        departamentoId: widget.departamentoId,
        presupuesto: double.parse(presupuestoController.text),
        rpe: widget.rpe,
      );
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Proyecto creado')));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear Proyecto')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: nombreController,
                decoration: const InputDecoration(labelText: 'Nombre del Proyecto'),
                validator: (v) => v!.isEmpty ? 'Ingrese nombre' : null,
              ),
              TextFormField(
                controller: presupuestoController,
                decoration: const InputDecoration(labelText: 'Presupuesto'),
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? 'Ingrese presupuesto' : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _guardar,
                child: const Text('Guardar Proyecto'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
