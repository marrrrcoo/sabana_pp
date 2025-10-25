import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/proyecto_details_screen.dart';
import 'services/api_service.dart';
import 'services/push_notifications.dart';

// ⬇️ sesión persistida
import 'services/session_service.dart';
import 'models/usuario.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

/// Abre la pantalla de detalle a partir de un RemoteMessage (system notification)
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

  // Tap de notificaciones locales (foreground) desde PushNotifications
  PushNotifications.instance.onTap = (data) async {
    final id = int.tryParse('${data['proyecto_id'] ?? ''}');
    if (id == null) return;

    try {
      final proyecto = await ApiService().getProyectoById(id);
      navigatorKey.currentState?.push(MaterialPageRoute(
        builder: (_) => ProyectoDetailsScreen(proyecto: proyecto),
      ));
    } catch (e) {
      debugPrint('No se pudo abrir el proyecto $id: $e');
    }
  };

  // Handlers FCM (system notifications)
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  FirebaseMessaging.instance.getInitialMessage().then(_handleMessage);
  FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);

  // 🔐 Carga sesión existente (autologin)
  final Usuario? usuario = await SessionService.getUser();
  if (usuario != null) {
    // Re-registra token por si cambió / tras reinstalar
    try {
      await PushNotifications.instance.initForUser(rpe: usuario.rpe);
    } catch (e) {
      debugPrint('No se pudo registrar token al iniciar: $e');
    }
  }

  runApp(SabanaApp(initialUser: usuario));
}

class SabanaApp extends StatelessWidget {
  final Usuario? initialUser;
  const SabanaApp({super.key, this.initialUser});

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

      // 👇 Si hay sesión, entra directo; si no, al Login
      home: initialUser == null
          ? const LoginScreen()
          : DashboardScreen(
        rpe: initialUser!.rpe,
        nombre: initialUser!.nombre,
        departamentoId: initialUser!.departamentoId,
        rol: initialUser!.rol,
      ),
    );
  }
}
