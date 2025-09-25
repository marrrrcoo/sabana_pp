import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const SabanaApp());
}

class SabanaApp extends StatelessWidget {
  const SabanaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sabana de Proyectos',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}
