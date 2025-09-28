import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/api_service.dart';

class CodigoProyectoScreen extends StatefulWidget {
  @override
  _CodigoProyectoScreenState createState() => _CodigoProyectoScreenState();
}

class _CodigoProyectoScreenState extends State<CodigoProyectoScreen> {
  final TextEditingController _codigoController = TextEditingController();
  final TextEditingController _anoController = TextEditingController();
  List<dynamic> _codigos = [];

  @override
  void initState() {
    super.initState();
    _obtenerCodigos();
  }

  // Obtener todos los códigos
  Future<void> _obtenerCodigos() async {
    final response = await http.get(Uri.parse('http://10.0.2.2:3000/codigo_proyecto'));

    if (response.statusCode == 200) {
      setState(() {
        _codigos = jsonDecode(response.body);
      });
    } else {
      throw Exception('Error al obtener los códigos');
    }
  }

  // Crear un nuevo código
  Future<void> _crearCodigo() async {
    final response = await http.post(
      Uri.parse('http://10.0.2.2:3000/codigo_proyecto'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'codigo_proyecto_sii': _codigoController.text,
        'ano': int.parse(_anoController.text),
      }),
    );

    if (response.statusCode == 201) {
      _obtenerCodigos();
      _codigoController.clear();
      _anoController.clear();
    } else {
      throw Exception('Error al crear el código');
    }
  }

  // Eliminar un código
  Future<void> _eliminarCodigo(int id) async {
    final response = await http.delete(
      Uri.parse('http://10.0.2.2:3000/codigo_proyecto/$id'),
    );

    if (response.statusCode == 200) {
      _obtenerCodigos();
    } else {
      throw Exception('Error al eliminar el código');
    }
  }

  // Editar un código
  void _editarCodigoDialog(Map<String, dynamic> codigo) {
    final TextEditingController codigoController =
    TextEditingController(text: codigo['codigo_proyecto_sii']);
    final TextEditingController anoController =
    TextEditingController(text: codigo['ano'].toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Editar Código de Proyecto'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codigoController,
                decoration: InputDecoration(labelText: 'Código de Proyecto'),
              ),
              TextField(
                controller: anoController,
                decoration: InputDecoration(labelText: 'Año'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await ApiService().editarCodigoProyecto(
                    id: codigo['id'],
                    codigoProyectoSii: codigoController.text,
                    ano: int.parse(anoController.text),
                  );
                  Navigator.pop(context);
                  _obtenerCodigos();
                } catch (e) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestionar Códigos de Proyecto')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _codigoController,
              decoration: const InputDecoration(labelText: 'Código de Proyecto'),
            ),
            TextField(
              controller: _anoController,
              decoration: const InputDecoration(labelText: 'Año'),
              keyboardType: TextInputType.number,
            ),
            ElevatedButton(
              onPressed: _crearCodigo,
              child: const Text('Crear Código'),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: _codigos.length,
                itemBuilder: (context, index) {
                  final codigo = _codigos[index];
                  return ListTile(
                    title: Text('${codigo['codigo_proyecto_sii']} - Año: ${codigo['ano']}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit),
                          onPressed: () => _editarCodigoDialog(codigo),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete),
                          onPressed: () => _eliminarCodigo(codigo['id']),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
