import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // <-- nuevo
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'screens/login_screen.dart';
import 'screens/proyecto_details_screen.dart';
import 'services/api_service.dart';
import 'models/proyecto.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Necesario si abren la app desde estado terminado por una notificación
  await Firebase.initializeApp();
}

Future<void> _handleMessage(RemoteMessage? message) async {
  if (message == null) return;
  final idStr = message.data['proyecto_id']?.toString();
  final id = int.tryParse(idStr ?? '');
  if (id == null) return;

  try {
    final proyecto = await ApiService().getProyectoById(id);
    navigatorKey.currentState?.push(MaterialPageRoute(
      builder: (_) => ProyectoDetailsScreen(proyecto: proyecto),
    ));
  } catch (e) {
    debugPrint('No se pudo abrir el proyecto $id: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Si abrieron la app tocando una notificación estando terminada:
  FirebaseMessaging.instance.getInitialMessage().then(_handleMessage);

  // Si la abren desde background:
  FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);

  runApp(const SabanaApp());
}

class SabanaApp extends StatelessWidget {
  const SabanaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Sabana de Proyectos',


      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'MX'),
        Locale('es'),
        Locale('en'),
      ],
      locale: const Locale('es', 'MX'),

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}
