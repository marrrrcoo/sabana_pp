class Etapa {
  final int id;
  final String nombre;

  Etapa({required this.id, required this.nombre});

  factory Etapa.fromJson(Map<String, dynamic> json) {
    return Etapa(
      id: json['id'],
      nombre: json['nombre'],
    );
  }
}
