class CodigoProyecto {
  final int id;
  final String codigoProyectoSii;
  final int ano;  // Cambié "año" por "ano"

  CodigoProyecto({
    required this.id,
    required this.codigoProyectoSii,
    required this.ano,  // Cambié "año" por "ano"
  });

  // Método para convertir un JSON en un objeto CodigoProyecto
  factory CodigoProyecto.fromJson(Map<String, dynamic> json) {
    return CodigoProyecto(
      id: json['id'],
      codigoProyectoSii: json['codigo_proyecto_sii'],
      ano: json['ano'],  // Cambié "año" por "ano"
    );
  }

  // Método para convertir un objeto CodigoProyecto en un JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'codigo_proyecto_sii': codigoProyectoSii,
      'ano': ano,  // Cambié "año" por "ano"
    };
  }
}
