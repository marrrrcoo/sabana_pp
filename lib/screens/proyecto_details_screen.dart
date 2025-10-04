import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/proyecto.dart';
import '../services/api_service.dart';

class ProyectoDetailsScreen extends StatefulWidget {
  final Proyecto proyecto;
  final bool canEdit; // <-- nuevo: controla si se muestra el checkbox

  const ProyectoDetailsScreen({
    super.key,
    required this.proyecto,
    this.canEdit = true,
  });

  @override
  State<ProyectoDetailsScreen> createState() => _ProyectoDetailsScreenState();
}

class _ProyectoDetailsScreenState extends State<ProyectoDetailsScreen> {
  late bool entregaSubida;

  @override
  void initState() {
    super.initState();
    entregaSubida = widget.proyecto.entregaSubida;
  }

  void _toggleEntrega(bool value) async {
    try {
      await ApiService().actualizarEntregaSubida(widget.proyecto.id, value);
      setState(() => entregaSubida = value);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar: $e')),
      );
    }
  }

  bool get _vencio {
    final s = widget.proyecto.fechaEstudioNecesidades;
    if (s == null || s.isEmpty) return false;
    final f = DateTime.tryParse(s);
    if (f == null) return false;
    final hoy = DateTime.now();
    final fh = DateTime(f.year, f.month, f.day);
    final hh = DateTime(hoy.year, hoy.month, hoy.day);
    return hh.isAfter(fh);
  }

  String _fmtDdMmYy(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return DateFormat('dd/MM/yy').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalles del Proyecto')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text('Nombre: ${widget.proyecto.nombre}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('Departamento: ${widget.proyecto.departamento}'),
            Text('Etapa: ${widget.proyecto.etapa}'),
            Text('Estado: ${widget.proyecto.estado}'),
            const SizedBox(height: 12),
            Text('Presupuesto: ${widget.proyecto.presupuestoEstimado} ${widget.proyecto.monedaId}'),
            Text('Tipo de procedimiento: ${widget.proyecto.tipoProcedimientoNombre ?? "—"}'),
            const SizedBox(height: 12),
            if (widget.proyecto.numeroSolcon != null)
              Text('Número de SolCon: ${widget.proyecto.numeroSolcon}'),
            if (widget.proyecto.observaciones != null) ...[
              const SizedBox(height: 12),
              Text('Observaciones: ${widget.proyecto.observaciones}'),
            ],
            const SizedBox(height: 16),
            if (widget.proyecto.fechaEstudioNecesidades != null)
              Text('Entrega de Especificaciones: ${_fmtDdMmYy(widget.proyecto.fechaEstudioNecesidades)}'),
            const SizedBox(height: 20),

            // Solo si no venció y el rol puede editar
            if (!_vencio && widget.canEdit)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Entrega de Especificaciones y Anexos'),
                  Checkbox(
                    value: entregaSubida,
                    onChanged: (value) => _toggleEntrega(value!),
                  ),
                ],
              )
            else if (_vencio)
              const Text(
                'La fecha de entrega de especificaciones ya venció.',
                style: TextStyle(color: Colors.red),
              ),
          ],
        ),
      ),
    );
  }
}
