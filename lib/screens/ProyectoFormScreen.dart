import 'package:flutter/material.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart' as picker;
import '../services/api_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ProyectoFormScreen extends StatefulWidget {
  final int rpe;
  final String rol;          // <-- NUEVO: rol del actor ('admin'|'user'|'viewer')
  final String nombre;
  final int departamentoId;

  const ProyectoFormScreen({
    super.key,
    required this.rpe,
    required this.rol,
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
  final TextEditingController observacionesController = TextEditingController();

  // catálogos
  List<Map<String, dynamic>> _codigosProyecto = [];
  String? _codigoProyectoSeleccionado;

  // tipo de contratación
  String? _tipoContratacion; // 'AD' | 'SE' | 'OP'

  late final ApiService _api; // <-- construido con actor

  @override
  void initState() {
    super.initState();
    // construimos el servicio con el actor para que mande x-rol / x-rpe
    _api = ApiService(actorRpe: widget.rpe, actorRol: widget.rol);
    _obtenerCodigosProyecto();
  }

  @override
  void dispose() {
    nombreController.dispose();
    presupuestoController.dispose();
    plazoEntregaController.dispose();
    fechaEstudioNecesidadesController.dispose();
    observacionesController.dispose();
    super.dispose();
  }

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

  void _seleccionarFechaEntrega() async {
    final selectedDate = await picker.DatePicker.showDatePicker(
      context,
      showTitleActions: true,
      minTime: DateTime(2020, 1, 1),
      maxTime: DateTime(2100, 12, 31),
      locale: picker.LocaleType.es,
    );
    if (selectedDate != null) {
      setState(() {
        plazoEntregaController.text = selectedDate.toString().split(' ')[0];
      });
    }
  }

  void _seleccionarFechaEstudio() async {
    final selectedDate = await picker.DatePicker.showDatePicker(
      context,
      showTitleActions: true,
      minTime: DateTime(2020, 1, 1),
      maxTime: DateTime(2100, 12, 31),
      locale: picker.LocaleType.es,
    );
    if (selectedDate != null) {
      setState(() {
        fechaEstudioNecesidadesController.text = selectedDate.toString().split(' ')[0];
      });
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    // seguridad extra en UI: viewer no debería poder
    if (widget.rol.toLowerCase() == 'viewer') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No tienes permiso para crear proyectos')),
      );
      return;
    }

    try {
      await _api.crearProyecto(
        nombre: nombreController.text.trim(),
        departamentoId: widget.departamentoId,
        presupuesto: double.parse(presupuestoController.text),
        plazoEntrega: plazoEntregaController.text,
        fechaEstudioNecesidades: fechaEstudioNecesidadesController.text,
        codigoProyectoSiiId: int.parse(_codigoProyectoSeleccionado!),
        tipoContratacion: _tipoContratacion,                 // AD/SE/OP
        observaciones: observacionesController.text.trim(),  // opcional
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Proyecto creado')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final canCreate = widget.rol.toLowerCase() != 'viewer';

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

              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _tipoContratacion,
                decoration: const InputDecoration(labelText: 'Tipo de contratación'),
                items: const [
                  DropdownMenuItem(value: 'AD', child: Text('Adquisición (AD)')),
                  DropdownMenuItem(value: 'SE', child: Text('Servicio (SE)')),
                  DropdownMenuItem(value: 'OP', child: Text('Obra (OP)')),
                ],
                onChanged: (v) => setState(() => _tipoContratacion = v),
                validator: (v) => v == null ? 'Seleccione el tipo' : null,
              ),

              const SizedBox(height: 12),
              TextFormField(
                controller: plazoEntregaController,
                decoration: const InputDecoration(labelText: 'Plazo de Entrega'),
                readOnly: true,
                onTap: _seleccionarFechaEntrega,
                validator: (v) => v!.isEmpty ? 'Seleccione la fecha' : null,
              ),
              TextFormField(
                controller: fechaEstudioNecesidadesController,
                decoration: const InputDecoration(labelText: 'Entrega de Especificaciones'),
                readOnly: true,
                onTap: _seleccionarFechaEstudio,
                validator: (v) => v!.isEmpty ? 'Seleccione la fecha' : null,
              ),

              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _codigoProyectoSeleccionado,
                decoration: const InputDecoration(labelText: 'Código de Proyecto'),
                items: _codigosProyecto.map((codigo) {
                  return DropdownMenuItem<String>(
                    value: codigo['id'].toString(),
                    child: Text(codigo['codigo_proyecto_sii']),
                  );
                }).toList(),
                onChanged: (valor) => setState(() => _codigoProyectoSeleccionado = valor),
                validator: (v) => v == null ? 'Seleccione un código' : null,
              ),

              const SizedBox(height: 12),
              TextFormField(
                controller: observacionesController,
                decoration: const InputDecoration(labelText: 'Observaciones (opcional)'),
                maxLines: 3,
              ),

              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: canCreate ? _guardar : null,
                child: const Text('Guardar Proyecto'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
