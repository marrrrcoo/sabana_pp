import 'package:flutter/material.dart';
import '../models/proyecto.dart';
import '../services/api_service.dart';

class ProyectoDetailsScreen extends StatefulWidget {
  final Proyecto proyecto;
  final bool isAdmin; // Se puede mantener para futuras funciones si se desea

  const ProyectoDetailsScreen({super.key, required this.proyecto, this.isAdmin = false});

  @override
  State<ProyectoDetailsScreen> createState() => _ProyectoDetailsScreenState();
}

class _ProyectoDetailsScreenState extends State<ProyectoDetailsScreen> {
  late bool entregaSubida;

  @override
  void initState() {
    super.initState();
    entregaSubida = widget.proyecto.entregaSubida;  // Inicializa el checkbox con el valor de la base de datos
  }

  // Actualizar checkbox en backend
  void _toggleEntrega(bool value) async {
    try {
      await ApiService().actualizarEntregaSubida(widget.proyecto.id, value);
      setState(() {
        entregaSubida = value;  // Actualiza el estado local
      });
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error al actualizar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Detalles del Proyecto')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text('Nombre: ${widget.proyecto.nombre}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('Departamento: ${widget.proyecto.departamento}'),
            Text('Etapa: ${widget.proyecto.etapa}'),
            Text('Estado: ${widget.proyecto.estado}'),
            const SizedBox(height: 12),
            Text('Presupuesto: ${widget.proyecto.presupuestoEstimado} ${widget.proyecto.monedaId}'),
            Text('Tipo de procedimiento: ${widget.proyecto.tipoProcedimientoId}'),
            const SizedBox(height: 12),
            if (widget.proyecto.numeroSolcon != null) Text('Número de SolCon: ${widget.proyecto.numeroSolcon}'),
            if (widget.proyecto.observaciones != null) ...[
              const SizedBox(height: 12),
              Text('Observaciones: ${widget.proyecto.observaciones}'),
            ],
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Entrega de Especificaciones y Anexos'),
                Checkbox(
                  value: entregaSubida,
                  onChanged: (value) => _toggleEntrega(value!),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
