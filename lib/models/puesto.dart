class Puesto {
  final int id;
  final String nombre;

  Puesto({required this.id, required this.nombre});

  factory Puesto.fromJson(Map<String, dynamic> json) {
    return Puesto(id: json['id'], nombre: json['nombre']);
  }
}
