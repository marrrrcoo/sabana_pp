import 'package:flutter/material.dart';
import '../services/session_service.dart';
import '../main.dart';
import '../screens/login_screen.dart';

class LogoutButton extends StatelessWidget {
  const LogoutButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Cerrar sesión',
      icon: const Icon(Icons.logout, color: Colors.red),
      onPressed: () async {
        await SessionService.clear();
        // Opcional: también borrar token FCM
        // try { await FirebaseMessaging.instance.deleteToken(); } catch (_) {}

        // Limpia el stack y vuelve al Login
        if (navigatorKey.currentState != null) {
          navigatorKey.currentState!.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
          );
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
          );
        }
      },
    );
  }
}
