import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/usuario.dart';
import '../models/proyecto.dart';
import '../models/departamento.dart';
import '../models/puesto.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
  final String baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:3000';

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
      'rol': u.rol,
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
      'rol': u.rol,
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

  Future<List<Proyecto>> getTodosProyectosPaged({
    int page = 1,
    int limit = 20,
    String order = 'vencimiento',
  }) async {
    final off = (page - 1) * limit;
    final uri = Uri.parse('$baseUrl/proyectos').replace(queryParameters: {
      'order': order,
      'limit': '$limit',
      'offset': '$off',
    });
    //               AQUÍ ESTÁ EL CAMBIO 👇
    final res = await http.get(uri, headers: _authJsonHeaders);
    if (res.statusCode != 200) {
      throw Exception('Error al cargar proyectos (paginado): ${res.body}');
    }
    final List<dynamic> data = jsonDecode(res.body);
    return data.map((j) => Proyecto.fromJson(j)).toList();
  }

  Future<List<Proyecto>> getProyectosPorDepartamentoPaged(
      int deptoId, {
        int page = 1,
        int limit = 20,
        String order = 'vencimiento',
      }) async {
    final off = (page - 1) * limit;
    final uri = Uri.parse('$baseUrl/proyectos/departamento/$deptoId').replace(
      queryParameters: {
        'order': order,
        'limit': '$limit',
        'offset': '$off',
      },
    );
    final res = await http.get(uri, headers: _jsonHeaders);
    if (res.statusCode != 200) {
      throw Exception('Error al cargar proyectos depto (paginado): ${res.body}');
    }
    final List<dynamic> data = jsonDecode(res.body);
    return data.map((j) => Proyecto.fromJson(j)).toList();
  }

  Future<void> crearProyecto({
    required String nombre,
    required int departamentoId,
    required double presupuesto,
    int monedaId = 1,
    int tipoProcedimientoId = 1,
    required int plazoEntregaDias,
    required String fechaEstudioNecesidades,
    required int codigoProyectoSiiId,
    String? tipoContratacion,
    String? observaciones,
  }) async {
    final url = Uri.parse('$baseUrl/proyectos');

    final body = {
      'nombre': nombre,
      'departamento_id': departamentoId,
      'presupuesto_estimado': presupuesto,
      'moneda_id': monedaId,
      'tipo_procedimiento_id': tipoProcedimientoId,
      'plazo_entrega_dias': plazoEntregaDias,
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

  Future<void> actualizarFechaEntrega({
    required int proyectoId,
    required String fechaISO,
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

  Future<List<Map<String, dynamic>>> getCodigosProyecto({
    String? q,
    String? anoInicio,
    String? anoFin,
  }) async {
    final params = <String, String>{};
    if (q != null && q.trim().isNotEmpty) params['q'] = q.trim();
    if (anoInicio != null) params['ano_inicio'] = anoInicio;
    if (anoFin != null) params['ano_fin'] = anoFin;

    final uri = Uri.parse('$baseUrl/codigo_proyecto')
        .replace(queryParameters: params.isEmpty ? null : params);

    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Error al cargar códigos: ${res.body}');
    }

    final raw = jsonDecode(res.body);
    if (raw is List) {
      return List<Map<String, dynamic>>.from(
        raw.map((e) => Map<String, dynamic>.from(e as Map)),
      );
    }
    return <Map<String, dynamic>>[];
  }

  Future<void> crearCodigoProyecto({
    required String nombre,
    required String codigoProyectoSii,
    required String anoInicio,
    required String anoFin,
    int? adminRpe,
  }) async {
    final url = Uri.parse('$baseUrl/codigo_proyecto');
    final body = {
      'nombre': nombre,
      'codigo_proyecto_sii': codigoProyectoSii,
      'ano_inicio': anoInicio,
      'ano_fin': anoFin,
      if (adminRpe != null) 'admin_rpe': adminRpe,
    };
    final res = await http.post(url, headers: _jsonHeaders, body: jsonEncode(body));
    if (res.statusCode != 201) {
      throw Exception('Error al crear código: ${res.body}');
    }
  }

  Future<void> editarCodigoProyecto({
    required int id,
    required String nombre,
    required String codigoProyectoSii,
    required String anoInicio,
    required String anoFin,
  }) async {
    final url = Uri.parse('$baseUrl/codigo_proyecto/$id');
    final body = {
      'nombre': nombre,
      'codigo_proyecto_sii': codigoProyectoSii,
      'ano_inicio': anoInicio,
      'ano_fin': anoFin,
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
  // Catálogos
  // ==============================
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

  Future<Map<String, dynamic>> actualizarEstado({
    required int proyectoId,
    required int estadoId,
    String? motivo,
    String? numeroIcm,
    String? fechaIcmISO,
    double? importePmc,
    // ✅ NUEVOS CAMPOS para estado 3
    String? atFechaSolicitudIcmISO,
    String? atOficioSolicitudIcm,
    int? plazoEntregaReal,
    String? vigenciaIcmISO,
    String? observaciones,
  }) async {
    final url = Uri.parse('$baseUrl/proyectos/$proyectoId/estado');
    final body = {
      'estado_id': estadoId,
      if (motivo != null && motivo.trim().isNotEmpty) 'motivo': motivo.trim(),
      if (numeroIcm != null && numeroIcm.trim().isNotEmpty) 'numero_icm': numeroIcm.trim(),
      if (fechaIcmISO != null && fechaIcmISO.trim().isNotEmpty) 'fecha_icm': fechaIcmISO.trim(),
      if (importePmc != null) 'importe_pmc': importePmc,
      // ✅ NUEVOS CAMPOS
      if (atFechaSolicitudIcmISO != null && atFechaSolicitudIcmISO.trim().isNotEmpty)
        'at_fecha_solicitud_icm': atFechaSolicitudIcmISO.trim(),
      if (atOficioSolicitudIcm != null && atOficioSolicitudIcm.trim().isNotEmpty)
        'at_oficio_solicitud_icm': atOficioSolicitudIcm.trim(),
      if (plazoEntregaReal != null) 'plazo_entrega_real': plazoEntregaReal,
      if (vigenciaIcmISO != null) 'vigencia_icm': vigenciaIcmISO,
      if (observaciones != null) 'observaciones': observaciones,
      if (actorRpe != null) 'actor_rpe': actorRpe,
      if (actorRol != null) 'actor_rol': actorRol,
    };

    final res = await http.put(url, headers: _authJsonHeaders, body: jsonEncode(body));
    if (res.statusCode != 200) {
      throw Exception('Error al actualizar estado: ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }


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

  Future<void> completarEntregaYEtapaDiam(int proyectoId) async {
    await actualizarEntregaSubida(proyectoId, true);
    await actualizarEtapaPorNombre(proyectoId: proyectoId, nombre: 'Diam');
  }

  Future<List<Map<String, dynamic>>> getHistorialEstados(int proyectoId) async {
    final url = Uri.parse('$baseUrl/proyectos/$proyectoId/estado/historial');
    final res = await http.get(url, headers: _authJsonHeaders);
    if (res.statusCode != 200) {
      throw Exception('Error al cargar historial de estados: ${res.body}');
    }
    final List<dynamic> data = jsonDecode(res.body);
    return data.cast<Map<String, dynamic>>();
  }

  Future<void> notificarVencimiento(int proyectoId) async {
    final url = Uri.parse('$baseUrl/proyectos/$proyectoId/notificar_vencimiento');
    final res = await http.post(
      url,
      headers: _authJsonHeaders,
      body: jsonEncode({
        if (actorRpe != null) 'actor_rpe': actorRpe,
        if (actorRol != null) 'actor_rol': actorRol,
      }),
    );
    if (res.statusCode != 200) {
      throw Exception('No se pudo enviar el correo: ${res.body}');
    }
  }

}