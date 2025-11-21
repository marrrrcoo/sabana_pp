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
  debugPrint('🎯 BG Notification: ${message.data}');
}

/// Maneja la lógica de navegación y permisos para un proyecto de notificación.
Future<void> _handleNotificationNavigationWithPermissionCheck(int proyectoId) async {
  debugPrint('🚀 INICIANDO NAVEGACIÓN DESDE NOTIFICACIÓN - Proyecto: $proyectoId');

  // 1. Obtener el usuario actual de la sesión
  final usuario = await SessionService.getUser();

  if (usuario == null) {
    debugPrint('Notificación recibida sin sesión. Abriendo LoginScreen.');
    return;
  }

  debugPrint('👤 Usuario de sesión: ${usuario.rpe} - ${usuario.rol} - Dept: ${usuario.departamentoId}');

  Proyecto? proyecto;
  try {
    // Usar ApiService con todos los parámetros del usuario
    final api = ApiService(
      actorRpe: usuario.rpe,
      actorRol: usuario.rol,
    );
    proyecto = await api.getProyectoById(proyectoId);
    debugPrint('📦 Proyecto cargado: ${proyecto.nombre} - Etapa: ${proyecto.etapa} - Estado: ${proyecto.estado}');
  } catch (e) {
    debugPrint('❌ Error al buscar proyecto $proyectoId desde notificación: $e');

    // Mostrar error al usuario
    if (navigatorKey.currentState?.context != null) {
      final context = navigatorKey.currentState!.context;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar proyecto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    return;
  }

  // 2. Verificar Permisos - LÓGICA SIMPLIFICADA TEMPORALMENTE
  bool tienePermiso = _verificarPermisosUsuario(usuario, proyecto);
  debugPrint('🔐 Usuario ${usuario.rpe} tiene permiso: $tienePermiso');

  // 3. Navegar con TODOS los parámetros requeridos
  if (tienePermiso) {
    // Esperar a que el navigator esté listo
    if (navigatorKey.currentState == null) {
      await Future.delayed(const Duration(milliseconds: 200));
    }

    debugPrint('📍 Navegando a ProyectoDetailsScreen...');
    navigatorKey.currentState?.push(MaterialPageRoute(
      builder: (_) => ProyectoDetailsScreen(
        proyecto: proyecto!,
        actorRpe: usuario.rpe,
        actorRol: usuario.rol,
        actorDepartamentoId: usuario.departamentoId,

        // PARÁMETROS CRÍTICOS:
        canEdit: _puedeEditarProyecto(usuario, proyecto),
        canEditTipoProcedimiento: usuario.departamentoId == 10, // Abastecimientos
      ),
    ));
  } else {
    debugPrint('❌ Usuario NO tiene permisos para este proyecto');
    if (navigatorKey.currentState == null) {
      await Future.delayed(const Duration(milliseconds: 200));
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

// ✅ FUNCIÓN SIMPLIFICADA: Verificación de permisos
bool _verificarPermisosUsuario(Usuario usuario, Proyecto proyecto) {
  final rol = usuario.rol.toLowerCase();

  // Admins y Viewers pueden ver todos los proyectos
  if (rol == 'admin' || rol == 'viewer') {
    return true;
  }

  // Usuarios normales - LÓGICA TEMPORAL SIMPLIFICADA
  if (rol == 'user') {
    // TEMPORAL: Permitir acceso mientras arreglamos las notificaciones
    debugPrint('✅ Acceso temporal permitido para usuario normal');
    return true;

    // LÓGICA ORIGINAL (comentada temporalmente):
    // if (usuario.departamentoId == 10) return true; // Abastecimientos
    // if (usuario.departamentoId == 9) return true;  // DIAM
    // return usuario.departamentoId == proyecto.departamentoId;
  }

  return false;
}

// ✅ Función para determinar si puede editar
bool _puedeEditarProyecto(Usuario usuario, Proyecto proyecto) {
  if (usuario.rol == 'admin') return true;
  if (usuario.rol == 'viewer') return false;

  // Usuario normal - LÓGICA TEMPORAL SIMPLIFICADA
  return usuario.rol == 'user';
}

/// Abre la pantalla de detalle a partir de un RemoteMessage
Future<void> _handleMessage(RemoteMessage? message) async {
  if (message == null) return;

  debugPrint('🎯 NOTIFICACIÓN RECIBIDA - Proyecto ID: ${message.data['proyecto_id']}');
  debugPrint('📱 Datos completos: ${message.data}');

  final idStr = message.data['proyecto_id']?.toString();
  final id = int.tryParse(idStr ?? '');
  if (id == null) return;

  // Espera un momento para que 'main()' termine de cargar la UI inicial
  await Future.delayed(const Duration(milliseconds: 800));

  // Llama a la función centralizada
  await _handleNotificationNavigationWithPermissionCheck(id);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp();

  // Carga sesión existente
  final Usuario? usuario = await SessionService.getUser();
  debugPrint('👤 MAIN - Usuario de sesión: ${usuario?.rpe}');

  // Configurar notificaciones SOLO si hay usuario
  if (usuario != null) {
    // ELIMINAR: No configurar onTap en PushNotifications
    // SOLO inicializar para token y notificaciones en foreground
    try {
      await PushNotifications.instance.initForUser(rpe: usuario.rpe);
      debugPrint('✅ Notificaciones inicializadas para usuario: ${usuario.rpe}');
    } catch (e) {
      debugPrint('❌ No se pudo registrar token al iniciar: $e');
    }
  }

  // SOLO handlers FCM nativos - UNIFICADO
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Handler para cuando la app está cerrada
  FirebaseMessaging.instance.getInitialMessage().then((message) async {
    if (message != null) {
      debugPrint('🚀 INITIAL MESSAGE: ${message.data}');
      await Future.delayed(const Duration(milliseconds: 1000));
      await _handleMessage(message);
    }
  });

  // Handler para cuando la app está en background
  FirebaseMessaging.onMessageOpenedApp.listen((message) async {
    debugPrint('📱 ON MESSAGE OPENED APP: ${message.data}');
    await _handleMessage(message);
  });

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