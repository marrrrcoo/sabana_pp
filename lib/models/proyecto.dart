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
  final int? plazoEntregaDias;
  final String? fechaEstudioNecesidades;
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

  // Desnormalizados del JOIN
  final String? departamento;
  final String? estado;
  final String? etapa;
  final String? tipoProcedimientoNombre;

  // Código SII y Centro
  final String? codigoProyectoSii;
  final int? centroId;
  final String? centroClave;
  final String? codigoProyectoAnoFin; // <-- CORREGIDO a String?

  // Dueño del proyecto
  final int? creadorRpe;
  final String? creadoPorNombre;

  // ICM
  final String? fechaIcm;
  final String? numeroIcm;
  final double? importePmc;
  final String? fechaEnvioPmc;


  final String? atFechaSolicitudIcm;
  final String? atOficioSolicitudIcm;
  final int? plazoEntregaReal;
  final String? vigenciaIcm;
  final String? fechaExpEstim;
  final String? fechaEntregaExp;
  final String? fechaPublicacion;
  final String? numeroProcedimientoMsc;

  final String? fechaPubliGAB;
  final String? fechaVisitaSitio;
  final String? fechaSesionAclaraciones;

  final String? fechaCancelacion;
  final String? fechaDesierto;

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
    this.codigoProyectoAnoFin,
    this.creadorRpe,
    this.creadoPorNombre,
    this.tipoContratacion,
    this.fechaIcm,
    this.numeroIcm,
    this.importePmc,
    this.fechaEnvioPmc,
    this.atFechaSolicitudIcm,
    this.atOficioSolicitudIcm,
    this.plazoEntregaReal,
    this.vigenciaIcm,
    this.fechaExpEstim,
    this.fechaEntregaExp,
    this.fechaPublicacion,
    this.numeroProcedimientoMsc,
    this.fechaPubliGAB,
    this.fechaVisitaSitio,
    this.fechaSesionAclaraciones,
    this.fechaCancelacion,
    this.fechaDesierto,
  });

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

  String get fechaEstudioNecesidadesDdMmYy {
    final s = fechaEstudioNecesidades;
    if (s == null || s.isEmpty) return '—';
    final dt = DateTime.tryParse(s);
    if (dt == null) return '—';
    return DateFormat('dd/MM/yy').format(dt);
  }

  // Helper para formatear fecha de solicitud ICM
  String get atFechaSolicitudIcmDdMmYy {
    final s = atFechaSolicitudIcm;
    if (s == null || s.isEmpty) return '—';
    final dt = DateTime.tryParse(s);
    if (dt == null) return '—';
    return DateFormat('dd/MM/yy').format(dt);
  }

  // Helpers de parseo
  static int _asInt(dynamic v) => (v is int) ? v : int.tryParse(v?.toString() ?? '0') ?? 0;
  static int? _asIntOrNull(dynamic v) => (v is int) ? v : int.tryParse(v?.toString() ?? '');
  static double? _asDoubleOrNull(dynamic v) => (v is num) ? v.toDouble() : double.tryParse(v?.toString() ?? '');
  static bool _asBool01(dynamic v) => v == 1 || v == true || v == '1' || v == 'true';

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
      codigoProyectoSii: json['codigo_proyecto_sii']?.toString(),
      centroId: _asIntOrNull(json['centro_id']),
      centroClave: json['centro_clave']?.toString(),
      codigoProyectoAnoFin: json['ano_fin']?.toString(), // <-- CORREGIDO
      creadorRpe: _asIntOrNull(json['creador_rpe'] ?? json['creado_por_rpe']),
      creadoPorNombre: json['creado_por_nombre']?.toString() ?? json['creador_nombre']?.toString(),
      tipoContratacion: json['tipo_contratacion']?.toString(),
      fechaIcm: json['fecha_icm']?.toString(),
      numeroIcm: json['numero_icm']?.toString(),
      fechaEnvioPmc: json['fecha_envio_pmc']?.toString(),
      importePmc: _asDoubleOrNull(json['importe_pmc']),
      atFechaSolicitudIcm: json['at_fecha_solicitud_icm']?.toString(),
      atOficioSolicitudIcm: json['at_oficio_solicitud_icm']?.toString(),
      plazoEntregaReal: json['plazo_entrega_real'] != null ? int.tryParse(json['plazo_entrega_real'].toString()) : null,
      vigenciaIcm: json['vigencia_icm'],
      fechaExpEstim: json['fecha_exp_estim']?.toString(),
      fechaEntregaExp: json['fecha_entrega_exp']?.toString(),
      fechaPublicacion: json['fecha_publicacion']?.toString(),
      numeroProcedimientoMsc: json['numero_procedimiento_msc']?.toString(),
      fechaPubliGAB: json['fecha_publi_GAB']?.toString(),
      fechaVisitaSitio: json['fecha_visita_sitio']?.toString(),
      fechaSesionAclaraciones: json['fecha_sesion_aclaraciones']?.toString(),
      fechaCancelacion: json['fecha_cancelacion']?.toString(),
      fechaDesierto: json['fecha_desierto']?.toString(),
    );
  }

  // Método para crear una copia con campos actualizados (útil para updates)
  Proyecto copyWith({
    int? id,
    String? nombre,
    int? departamentoId,
    int? estadoId,
    int? etapaId,
    bool? entregaSubida,
    int? monedaId,
    int? tipoProcedimientoId,
    int? codigoProyectoSiiId,
    double? presupuestoEstimado,
    String? numeroSolcon,
    double? importeAnticipo,
    String? adquisicionServicioObra,
    String? solicitudPAC,
    int? plazoEntregaDias,
    String? fechaEstudioNecesidades,
    String? fechaConclusionEstudio,
    String? fechaSolicitudICM,
    String? fechaAperturaTecnica,
    String? fechaAperturaEconomica,
    String? fechaFallo,
    String? fechaFormalizacionContrato,
    String? fechaPago,
    String? numeroContrato,
    double? importeAdjudicado,
    double? anticipoOtorgado,
    String? observaciones,
    String? departamento,
    String? estado,
    String? etapa,
    String? tipoProcedimientoNombre,
    String? codigoProyectoSii,
    int? centroId,
    String? centroClave,
    String? codigoProyectoAnoFin,
    int? creadorRpe,
    String? creadoPorNombre,
    String? tipoContratacion,
    String? fechaIcm,
    String? numeroIcm,
    double? importePmc,
    String? fechaEnvioPmc,
    String? atFechaSolicitudIcm,
    String? atOficioSolicitudIcm,
    int? plazoEntregaReal,
    String? vigenciaIcm,
    String? fechaExpEstim,
    String? fechaEntregaExp,
    String? fechaPublicacion,
    String? numeroProcedimientoMsc,
    String? fechaPubliGAB,
    String? fechaVisitaSitio,
    String? fechaSesionAclaraciones,
    String? fechaCancelacion,
    String? fechaDesierto,
  }) {
    return Proyecto(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      departamentoId: departamentoId ?? this.departamentoId,
      estadoId: estadoId ?? this.estadoId,
      etapaId: etapaId ?? this.etapaId,
      entregaSubida: entregaSubida ?? this.entregaSubida,
      monedaId: monedaId ?? this.monedaId,
      tipoProcedimientoId: tipoProcedimientoId ?? this.tipoProcedimientoId,
      codigoProyectoSiiId: codigoProyectoSiiId ?? this.codigoProyectoSiiId,
      presupuestoEstimado: presupuestoEstimado ?? this.presupuestoEstimado,
      numeroSolcon: numeroSolcon ?? this.numeroSolcon,
      importeAnticipo: importeAnticipo ?? this.importeAnticipo,
      adquisicionServicioObra: adquisicionServicioObra ?? this.adquisicionServicioObra,
      solicitudPAC: solicitudPAC ?? this.solicitudPAC,
      plazoEntregaDias: plazoEntregaDias ?? this.plazoEntregaDias,
      fechaEstudioNecesidades: fechaEstudioNecesidades ?? this.fechaEstudioNecesidades,
      fechaConclusionEstudio: fechaConclusionEstudio ?? this.fechaConclusionEstudio,
      fechaSolicitudICM: fechaSolicitudICM ?? this.fechaSolicitudICM,
      fechaAperturaTecnica: fechaAperturaTecnica ?? this.fechaAperturaTecnica,
      fechaAperturaEconomica: fechaAperturaEconomica ?? this.fechaAperturaEconomica,
      fechaFallo: fechaFallo ?? this.fechaFallo,
      fechaFormalizacionContrato: fechaFormalizacionContrato ?? this.fechaFormalizacionContrato,
      fechaPago: fechaPago ?? this.fechaPago,
      numeroContrato: numeroContrato ?? this.numeroContrato,
      importeAdjudicado: importeAdjudicado ?? this.importeAdjudicado,
      anticipoOtorgado: anticipoOtorgado ?? this.anticipoOtorgado,
      observaciones: observaciones ?? this.observaciones,
      departamento: departamento ?? this.departamento,
      estado: estado ?? this.estado,
      etapa: etapa ?? this.etapa,
      tipoProcedimientoNombre: tipoProcedimientoNombre ?? this.tipoProcedimientoNombre,
      codigoProyectoSii: codigoProyectoSii ?? this.codigoProyectoSii,
      centroId: centroId ?? this.centroId,
      centroClave: centroClave ?? this.centroClave,
      codigoProyectoAnoFin: codigoProyectoAnoFin ?? this.codigoProyectoAnoFin,
      creadorRpe: creadorRpe ?? this.creadorRpe,
      creadoPorNombre: creadoPorNombre ?? this.creadoPorNombre,
      tipoContratacion: tipoContratacion ?? this.tipoContratacion,
      fechaIcm: fechaIcm ?? this.fechaIcm,
      numeroIcm: numeroIcm ?? this.numeroIcm,
      importePmc: importePmc ?? this.importePmc,
      fechaEnvioPmc: fechaEnvioPmc ?? this.fechaEnvioPmc,
      atFechaSolicitudIcm: atFechaSolicitudIcm ?? this.atFechaSolicitudIcm,
      atOficioSolicitudIcm: atOficioSolicitudIcm ?? this.atOficioSolicitudIcm,
      plazoEntregaReal: plazoEntregaReal ?? this.plazoEntregaReal,
      vigenciaIcm: vigenciaIcm ?? this.vigenciaIcm,
      fechaExpEstim: fechaExpEstim ?? this.fechaExpEstim,
      fechaEntregaExp: fechaEntregaExp ?? this.fechaEntregaExp,
      fechaPublicacion: fechaPublicacion ?? this.fechaPublicacion,
      numeroProcedimientoMsc: numeroProcedimientoMsc ?? this.numeroProcedimientoMsc,
      fechaPubliGAB: fechaPubliGAB ?? this.fechaPubliGAB,
      fechaVisitaSitio: fechaVisitaSitio ?? this.fechaVisitaSitio,
      fechaSesionAclaraciones: fechaSesionAclaraciones ?? this.fechaSesionAclaraciones,
      fechaCancelacion: fechaCancelacion ?? this.fechaCancelacion,
      fechaDesierto: fechaDesierto ?? this.fechaDesierto,
    );
  }
}