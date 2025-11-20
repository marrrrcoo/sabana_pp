import 'package:flutter/material.dart';

import 'dashboard_screen.dart';
import 'package:flutter_http_demo/services/push_notifications.dart';
import '../services/api_service.dart';
import '../models/usuario.dart';
import '../services/session_service.dart';

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
  final ApiService _apiService = ApiService();

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa correo y contraseña')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final Usuario? usuario = await _apiService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (usuario != null) {
        // 1) Guarda sesión local (no persistimos password)
        await SessionService.saveUser(usuario);

        // 2) Registra/actualiza token FCM
        try {
          await PushNotifications.instance.initForUser(rpe: usuario.rpe);
        } catch (e) {
          debugPrint('No se pudo registrar el token FCM: $e');
        }

        if (!mounted) return;

        // 3) Navega al Dashboard
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
        throw Exception('Usuario no recibido tras intento de login');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al iniciar sesión: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted && _loading) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Usamos el color primario para dar identidad a los elementos
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      // Color de fondo ligeramente gris para que resalten los inputs (opcional)
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Login'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView( // Evita error de overflow en pantallas chicas
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Sabana de Proyectos',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 25),

                // 2. Imagen limpia (Sin bordes forzados)
                // Si la imagen tiene fondo transparente, se verá integrada perfectamente.
                Container(
                  height: 320, // Altura fija para mantener consistencia
                  decoration: BoxDecoration(
                    // Opcional: Una sombra sutil DETRÁS de la imagen para profundidad
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.1),
                        blurRadius: 60,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/LOGO2.png',
                    fit: BoxFit.contain, // Muestra la imagen completa sin recortar
                  ),
                ),

                const SizedBox(height: 30),

                // 3. Inputs Estilizados
                TextField(
                  controller: _emailController,
                  autofillHints: const [AutofillHints.username, AutofillHints.email],
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Correo Electrónico',
                    prefixIcon: Icon(Icons.email_outlined, color: primaryColor),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none, // Sin borde negro duro
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: primaryColor, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onSubmitted: (_) => _login(),
                ),

                const SizedBox(height: 16),

                TextField(
                  controller: _passwordController,
                  autofillHints: const [AutofillHints.password],
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: Icon(Icons.lock_outline, color: primaryColor),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: primaryColor, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onSubmitted: (_) => _login(),
                ),

                const SizedBox(height: 32),

                // 4. Botón Grande y Moderno
                SizedBox(
                  width: double.infinity,
                  height: 55, // Botón más alto
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                        : const Text(
                      'Iniciar Sesión',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
