import 'package:flutter/material.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart' as picker;
import '../services/api_service.dart';

class ProyectoFormScreen extends StatefulWidget {
  final int rpe;
  final String rol; // 'admin' | 'user' | 'viewer'
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
  final TextEditingController plazoEntregaDiasController = TextEditingController(); // <- INT (días)
  final TextEditingController fechaEstudioNecesidadesController = TextEditingController();
  final TextEditingController observacionesController = TextEditingController();

  // catálogos
  List<Map<String, dynamic>> _codigosProyecto = [];
  String? _codigoProyectoSeleccionado;

  // tipos de procedimiento (catálogo)
  List<Map<String, dynamic>> _tiposProc = [];
  int? _tipoProcIdSel;

  // tipo de contratación (AD / SE / OP)
  String? _tipoContratacion;

  late final ApiService _api;

  @override
  void initState() {
    super.initState();
    _api = ApiService(actorRpe: widget.rpe, actorRol: widget.rol);
    _cargarCatalogos();
  }

  Future<void> _cargarCatalogos() async {
    try {
      final cods = await _api.getCodigosProyecto();
      final tps = await _api.catGetTipos(); // [{id, nombre}, ...]

      setState(() {
        _codigosProyecto = List<Map<String, dynamic>>.from(cods);
        _tiposProc = List<Map<String, dynamic>>.from(tps);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando catálogos: $e')),
      );
    }
  }

  @override
  void dispose() {
    nombreController.dispose();
    presupuestoController.dispose();
    plazoEntregaDiasController.dispose();
    fechaEstudioNecesidadesController.dispose();
    observacionesController.dispose();
    super.dispose();
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

    if (widget.rol.toLowerCase() == 'viewer') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No tienes permiso para crear proyectos')),
      );
      return;
    }

    try {
      final tipoId = _tipoProcIdSel!; // validado por el form
      final codigoId = int.parse(_codigoProyectoSeleccionado!); // validado por el form
      final plazoDias = int.parse(plazoEntregaDiasController.text); // validado por el form

      await _api.crearProyecto(
        nombre: nombreController.text.trim(),
        departamentoId: widget.departamentoId,
        presupuesto: double.parse(presupuestoController.text),
        tipoProcedimientoId: tipoId,
        plazoEntregaDias: plazoDias, // <- INT
        fechaEstudioNecesidades: fechaEstudioNecesidadesController.text,
        codigoProyectoSiiId: codigoId,
        tipoContratacion: _tipoContratacion,
        observaciones: observacionesController.text.trim(),
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
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Crear Proyecto')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Estado del proyecto (solo lectura)
              Text('Estado del proyecto', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              TextField(
                controller: TextEditingController(text: '00 Planeación'),
                readOnly: true,
                enabled: false,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: cs.surfaceContainerHighest,
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: cs.outlineVariant),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Nombre / Presupuesto
              TextFormField(
                controller: nombreController,
                decoration: const InputDecoration(labelText: 'Concepto de la contratación'),
                validator: (v) => v == null || v.isEmpty ? 'Ingrese nombre' : null,
              ),
              TextFormField(
                controller: presupuestoController,
                decoration: const InputDecoration(labelText: 'Presupuesto'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Ingrese presupuesto';
                  final d = double.tryParse(v);
                  if (d == null || d <= 0) return 'Ingrese un monto válido';
                  return null;
                },
              ),

              // Tipo de procedimiento (catálogo)
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _tipoProcIdSel,
                decoration: const InputDecoration(labelText: 'Mecanismo de contratación'),
                items: _tiposProc
                    .map((tp) => DropdownMenuItem<int>(
                  value: (tp['id'] as num).toInt(),
                  child: Text((tp['nombre'] ?? '').toString()),
                ))
                    .toList(),
                onChanged: (v) => setState(() => _tipoProcIdSel = v),
                validator: (v) => v == null ? 'Seleccione el tipo de ejercicio' : null,
              ),

              // Tipo de contratación (AD/SE/OP)
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
                validator: (v) => v == null ? 'Seleccione el tipo de contratación' : null,
              ),

              // Plazo de entrega (días) — INT
              const SizedBox(height: 12),
              TextFormField(
                controller: plazoEntregaDiasController,
                decoration: const InputDecoration(labelText: 'Plazo de entrega (días)'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Ingresa el número de días';
                  final n = int.tryParse(v);
                  if (n == null || n <= 0) return 'Ingresa un número válido (> 0)';
                  return null;
                },
              ),

              // Entrega de especificaciones (fecha)
              const SizedBox(height: 12),
              TextFormField(
                controller: fechaEstudioNecesidadesController,
                decoration: const InputDecoration(labelText: 'Entrega de especificaciones'),
                readOnly: true,
                onTap: _seleccionarFechaEstudio,
                validator: (v) => v == null || v.isEmpty ? 'Seleccione la fecha' : null,
              ),

              // Código de proyecto
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _codigoProyectoSeleccionado,
                decoration: const InputDecoration(labelText: 'Código de proyecto'),
                items: _codigosProyecto
                    .map((codigo) => DropdownMenuItem<String>(
                  value: codigo['id'].toString(),
                  child: Text(codigo['codigo_proyecto_sii'].toString()),
                ))
                    .toList(),
                onChanged: (valor) => setState(() => _codigoProyectoSeleccionado = valor),
                validator: (v) => v == null ? 'Seleccione un código' : null,
              ),

              // Observaciones
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
