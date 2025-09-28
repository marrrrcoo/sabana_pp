import 'package:flutter/material.dart';
import '../models/proyecto.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';

class ProyectoDetailsScreen extends StatefulWidget {
  final Proyecto proyecto;
  final bool isAdmin; // Para mostrar alertas a admins

  const ProyectoDetailsScreen({super.key, required this.proyecto, this.isAdmin = false});

  @override
  State<ProyectoDetailsScreen> createState() => _ProyectoDetailsScreenState();
}

class _ProyectoDetailsScreenState extends State<ProyectoDetailsScreen> {
  late bool entregaSubida;
  late DateTime fechaEntrega;

  @override
  void initState() {
    super.initState();
    entregaSubida = widget.proyecto.entregaSubida;  // Asegúrate de que esto no sea null
    try {
      fechaEntrega = DateTime.parse(widget.proyecto.fechaEstudioNecesidades!);  // Convertir la fecha a DateTime
      print("Fecha de entrega: $fechaEntrega");
    } catch (e) {
      print("Error al parsear fecha de entrega: $e");
    }
  }

  // Actualizar checkbox en backend
  void _toggleEntrega(bool value) async {
    try {
      await ApiService().actualizarEntregaSubida(widget.proyecto.id, value); // Llamada para actualizar el checkbox en la base de datos
      setState(() {
        entregaSubida = value;  // Actualizamos el estado localmente
      });
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error al actualizar: $e')));  // En caso de error al actualizar
    }
  }

  // Lógica para notificaciones
  bool get alertaUsuario {
    final now = DateTime.now();
    final diff = fechaEntrega.difference(now).inDays;
    print("Diferencia de días: $diff");
    return !entregaSubida && (diff == 2 || diff == 1);  // Alertar al usuario 2-1 día antes de la fecha de entrega
  }

  bool get alertaAdmin {
    final now = DateTime.now();
    print("Fecha actual: $now");
    print("Fecha de entrega: $fechaEntrega");
    return !entregaSubida && now.isAfter(fechaEntrega) && widget.isAdmin;  // Alertar al admin si la fecha ya pasó y no está subida
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = alertaAdmin ? Colors.yellow[200] : Colors.white;  // Si es un admin y la fecha pasó, marcar el fondo en amarillo

    return Scaffold(
      appBar: AppBar(title: Text('Detalles del Proyecto')),
      body: Container(
        color: bgColor,  // Aplicar color de fondo amarillo para los admins con proyectos vencidos
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
                  value: entregaSubida,  // Aquí aseguramos que el valor local se use
                  onChanged: (value) => _toggleEntrega(value!),  // Aquí actualizamos el estado al cambiar el checkbox
                ),
              ],
            ),
            if (alertaUsuario)
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.red[100],
                child: const Text('¡No ha subido la entrega! Faltan 1-2 días para la fecha límite.'),  // Alerta si faltan 1-2 días
              ),
            if (alertaAdmin)
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.orange[100],
                child: const Text('¡La entrega de especificaciones no se subió!'),  // Alerta si la fecha ya pasó
              ),
          ],
        ),
      ),
    );
  }
}
