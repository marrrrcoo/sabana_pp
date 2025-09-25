import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dashboard_screen.dart';

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

    final data = jsonDecode(response.body);

    if (data['error'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['error'])),
      );
      return;
    }

    final departamentoId = data['departamento_id'];
    final rpe = data['rpe'];
    final nombre = data['nombre'];

    if (departamentoId == 8) {
      // Admin → Dashboard con tabs
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardScreen(
            rpe: rpe,
            nombre: nombre,
            departamentoId: departamentoId,
            isAdmin: true, // indica que puede ver tab de usuarios
          ),
        ),
      );
    } else {
      // Usuario normal → Dashboard con solo tab Proyectos
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardScreen(
            rpe: rpe,
            nombre: nombre,
            departamentoId: departamentoId,
            isAdmin: false, // solo tab de proyectos
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
