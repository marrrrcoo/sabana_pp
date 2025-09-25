class Usuario {
  final int rpe;
  final String nombre;
  final int departamentoId;
  final int puestoId;
  final String correo;
  final String password;

  Usuario({
    required this.rpe,
    required this.nombre,
    required this.departamentoId,
    required this.puestoId,
    required this.correo,
    required this.password,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      rpe: json['rpe'],
      nombre: json['nombre'],
      departamentoId: json['departamento_id'],
      puestoId: json['puesto_id'],
      correo: json['correo'],
      password: json['password'],
    );
  }
}
