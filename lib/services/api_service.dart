import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/usuario.dart';
import '../models/proyecto.dart';
import '../models/departamento.dart';
import '../models/puesto.dart';

class ApiService {
  final String baseUrl = 'http://10.0.2.2:3000';

  /// Contexto del actor autenticado. Úsalo tras login.
  /// Ej.: ApiService(actorRpe: user.rpe, actorRol: user.rol)
  final int? actorRpe;
  final String? actorRol;

  ApiService({this.actorRpe, this.actorRol});

  Map<String, String> get _jsonHeaders => {
    'Content-Type': 'application/json',
  };

  /// Headers con contexto del actor para endpoints que cambian datos.
  Map<String, String> get _authJsonHeaders => {
    'Content-Type': 'application/json',
    if (actorRol != null) 'x-rol': actorRol!,
    if (actorRpe != null) 'x-rpe': actorRpe!.toString(),
  };

  // ==============================
  // Login
  // ==============================
  Future<Usuario?> login(String correo, String password) async {
    final url = Uri.parse('$baseUrl/login');
    final response = await http.post(
      url,
      headers: _jsonHeaders,
      body: jsonEncode({'correo': correo, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map && data['error'] != null) return null;
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
      'rol': u.rol, // nuevo
      'admin_rpe': adminRpe,
    };

    final response = await http.post(
      url,
      headers: _jsonHeaders,
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
      'rol': u.rol, // nuevo
      'admin_rpe': adminRpe,
    };

    final response = await http.put(
      url,
      headers: _jsonHeaders,
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception('Error al editar usuario: ${response.body}');
    }
  }

  Future<void> eliminarUsuario(int rpeUsuario, int adminRpe) async {
    final url = Uri.parse('$baseUrl/usuarios/$rpeUsuario?admin_rpe=$adminRpe');
    final response = await http.delete(url, headers: _jsonHeaders);

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

  Future<List<Proyecto>> getProyectosPorDepartamento(int deptoId) async {
    final url = Uri.parse('$baseUrl/proyectos/departamento/$deptoId');
    final response = await http.get(url, headers: _jsonHeaders);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((j) => Proyecto.fromJson(j)).toList();
    } else {
      throw Exception('Error al cargar proyectos por departamento');
    }
  }

  Future<void> crearProyecto({
    required String nombre,
    required int departamentoId,
    required double presupuesto,
    int monedaId = 1,
    int tipoProcedimientoId = 1,
    required int plazoEntregaDias,                 // <-- ahora es int
    required String fechaEstudioNecesidades,
    required int codigoProyectoSiiId,
    String? tipoContratacion, // 'AD' | 'SE' | 'OP'
    String? observaciones,
  }) async {
    final url = Uri.parse('$baseUrl/proyectos');

    final body = {
      'nombre': nombre,
      'departamento_id': departamentoId,
      'presupuesto_estimado': presupuesto,
      'moneda_id': monedaId,
      'tipo_procedimiento_id': tipoProcedimientoId,
      'plazo_entrega_dias': plazoEntregaDias,     // <-- clave nueva
      'fecha_estudio_necesidades': fechaEstudioNecesidades,
      'codigo_proyecto_sii_id': codigoProyectoSiiId,
      if (tipoContratacion != null) 'tipo_contratacion': tipoContratacion,
      if (observaciones != null) 'observaciones': observaciones,
      if (actorRpe != null) 'actor_rpe': actorRpe,
      if (actorRol != null) 'actor_rol': actorRol,
    };

    final response = await http.post(
      url,
      headers: _authJsonHeaders,
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
      headers: _authJsonHeaders,
      body: jsonEncode({
        'entrega_subida': valor,
        if (actorRol != null) 'actor_rol': actorRol,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Error al actualizar la entrega de especificaciones');
    }
  }

  // actualizar observaciones con historial
  Future<void> actualizarObservaciones({
    required int proyectoId,
    required String observaciones,
  }) async {
    final url = Uri.parse('$baseUrl/proyectos/$proyectoId/observaciones');
    final res = await http.put(
      url,
      headers: _authJsonHeaders,
      body: jsonEncode({
        'observaciones': observaciones,
        if (actorRpe != null) 'actor_rpe': actorRpe,
        if (actorRol != null) 'actor_rol': actorRol,
      }),
    );
    if (res.statusCode != 200) {
      throw Exception('Error al actualizar observaciones: ${res.body}');
    }
  }

// obtener historial de observaciones
  Future<List<Map<String, dynamic>>> getHistorialObservaciones(int proyectoId) async {
    final url = Uri.parse('$baseUrl/proyectos/$proyectoId/observaciones/historial');
    final res = await http.get(url, headers: _jsonHeaders);
    if (res.statusCode == 200) {
      final List<dynamic> data = jsonDecode(res.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Error al cargar historial de observaciones');
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

  // ====== Fechas (Entrega de especificaciones) ======

  Future<void> actualizarFechaEntrega({
    required int proyectoId,
    required String fechaISO, // 'YYYY-MM-DD'
    String? motivo,
  }) async {
    final url = Uri.parse('$baseUrl/proyectos/$proyectoId/fecha_entrega');
    final res = await http.put(
      url,
      headers: _authJsonHeaders,
      body: jsonEncode({
        'fecha_estudio_necesidades': fechaISO,
        if (motivo != null && motivo.trim().isNotEmpty) 'motivo': motivo.trim(),
        if (actorRpe != null) 'actor_rpe': actorRpe,
        if (actorRol != null) 'actor_rol': actorRol,
      }),
    );
    if (res.statusCode != 200) {
      throw Exception('Error al actualizar fecha: ${res.body}');
    }
  }

  Future<List<Map<String, dynamic>>> getHistorialFechas(int proyectoId) async {
    final url = Uri.parse('$baseUrl/proyectos/$proyectoId/fecha_entrega/historial');
    final res = await http.get(url, headers: _jsonHeaders);
    if (res.statusCode == 200) {
      final List<dynamic> data = jsonDecode(res.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Error al cargar historial de fechas: ${res.body}');
    }
  }


  // ==============================
  // Códigos de proyecto (codigo_proyecto)
  // ==============================
  Future<List<dynamic>> getCodigosProyecto() async {
    final url = Uri.parse('$baseUrl/codigo_proyecto');
    final res = await http.get(url);
    if (res.statusCode != 200) {
      throw Exception('Error al cargar códigos: ${res.body}');
    }
    return jsonDecode(res.body);
  }

  Future<void> crearCodigoProyecto({
    required String codigoProyectoSii,
    required int ano,
    int? adminRpe, // por si luego decides restringir por rol
  }) async {
    final url = Uri.parse('$baseUrl/codigo_proyecto');
    final body = {
      'codigo_proyecto_sii': codigoProyectoSii,
      'ano': ano,
      if (adminRpe != null) 'admin_rpe': adminRpe,
    };
    final res = await http.post(url, headers: _jsonHeaders, body: jsonEncode(body));
    if (res.statusCode != 201) {
      throw Exception('Error al crear código: ${res.body}');
    }
  }

  Future<void> editarCodigoProyecto({
    required int id,
    required String codigoProyectoSii,
    required int ano,
  }) async {
    final url = Uri.parse('$baseUrl/codigo_proyecto/$id');
    final body = {
      'codigo_proyecto_sii': codigoProyectoSii,
      'ano': ano,
    };

    final response = await http.put(
      url,
      headers: _authJsonHeaders,
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception('Error al actualizar código de proyecto: ${response.body}');
    }
  }

  Future<void> eliminarCodigoProyecto(int id, {int? adminRpe}) async {
    final url = Uri.parse(
      adminRpe == null
          ? '$baseUrl/codigo_proyecto/$id'
          : '$baseUrl/codigo_proyecto/$id?admin_rpe=$adminRpe',
    );
    final res = await http.delete(url);
    if (res.statusCode != 200) {
      throw Exception('Error al eliminar código: ${res.body}');
    }
  }

  // ==============================
  // Catálogos (CRUD solo Admin): Puestos / Estados / Tipos
  // ==============================
  // ---- Puestos ----
  Future<List<dynamic>> catGetPuestos() async {
    final res = await http.get(Uri.parse('$baseUrl/catalogos/puestos'));
    if (res.statusCode != 200) throw Exception(res.body);
    return jsonDecode(res.body);
  }

  Future<void> catCrearPuesto(String nombre, int adminRpe) async {
    final res = await http.post(
      Uri.parse('$baseUrl/catalogos/puestos'),
      headers: _jsonHeaders,
      body: jsonEncode({'nombre': nombre, 'admin_rpe': adminRpe}),
    );
    if (res.statusCode != 201) throw Exception(res.body);
  }

  Future<void> catEditarPuesto(int id, String nombre, int adminRpe) async {
    final res = await http.put(
      Uri.parse('$baseUrl/catalogos/puestos/$id'),
      headers: _jsonHeaders,
      body: jsonEncode({'nombre': nombre, 'admin_rpe': adminRpe}),
    );
    if (res.statusCode != 200) throw Exception(res.body);
  }

  Future<void> catEliminarPuesto(int id, int adminRpe) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/catalogos/puestos/$id?admin_rpe=$adminRpe'),
    );
    if (res.statusCode != 200) throw Exception(res.body);
  }

  // ---- Estados de proyecto ----
  Future<List<dynamic>> catGetEstados() async {
    final res = await http.get(Uri.parse('$baseUrl/catalogos/estados'));
    if (res.statusCode != 200) throw Exception(res.body);
    return jsonDecode(res.body);
  }

  Future<void> catCrearEstado(String nombre, int adminRpe) async {
    final res = await http.post(
      Uri.parse('$baseUrl/catalogos/estados'),
      headers: _jsonHeaders,
      body: jsonEncode({'nombre': nombre, 'admin_rpe': adminRpe}),
    );
    if (res.statusCode != 201) throw Exception(res.body);
  }

  Future<void> catEditarEstado(int id, String nombre, int adminRpe) async {
    final res = await http.put(
      Uri.parse('$baseUrl/catalogos/estados/$id'),
      headers: _jsonHeaders,
      body: jsonEncode({'nombre': nombre, 'admin_rpe': adminRpe}),
    );
    if (res.statusCode != 200) throw Exception(res.body);
  }

  Future<void> catEliminarEstado(int id, int adminRpe) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/catalogos/estados/$id?admin_rpe=$adminRpe'),
    );
    if (res.statusCode != 200) throw Exception(res.body);
  }

  // ---- Tipos de contratación (tipos_procedimiento) ----
  Future<List<dynamic>> catGetTipos() async {
    final res = await http.get(Uri.parse('$baseUrl/catalogos/tipos'));
    if (res.statusCode != 200) throw Exception(res.body);
    return jsonDecode(res.body);
  }

  Future<void> catCrearTipo(String nombre, int adminRpe) async {
    final res = await http.post(
      Uri.parse('$baseUrl/catalogos/tipos'),
      headers: _jsonHeaders,
      body: jsonEncode({'nombre': nombre, 'admin_rpe': adminRpe}),
    );
    if (res.statusCode != 201) throw Exception(res.body);
  }

  Future<void> catEditarTipo(int id, String nombre, int adminRpe) async {
    final res = await http.put(
      Uri.parse('$baseUrl/catalogos/tipos/$id'),
      headers: _jsonHeaders,
      body: jsonEncode({'nombre': nombre, 'admin_rpe': adminRpe}),
    );
    if (res.statusCode != 200) throw Exception(res.body);
  }

  Future<void> catEliminarTipo(int id, int adminRpe) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/catalogos/tipos/$id?admin_rpe=$adminRpe'),
    );
    if (res.statusCode != 200) throw Exception(res.body);
  }

  Future<String?> actualizarTipoProcedimiento({
    required int proyectoId,
    required int tipoProcedimientoId,
  }) async {
    final url = Uri.parse('$baseUrl/proyectos/$proyectoId/tipo_procedimiento');
    final res = await http.put(
      url,
      headers: _authJsonHeaders,
      body: jsonEncode({
        'tipo_procedimiento_id': tipoProcedimientoId,
        if (actorRpe != null) 'actor_rpe': actorRpe,
        if (actorRol != null) 'actor_rol': actorRol,
      }),
    );
    if (res.statusCode != 200) {
      throw Exception('Error al actualizar tipo de procedimiento: ${res.body}');
    }
    try {
      final data = jsonDecode(res.body);
      return data['tipo_procedimiento_nombre']?.toString();
    } catch (_) {
      return null;
    }
  }

// Actualiza el ESTADO del proyecto (tabla estados_proyectos)
  Future<Map<String, dynamic>> actualizarEstado({
    required int proyectoId,
    required int estadoId,
  }) async {
    final url = Uri.parse('$baseUrl/proyectos/$proyectoId/estado');
    final res = await http.put(
      url,
      headers: _authJsonHeaders,
      body: jsonEncode({
        'estado_id': estadoId,
        if (actorRpe != null) 'actor_rpe': actorRpe,
        if (actorRol != null) 'actor_rol': actorRol,
      }),
    );
    if (res.statusCode != 200) {
      throw Exception('Error al actualizar estado: ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

// Actualiza la ETAPA por nombre (por ejemplo, "Diam")
  Future<Map<String, dynamic>> actualizarEtapaPorNombre({
    required int proyectoId,
    required String nombre,
  }) async {
    final url = Uri.parse('$baseUrl/proyectos/$proyectoId/etapa');
    final res = await http.put(
      url,
      headers: _authJsonHeaders,
      body: jsonEncode({
        'nombre': nombre,
        if (actorRpe != null) 'actor_rpe': actorRpe,
        if (actorRol != null) 'actor_rol': actorRol,
      }),
    );
    if (res.statusCode != 200) {
      throw Exception('Error al actualizar etapa: ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

// (Opcional) Helper para cuando completes los 3 checkboxes:
// marca entrega_subida y cambia etapa a "Diam".
  Future<void> completarEntregaYEtapaDiam(int proyectoId) async {
    await actualizarEntregaSubida(proyectoId, true);
    await actualizarEtapaPorNombre(proyectoId: proyectoId, nombre: 'Diam');
  }


}
