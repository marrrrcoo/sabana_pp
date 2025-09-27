class Proyecto {
  final int id;
  final String nombre;
  final int departamentoId;
  final int estadoId;
  final int etapaId;
  final double? presupuestoEstimado;
  final int? monedaId;
  final int? tipoProcedimientoId;
  final String? numeroSolcon;
  final int? codigoProyectoSiiId;  // Cambiado a ID del código de proyecto
  final double? importeAnticipo;
  final String? adquisicionServicioObra;
  final String? solicitudPAC;
  final String? plazoEntrega;
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

  // Nombres desnormalizados del JOIN
  final String? departamento;
  final String? estado;
  final String? etapa;

  Proyecto({
    required this.id,
    required this.nombre,
    required this.departamentoId,
    required this.estadoId,
    required this.etapaId,
    this.presupuestoEstimado,
    this.monedaId,
    this.tipoProcedimientoId,
    this.numeroSolcon,
    this.codigoProyectoSiiId,  // Ahora solo tenemos el ID del código
    this.importeAnticipo,
    this.adquisicionServicioObra,
    this.solicitudPAC,
    this.plazoEntrega,
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
  });

  factory Proyecto.fromJson(Map<String, dynamic> json) {
    return Proyecto(
      id: json['id'],
      nombre: json['nombre'],
      departamentoId: json['departamento_id'],
      estadoId: json['estado_id'],
      etapaId: json['etapa_id'],
      presupuestoEstimado: json['presupuesto_estimado'] != null
          ? double.tryParse(json['presupuesto_estimado'].toString())
          : null,
      monedaId: json['moneda_id'],
      tipoProcedimientoId: json['tipo_procedimiento_id'],
      numeroSolcon: json['numero_solcon'],
      codigoProyectoSiiId: json['codigo_proyecto_sii_id'],  // Usamos el ID del código de proyecto
      importeAnticipo: json['importe_anticipo'] != null
          ? double.tryParse(json['importe_anticipo'].toString())
          : null,
      adquisicionServicioObra: json['adquisicion_servicio_obra'],
      solicitudPAC: json['solicitud_pac'],
      plazoEntrega: json['plazo_entrega'],
      fechaEstudioNecesidades: json['fecha_estudio_necesidades'],
      fechaConclusionEstudio: json['fecha_conclusion_estudio'],
      fechaSolicitudICM: json['fecha_solicitud_icm'],
      fechaAperturaTecnica: json['fecha_apertura_tecnica'],
      fechaAperturaEconomica: json['fecha_apertura_economica'],
      fechaFallo: json['fecha_fallo'],
      fechaFormalizacionContrato: json['fecha_formalizacion_contrato'],
      fechaPago: json['fecha_pago'],
      numeroContrato: json['numero_contrato'],
      importeAdjudicado: json['importe_adjudicado'] != null
          ? double.tryParse(json['importe_adjudicado'].toString())
          : null,
      anticipoOtorgado: json['anticipo_otorgado'] != null
          ? double.tryParse(json['anticipo_otorgado'].toString())
          : null,
      observaciones: json['observaciones'],
      departamento: json['departamento'],
      estado: json['estado'],
      etapa: json['etapa'],
    );
  }
}
