import 'package:flutter/material.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart' as picker;
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ProyectoFormScreen extends StatefulWidget {
  final int rpe;
  final String nombre;
  final int departamentoId;
  // Si más adelante quieres usar roles desde aquí, añade: final String rol;

  const ProyectoFormScreen({
    super.key,
    required this.rpe,
    required this.nombre,
    required this.departamentoId,
    // this.rol = 'user',
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
  DateTime? _plazoEntrega;
  DateTime? _fechaEstudio;

  List<Map<String, dynamic>> _codigosProyecto = [];
  String? _codigoProyectoSeleccionado;
  bool _loadingCodigos = true;
  String? _errorCodigos;
  bool _saving = false;

  late final ApiService api; // <<--- usaremos actorRpe en headers

  @override
  void initState() {
    super.initState();
    // Crea ApiService con el actor RPE (y opcionalmente actorRol si lo tienes)
    api = ApiService(
      actorRpe: widget.rpe,
      // actorRol: widget.rol, // si decides pasar rol al form
    );
    _obtenerCodigosProyecto();
  }

  // Helpers de formato
  String _fmtUi(DateTime d) => DateFormat('dd/MM/yy').format(d);
  String _fmtApi(DateTime? d) => d == null ? '' : DateFormat('yyyy-MM-dd').format(d);

  // Cargar códigos
  Future<void> _obtenerCodigosProyecto() async {
    setState(() {
      _loadingCodigos = true;
      _errorCodigos = null;
    });
    try {
      final resp = await http.get(Uri.parse('http://10.0.2.2:3000/codigo_proyecto'));
      if (resp.statusCode == 200) {
        final list = List<Map<String, dynamic>>.from(jsonDecode(resp.body));
        setState(() {
          _codigosProyecto = list;
          _loadingCodigos = false;
        });
      } else {
        throw Exception('HTTP ${resp.statusCode}');
      }
    } catch (e) {
      setState(() {
        _errorCodigos = 'Error al obtener códigos: $e';
        _loadingCodigos = false;
      });
    }
  }

  // Date pickers
  Future<void> _seleccionarFechaEntrega() async {
    final selectedDate = await picker.DatePicker.showDatePicker(
      context,
      showTitleActions: true,
      minTime: DateTime(2020, 1, 1),
      maxTime: DateTime(2100, 12, 31),
      locale: picker.LocaleType.es,
    );
    if (selectedDate != null) {
      setState(() {
        _plazoEntrega = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
        plazoEntregaController.text = _fmtUi(_plazoEntrega!);
      });
    }
  }

  Future<void> _seleccionarFechaEstudio() async {
    final selectedDate = await picker.DatePicker.showDatePicker(
      context,
      showTitleActions: true,
      minTime: DateTime(2020, 1, 1),
      maxTime: DateTime(2100, 12, 31),
      locale: picker.LocaleType.es,
    );
    if (selectedDate != null) {
      setState(() {
        _fechaEstudio = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
        fechaEstudioNecesidadesController.text = _fmtUi(_fechaEstudio!);
      });
    }
  }

  // Guardar
  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_codigoProyectoSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccione un código de proyecto')),
      );
      return;
    }
    if (_plazoEntrega == null || _fechaEstudio == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccione las fechas requeridas')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final presupuesto = double.tryParse(presupuestoController.text.replaceAll(',', '.'));
      if (presupuesto == null) {
        throw Exception('Presupuesto inválido');
      }

      await api.crearProyecto( // <<--- SIN 'rpe:'
        nombre: nombreController.text.trim(),
        departamentoId: widget.departamentoId,
        presupuesto: presupuesto,
        plazoEntrega: _fmtApi(_plazoEntrega),
        fechaEstudioNecesidades: _fmtApi(_fechaEstudio),
        codigoProyectoSiiId: int.parse(_codigoProyectoSeleccionado!),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Proyecto creado')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    nombreController.dispose();
    presupuestoController.dispose();
    plazoEntregaController.dispose();
    fechaEstudioNecesidadesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSave = !_saving &&
        !_loadingCodigos &&
        _errorCodigos == null &&
        (_codigoProyectoSeleccionado != null) &&
        nombreController.text.trim().isNotEmpty &&
        presupuestoController.text.trim().isNotEmpty &&
        plazoEntregaController.text.trim().isNotEmpty &&
        fechaEstudioNecesidadesController.text.trim().isNotEmpty;

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
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingrese nombre' : null,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: presupuestoController,
                decoration: const InputDecoration(
                  labelText: 'Presupuesto (número)',
                  hintText: 'Ej. 100000',
                ),
                keyboardType: TextInputType.number,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingrese presupuesto' : null,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: plazoEntregaController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Plazo de Entrega',
                  hintText: 'dd/MM/yy',
                  suffixIcon: Icon(Icons.event),
                ),
                onTap: _seleccionarFechaEntrega,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingrese plazo de entrega' : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: fechaEstudioNecesidadesController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Entrega de Especificaciones',
                  hintText: 'dd/MM/yy',
                  suffixIcon: Icon(Icons.event),
                ),
                onTap: _seleccionarFechaEstudio,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingrese fecha' : null,
              ),
              const SizedBox(height: 16),

              if (_loadingCodigos)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_errorCodigos != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_errorCodigos!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _obtenerCodigosProyecto,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                )
              else
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

              const SizedBox(height: 24),

              ElevatedButton.icon(
                onPressed: canSave ? _guardar : null,
                icon: _saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_outlined),
                label: const Text('Guardar Proyecto'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
