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

// sesión persistida
import 'services/session_service.dart';
import 'models/proyecto.dart';
import 'models/usuario.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

/// Maneja la lógica de navegación y permisos para un proyecto de notificación.
Future<void> _handleNotificationNavigationWithPermissionCheck(int proyectoId) async {
  // 1. Obtener el usuario actual de la sesión
  final usuario = await SessionService.getUser();

  // Si no hay sesión, la app ya está (o estará) en LoginScreen.
  if (usuario == null) {
    debugPrint('Notificación recibida sin sesión. Abriendo LoginScreen.');
    return;
  }

  Proyecto? proyecto;
  try {
    // 2. Obtener el proyecto al que apunta la notificación
    proyecto = await ApiService(
      // Usamos el RPE/Rol del usuario actual para la llamada
      actorRpe: usuario.rpe,
      actorRol: usuario.rol,
    ).getProyectoById(proyectoId);

  } catch (e) {
    debugPrint('Error al buscar proyecto $proyectoId desde notificación: $e');
    // Si el proyecto no existe o falla la red, no hacemos nada.
    return;
  }

  // 3. Verificar Permisos
  bool tienePermiso = false;
  final rol = usuario.rol.toLowerCase();

  // Admins y Viewers pueden ver todos los proyectos
  if (rol == 'admin' || rol == 'viewer') {
    tienePermiso = true;
  }
  // Los 'user' solo pueden ver proyectos de su propio departamento
  else if (rol == 'user') {
    if (usuario.departamentoId == proyecto.departamentoId) {
      tienePermiso = true;
    }
  }

  // 4. Actuar según el permiso
  if (tienePermiso) {
    // Si tiene permiso, navegar a la pantalla de detalles
    // Aseguramos que el navigatorKey esté listo
    if (navigatorKey.currentState == null) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    navigatorKey.currentState?.push(MaterialPageRoute(
      builder: (_) => ProyectoDetailsScreen(
        proyecto: proyecto!,
        // Pasamos el contexto del usuario actual a la pantalla
        actorRpe: usuario.rpe,
        actorRol: usuario.rol,
        actorDepartamentoId: usuario.departamentoId,
        // (Los permisos de edición se calculan dentro de ProyectoDetailsScreen)
      ),
    ));
  } else {
    // Si NO tiene permiso, mostrar un mensaje de error
    // Aseguramos que el navigatorKey y su contexto existan
    if (navigatorKey.currentState == null) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    final context = navigatorKey.currentState?.context;
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No tienes permisos para ver este proyecto.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

/// Abre la pantalla de detalle a partir de un RemoteMessage (system notification)
// (Reemplaza la función _handleMessage existente en lib/main.dart)

Future<void> _handleMessage(RemoteMessage? message) async {
  if (message == null) return;
  final idStr = message.data['proyecto_id']?.toString();
  final id = int.tryParse(idStr ?? '');
  if (id == null) return;

  // Espera un momento para que 'main()' termine de cargar la UI inicial
  await Future.delayed(const Duration(milliseconds: 500));

  // Llama a la nueva función centralizada
  await _handleNotificationNavigationWithPermissionCheck(id);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp();

  // Tap de notificaciones locales (foreground) desde PushNotifications
  PushNotifications.instance.onTap = (data) async {
    final id = int.tryParse('${data['proyecto_id'] ?? ''}');
    if (id == null) return;

    // Llama a la nueva función centralizada
    await _handleNotificationNavigationWithPermissionCheck(id);
  };

  // Handlers FCM (system notifications)
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  FirebaseMessaging.instance.getInitialMessage().then(_handleMessage);
  FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);

  // Carga sesión existente (autologin)
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

      //  Si hay sesión, entra directo; si no, al Login
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
