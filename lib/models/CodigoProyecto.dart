class CodigoProyecto {
  final int id;
  final String codigoProyectoSii;
  final String? anoInicio; // Cambiado a String
  final String? anoFin;    // Cambiado a String

  CodigoProyecto({
    required this.id,
    required this.codigoProyectoSii,
    this.anoInicio,
    this.anoFin,
  });

  factory CodigoProyecto.fromJson(Map<String, dynamic> json) {
    return CodigoProyecto(
      id: json['id'],
      codigoProyectoSii: json['codigo_proyecto_sii'],
      anoInicio: json['ano_inicio']?.toString(),
      anoFin: json['ano_fin']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'codigo_proyecto_sii': codigoProyectoSii,
      'ano_inicio': anoInicio,
      'ano_fin': anoFin,
    };
  }
}