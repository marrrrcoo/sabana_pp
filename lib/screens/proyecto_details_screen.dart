import 'package:flutter/material.dart';
import '../models/proyecto.dart';

class ProyectoDetailsScreen extends StatelessWidget {
  final Proyecto proyecto;

  const ProyectoDetailsScreen({super.key, required this.proyecto});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Detalles del Proyecto')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text('Nombre: ${proyecto.nombre}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('Departamento: ${proyecto.departamento}'),
            Text('Etapa: ${proyecto.etapa}'),
            Text('Estado: ${proyecto.estado}'),
            const SizedBox(height: 12),
            Text('Presupuesto: ${proyecto.presupuestoEstimado} ${proyecto.monedaId}'),
            Text('Tipo de procedimiento: ${proyecto.tipoProcedimientoId}'),
            const SizedBox(height: 12),
            if (proyecto.numeroSolcon != null) Text('Número de SolCon: ${proyecto.numeroSolcon}'),
            if (proyecto.codigoProyectoSII != null) Text('Código Proyecto SII: ${proyecto.codigoProyectoSII}'),
            if (proyecto.observaciones != null) ...[
              const SizedBox(height: 12),
              Text('Observaciones: ${proyecto.observaciones}'),
            ],

          ],
        ),
      ),
    );
  }
}
