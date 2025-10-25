class Usuario {
  final int rpe;
  final String nombre;
  final int departamentoId;
  final int puestoId;
  final String correo;
  final String password;
  final String rol;

  Usuario({
    required this.rpe,
    required this.nombre,
    required this.departamentoId,
    required this.puestoId,
    required this.correo,
    required this.password,
    required this.rol,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) {
    int _toInt(dynamic v) =>
        v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;

    return Usuario(
      rpe: _toInt(json['rpe']),
      nombre: json['nombre']?.toString() ?? '',
      departamentoId: _toInt(json['departamento_id'] ?? json['departamentoId']),
      puestoId: _toInt(json['puesto_id'] ?? json['puestoId']),
      correo: json['correo']?.toString() ?? '',
      // Si falta en el storage, usa vacío para no tronar.
      password: json['password']?.toString() ?? '',
      rol: json['rol']?.toString() ?? 'user',
    );
  }

  /// por seguridad NO guardamos `password` en disco.
  Map<String, dynamic> toJson() {
    return {
      'rpe': rpe,
      'nombre': nombre,
      'departamento_id': departamentoId,
      'puesto_id': puestoId,
      'correo': correo,
      // 'password': password,
      'rol': rol,
    };
  }
}
