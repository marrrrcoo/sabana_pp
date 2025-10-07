import 'package:intl/intl.dart';

class Proyecto {
  final int id;
  final String nombre;
  final String? tipoContratacion; // 'AD' | 'SE' | 'OP'

  // Claves foráneas / ids crudos
  final int departamentoId;
  final int estadoId;
  final int etapaId;
  final int? monedaId;
  final int? tipoProcedimientoId;
  final int? codigoProyectoSiiId;

  // Datos de negocio
  final double? presupuestoEstimado;
  final String? numeroSolcon;
  final double? importeAnticipo;
  final String? adquisicionServicioObra;
  final String? solicitudPAC;
  final int? plazoEntregaDias;                 // <-- INT (número de días)
  final String? fechaEstudioNecesidades;       // deadline notificaciones
  final String? fechaConclusionEstudio;
  final String? fechaSolicitudICM;
  final String? fechaAperturaTecnica;
  final String? fechaAperturaEconomica;
  final String? fechaFallo;
  final String? fechaFormalizacionContrato;
  final String? fechaPago;
  final String? numeroContrato;
  final double? importeAdjudicado;
  final double? anticipoOtorgado;
  final String? observaciones;
  final bool entregaSubida;

  // Desnormalizados del JOIN (opcionales)
  final String? departamento;
  final String? estado;
  final String? etapa;

  // Nombre legible del tipo de procedimiento (JOIN a tipos_procedimiento)
  final String? tipoProcedimientoNombre;

  // Código SII y Centro (JOIN a codigo_proyectos_sii -> centros)
  final String? codigoProyectoSii;             // p.ej. MG-E2-24-GT19-92
  final int? centroId;                         // id en tabla centros
  final String? centroClave;                   // p.ej. GT19

  // Dueño del proyecto (quien lo creó)
  final int? creadorRpe;

  Proyecto({
    required this.id,
    required this.nombre,
    required this.departamentoId,
    required this.estadoId,
    required this.etapaId,
    required this.entregaSubida,
    this.monedaId,
    this.tipoProcedimientoId,
    this.codigoProyectoSiiId,
    this.presupuestoEstimado,
    this.numeroSolcon,
    this.importeAnticipo,
    this.adquisicionServicioObra,
    this.solicitudPAC,
    this.plazoEntregaDias,
    this.fechaEstudioNecesidades,
    this.fechaConclusionEstudio,
    this.fechaSolicitudICM,
    this.fechaAperturaTecnica,
    this.fechaAperturaEconomica,
    this.fechaFallo,
    this.fechaFormalizacionContrato,
    this.fechaPago,
    this.numeroContrato,
    this.importeAdjudicado,
    this.anticipoOtorgado,
    this.observaciones,
    this.departamento,
    this.estado,
    this.etapa,
    this.tipoProcedimientoNombre,
    this.codigoProyectoSii,
    this.centroId,
    this.centroClave,
    this.creadorRpe,
    this.tipoContratacion,
  });

  /// Indica si la fecha_estudio_necesidades ya venció.
  bool get vencio {
    final s = fechaEstudioNecesidades;
    if (s == null || s.isEmpty) return false;
    final f = DateTime.tryParse(s);
    if (f == null) return false;
    final hoy = DateTime.now();
    final fh = DateTime(f.year, f.month, f.day);
    final hh = DateTime(hoy.year, hoy.month, hoy.day);
    return hh.isAfter(fh);
  }

  /// Formatea la fecha_estudio_necesidades en dd/MM/yy.
  /// Si es nula o no parseable, devuelve '—'.
  String get fechaEstudioNecesidadesDdMmYy {
    final s = fechaEstudioNecesidades;
    if (s == null || s.isEmpty) return '—';
    final dt = DateTime.tryParse(s);
    if (dt == null) return '—';
    return DateFormat('dd/MM/yy').format(dt);
  }

  // Helpers de parseo seguros
  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static int? _asIntOrNull(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }

  static double? _asDoubleOrNull(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static bool _asBool01(dynamic v) {
    if (v is bool) return v;
    if (v is int) return v == 1;
    if (v is String) {
      final s = v.toLowerCase();
      if (s == '1' || s == 'true') return true;
      if (s == '0' || s == 'false') return false;
    }
    return false;
  }

  factory Proyecto.fromJson(Map<String, dynamic> json) {
    return Proyecto(
      id: _asInt(json['id']),
      nombre: (json['nombre'] ?? '').toString(),

      departamentoId: _asInt(json['departamento_id']),
      estadoId: _asInt(json['estado_id']),
      etapaId: _asInt(json['etapa_id']),

      entregaSubida: _asBool01(json['entrega_subida']),

      presupuestoEstimado: _asDoubleOrNull(json['presupuesto_estimado']),
      monedaId: _asIntOrNull(json['moneda_id']),
      tipoProcedimientoId: _asIntOrNull(json['tipo_procedimiento_id']),
      numeroSolcon: json['numero_solcon']?.toString(),
      codigoProyectoSiiId: _asIntOrNull(json['codigo_proyecto_sii_id']),

      importeAnticipo: _asDoubleOrNull(json['importe_anticipo']),
      adquisicionServicioObra: json['adquisicion_servicio_obra']?.toString(),
      solicitudPAC: json['solicitud_pac']?.toString(),
      plazoEntregaDias: _asIntOrNull(json['plazo_entrega_dias']),
      fechaEstudioNecesidades: json['fecha_estudio_necesidades']?.toString(),
      fechaConclusionEstudio: json['fecha_conclusion_estudio']?.toString(),
      fechaSolicitudICM: json['fecha_solicitud_icm']?.toString(),
      fechaAperturaTecnica: json['fecha_apertura_tecnica']?.toString(),
      fechaAperturaEconomica: json['fecha_apertura_economica']?.toString(),
      fechaFallo: json['fecha_fallo']?.toString(),
      fechaFormalizacionContrato: json['fecha_formalizacion_contrato']?.toString(),
      fechaPago: json['fecha_pago']?.toString(),
      numeroContrato: json['numero_contrato']?.toString(),
      importeAdjudicado: _asDoubleOrNull(json['importe_adjudicado']),
      anticipoOtorgado: _asDoubleOrNull(json['anticipo_otorgado']),
      observaciones: json['observaciones']?.toString(),

      departamento: json['departamento']?.toString(),
      estado: json['estado']?.toString(),
      etapa: json['etapa']?.toString(),

      tipoProcedimientoNombre: json['tipo_procedimiento_nombre']?.toString(),

      // Nuevos campos traídos del JOIN
      codigoProyectoSii: json['codigo_proyecto_sii']?.toString(),
      centroId: _asIntOrNull(json['centro_id']),
      centroClave: json['centro_clave']?.toString(),

      creadorRpe: _asIntOrNull(json['creador_rpe']),
      tipoContratacion: json['tipo_contratacion']?.toString(),
    );
  }
}
