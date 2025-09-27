import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CodigoProyectoScreen extends StatefulWidget {
  @override
  _CodigoProyectoScreenState createState() => _CodigoProyectoScreenState();
}

class _CodigoProyectoScreenState extends State<CodigoProyectoScreen> {
  final TextEditingController _codigoController = TextEditingController();
  final TextEditingController _anoController = TextEditingController();
  List<dynamic> _codigos = [];

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
        'ano': int.parse(_anoController.text),  // Cambié "año" por "ano"
      }),
    );

    if (response.statusCode == 201) {
      _obtenerCodigos();  // Refrescar la lista de códigos
      _codigoController.clear();  // Limpiar el campo de texto
      _anoController.clear();  // Limpiar el campo de año
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
      _obtenerCodigos();  // Refrescar la lista de códigos
    } else {
      throw Exception('Error al eliminar el código');
    }
  }

  @override
  void initState() {
    super.initState();
    _obtenerCodigos();
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
                    trailing: IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () => _eliminarCodigo(codigo['id']),
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
