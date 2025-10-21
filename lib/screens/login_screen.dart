// lib/screens/login_screen.dart

import 'package:flutter/material.dart';
// Ya no necesitas 'dart:convert' ni 'package:http/http.dart' aquí
// import 'dart:convert';
// import 'package:http/http.dart' as http;

import 'dashboard_screen.dart';
import 'package:flutter_http_demo/services/push_notifications.dart'; // Mantén esta si la usas
import '../services/api_service.dart'; // <-- Importa ApiService
import '../models/usuario.dart';      // <-- Importa Usuario si es necesario

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  final ApiService _apiService = ApiService(); // <-- Crea una instancia de ApiService

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa correo y contraseña')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      // --- Cambio Principal: Usa ApiService.login ---
      final Usuario? usuario = await _apiService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
      // ---------------------------------------------

      // Si el login fue exitoso (usuario no es null)
      if (usuario != null) {
        // Registrar/actualizar token FCM (esto ya usa ApiService internamente si lo modificaste)
        try {
          await PushNotifications.instance.initForUser(rpe: usuario.rpe);
        } catch (e) {
          debugPrint('No se pudo registrar el token FCM: $e');
          // Opcional: Mostrar mensaje al usuario
        }

        if (!mounted) return;

        // Navega al Dashboard
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DashboardScreen(
              rpe: usuario.rpe,
              nombre: usuario.nombre,
              departamentoId: usuario.departamentoId,
              rol: usuario.rol,
            ),
          ),
        );
      } else {
        // Esto no debería ocurrir si ApiService.login maneja errores con excepciones
        throw Exception('Usuario no recibido tras intento de login');
      }

    } catch (e) {
      // Captura errores de ApiService.login o PushNotifications
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al iniciar sesión: ${e.toString()}')),
      );
    } finally {
      // Asegúrate de que _loading siempre se actualice
      if (mounted && _loading) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... el resto del widget build sigue igual ...
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: AutofillGroup(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Sabana de Proyectos', style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 24),

                  TextField(
                    controller: _emailController,
                    autofillHints: const [AutofillHints.username, AutofillHints.email],
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Correo',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    onSubmitted: (_) => _login(),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _passwordController,
                    autofillHints: const [AutofillHints.password],
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    onSubmitted: (_) => _login(),
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _login,
                      icon: _loading
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Icon(Icons.login),
                      label: Text(_loading ? 'Entrando...' : 'Entrar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}