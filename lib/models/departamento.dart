class Departamento {
  final int id;
  final String nombre;

  Departamento({required this.id, required this.nombre});

  factory Departamento.fromJson(Map<String, dynamic> json) {
    return Departamento(id: json['id'], nombre: json['nombre']);
  }
}
