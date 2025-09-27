import 'package:flutter/material.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart' as picker;
import '../services/api_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
  final TextEditingController nombreController = TextEditingController();
  final TextEditingController presupuestoController = TextEditingController();
  final TextEditingController plazoEntregaController = TextEditingController();
  final TextEditingController fechaEstudioNecesidadesController = TextEditingController();

  List<Map<String, dynamic>> _codigosProyecto = [];  // Lista de códigos de proyecto
  String? _codigoProyectoSeleccionado;  // ID del código seleccionado

  @override
  void initState() {
    super.initState();
    _obtenerCodigosProyecto();  // Obtener los códigos de proyectos
  }

  // Obtener los códigos de proyecto desde la API
  Future<void> _obtenerCodigosProyecto() async {
    final response = await http.get(Uri.parse('http://10.0.2.2:3000/codigo_proyecto'));

    if (response.statusCode == 200) {
      setState(() {
        _codigosProyecto = List<Map<String, dynamic>>.from(jsonDecode(response.body));
      });
    } else {
      throw Exception('Error al obtener los códigos de proyecto');
    }
  }

  // Función para seleccionar la fecha de entrega
  void _seleccionarFechaEntrega() async {
    DateTime? selectedDate = await picker.DatePicker.showDatePicker(
      context,
      showTitleActions: true,
      minTime: DateTime(2020, 1, 1),
      maxTime: DateTime(2100, 12, 31),
      locale: picker.LocaleType.es,
    );
    if (selectedDate != null) {
      setState(() {
        plazoEntregaController.text = selectedDate.toString().split(' ')[0]; // Formato YYYY-MM-DD
      });
    }
  }

  // Función para seleccionar la fecha de estudio de necesidades
  void _seleccionarFechaEstudio() async {
    DateTime? selectedDate = await picker.DatePicker.showDatePicker(
      context,
      showTitleActions: true,
      minTime: DateTime(2020, 1, 1),
      maxTime: DateTime(2100, 12, 31),
      locale: picker.LocaleType.es,
    );
    if (selectedDate != null) {
      setState(() {
        fechaEstudioNecesidadesController.text = selectedDate.toString().split(' ')[0]; // Formato YYYY-MM-DD
      });
    }
  }

  // Función para guardar el proyecto
  void _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    // Llamada al API para guardar el proyecto
    try {
      await ApiService().crearProyecto(
        nombre: nombreController.text,
        departamentoId: widget.departamentoId,
        presupuesto: double.parse(presupuestoController.text),
        plazoEntrega: plazoEntregaController.text,
        fechaEstudioNecesidades: fechaEstudioNecesidadesController.text,
        rpe: widget.rpe,
        codigoProyectoSiiId: int.parse(_codigoProyectoSeleccionado!),  // Asignamos el ID del código de proyecto
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
              TextFormField(
                controller: plazoEntregaController,
                decoration: const InputDecoration(labelText: 'Plazo de Entrega'),
                readOnly: true,
                onTap: _seleccionarFechaEntrega, // Activar selector de fecha
                validator: (v) => v!.isEmpty ? 'Ingrese plazo de entrega' : null,
              ),
              TextFormField(
                controller: fechaEstudioNecesidadesController,
                decoration: const InputDecoration(labelText: 'Entrega de Especificaciones'),
                readOnly: true,
                onTap: _seleccionarFechaEstudio, // Activar selector de fecha
                validator: (v) => v!.isEmpty ? 'Ingrese especificaciones' : null,
              ),
              // Dropdown para seleccionar el código de proyecto
              DropdownButtonFormField<String>(
                value: _codigoProyectoSeleccionado,
                decoration: const InputDecoration(labelText: 'Código de Proyecto'),
                items: _codigosProyecto.map((codigo) {
                  return DropdownMenuItem<String>(
                    value: codigo['id'].toString(),
                    child: Text(codigo['codigo_proyecto_sii']),
                  );
                }).toList(),
                onChanged: (valor) {
                  setState(() {
                    _codigoProyectoSeleccionado = valor;
                  });
                },
                validator: (v) => v == null ? 'Seleccione un código' : null,
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
