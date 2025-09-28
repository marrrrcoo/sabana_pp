import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/usuario.dart';
import '../models/proyecto.dart';
import '../models/departamento.dart';
import '../models/puesto.dart';

class ApiService {
  final String baseUrl = 'http://10.0.2.2:3000';

  // ==============================
  // Login
  // ==============================
  Future<Usuario?> login(String correo, String password) async {
    final url = Uri.parse('$baseUrl/login');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'correo': correo, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['error'] != null) return null;
      return Usuario.fromJson(data);
    } else {
      throw Exception('Error en login');
    }
  }

  // ==============================
  // Usuarios
  // ==============================
  Future<List<Usuario>> getUsuarios() async {
    final url = Uri.parse('$baseUrl/usuarios');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Usuario.fromJson(json)).toList();
    } else {
      throw Exception('Error al cargar usuarios');
    }
  }

  Future<void> crearUsuario(Usuario u, int adminRpe) async {
    final url = Uri.parse('$baseUrl/usuarios');
    final body = {
      'rpe': u.rpe,
      'nombre': u.nombre,
      'departamento_id': u.departamentoId,
      'puesto_id': u.puestoId,
      'correo': u.correo,
      'password': u.password,
      'admin_rpe': adminRpe,
    };

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode != 201) {
      throw Exception('Error al crear usuario: ${response.body}');
    }
  }

  Future<void> editarUsuario(Usuario u, int adminRpe) async {
    final url = Uri.parse('$baseUrl/usuarios/${u.rpe}');
    final body = {
      'nombre': u.nombre,
      'departamento_id': u.departamentoId,
      'puesto_id': u.puestoId,
      'correo': u.correo,
      'password': u.password,
      'admin_rpe': adminRpe,
    };

    final response = await http.put(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception('Error al editar usuario: ${response.body}');
    }
  }

  Future<void> eliminarUsuario(int rpeUsuario, int adminRpe) async {
    final url = Uri.parse('$baseUrl/usuarios/$rpeUsuario?admin_rpe=$adminRpe');
    final response = await http.delete(url, headers: {'Content-Type': 'application/json'});

    if (response.statusCode != 200) {
      throw Exception('Error al eliminar usuario: ${response.body}');
    }
  }

  Future<List<Departamento>> getDepartamentos() async {
    final url = Uri.parse('$baseUrl/usuarios/departamentos');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Departamento.fromJson(json)).toList();
    } else {
      throw Exception('Error al cargar departamentos');
    }
  }

  Future<List<Puesto>> getPuestos() async {
    final url = Uri.parse('$baseUrl/usuarios/puestos');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Puesto.fromJson(json)).toList();
    } else {
      throw Exception('Error al cargar puestos');
    }
  }

  // ==============================
  // Proyectos
  // ==============================
  Future<List<Proyecto>> getProyectosPorUsuario(int rpe) async {
    final url = Uri.parse('$baseUrl/proyectos/usuario/$rpe');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Proyecto.fromJson(json)).toList();
    } else {
      throw Exception('Error al cargar proyectos por usuario');
    }
  }

  Future<List<Proyecto>> getTodosProyectos() async {
    final url = Uri.parse('$baseUrl/proyectos');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Proyecto.fromJson(json)).toList();
    } else {
      throw Exception('Error al cargar todos los proyectos');
    }
  }

  Future<void> crearProyecto({
    required String nombre,
    required int departamentoId,
    required double presupuesto,
    int monedaId = 1,
    int tipoProcedimientoId = 1,
    required int rpe,
    required String plazoEntrega,
    required String fechaEstudioNecesidades,
    required int codigoProyectoSiiId,  // Campo para el ID del código de proyecto
  }) async {
    final url = Uri.parse('$baseUrl/proyectos');
    final body = {
      'nombre': nombre,
      'departamento_id': departamentoId,
      'presupuesto_estimado': presupuesto,
      'moneda_id': monedaId,
      'tipo_procedimiento_id': tipoProcedimientoId,
      'rpe': rpe,
      'plazo_entrega': plazoEntrega,
      'fecha_estudio_necesidades': fechaEstudioNecesidades,
      'codigo_proyecto_sii_id': codigoProyectoSiiId,  // Enviar el ID del código de proyecto
    };

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode != 201) {
      throw Exception('Error al crear proyecto: ${response.body}');
    }
  }

  Future<void> actualizarEntregaSubida(int proyectoId, bool valor) async {
    final url = Uri.parse('$baseUrl/proyectos/$proyectoId/entrega_subida');
    final response = await http.patch(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'entrega_subida': valor}),
    );

    if (response.statusCode != 200) {
      throw Exception('Error al actualizar la entrega de especificaciones');
    }
  }

  Future<Proyecto> getProyectoById(int id) async {
    final url = Uri.parse('$baseUrl/proyectos/$id');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Proyecto.fromJson(data);
    } else {
      throw Exception('Error al cargar el proyecto');
    }
  }



}
