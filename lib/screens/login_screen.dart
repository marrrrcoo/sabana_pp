import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'dashboard_screen.dart';
// registra el token en tu backend
import 'package:flutter_http_demo/services/push_notifications.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _loading = false;

  Future<void> _login() async {
    setState(() => _loading = true);

    final url = Uri.parse('http://10.0.2.2:3000/login');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'correo': _emailController.text,
        'password': _passwordController.text,
      }),
    );

    setState(() => _loading = false);

    // Si el backend devolviera algo que no es JSON válido, evitamos crash
    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Respuesta inválida del servidor')),
      );
      return;
    }

    if (data['error'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['error'].toString())),
      );
      return;
    }

    final int departamentoId = data['departamento_id'] as int;
    final int rpe = data['rpe'] as int;
    final String nombre = data['nombre'] as String;

    // inicializa FCM para este usuario y registra el token en tu backend
    try {
      await PushNotifications.instance.initForUser(rpe: rpe);
    } catch (e) {
      // No bloquees el login si falla el registro del token
      debugPrint('No se pudo registrar el token FCM: $e');
    }

    if (!mounted) return;

    // Navegación
    if (departamentoId == 8) {
      // Admin → Dashboard con tabs
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardScreen(
            rpe: rpe,
            nombre: nombre,
            departamentoId: departamentoId,
            isAdmin: true,
          ),
        ),
      );
    } else {
      // Usuario normal - Dashboard con solo tab Proyectos
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardScreen(
            rpe: rpe,
            nombre: nombre,
            departamentoId: departamentoId,
            isAdmin: false,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Correo'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Contraseña'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loading ? null : _login,
              child: _loading
                  ? const CircularProgressIndicator()
                  : const Text('Entrar'),
            ),
          ],
        ),
      ),
    );
  }
}
