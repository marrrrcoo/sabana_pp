import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Handler de mensajes en background (requerido por FCM)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('BG message: ${message.messageId} data=${message.data}');
}

/// Callback para abrir pantallas desde el toque a la notificación
typedef NotificationTapHandler = void Function(Map<String, dynamic> data);

class PushNotifications {
  PushNotifications._();
  static final PushNotifications instance = PushNotifications._();

  final FirebaseMessaging _fm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _fln = FlutterLocalNotificationsPlugin();

  // Canal Android (¡usa el mismo id en el backend!)
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance',
    'Notificaciones importantes',
    description: 'Alertas y recordatorios de proyectos',
    importance: Importance.max,
  );

  String? _currentToken;
  int? _currentRpe;

  /// Así te pasas el "tap" a tu UI/router
  NotificationTapHandler? onTap;

  Future<void> initForUser({required int rpe}) async {
    _currentRpe = rpe;

    // 1) Permisos
    await _fm.requestPermission();
    await _fm.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);

    // 2) Handlers FCM
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 3) Notificaciones locales
    await _initLocalNotifications();

    // 4) Token + registro en tu backend
    _currentToken = await _fm.getToken();
    if (_currentToken != null) {
      await _registerTokenWithBackend(rpe: rpe, token: _currentToken!);
      debugPrint('FCM token: $_currentToken');
    }
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      _currentToken = newToken;
      if (_currentRpe != null) {
        await _registerTokenWithBackend(rpe: _currentRpe!, token: newToken);
      }
    });

    // 5) Mensaje en FOREGROUND -> mostramos local
    FirebaseMessaging.onMessage.listen((message) async {
      debugPrint('FG message: ${message.notification?.title} - ${message.notification?.body} data=${message.data}');
      await _showLocalFromRemote(message);
    });

    // 6) Tap cuando la app estaba en background
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('Notification tap (FCM): data=${message.data}');
      onTap?.call(message.data);
    });

    // 7) App abierta DESDE una notificación (app terminada)
    final initialMessage = await _fm.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('Initial message: data=${initialMessage.data}');
      onTap?.call(initialMessage.data);
    }
  }

  Future<void> _initLocalNotifications() async {
    // Icono: usa el launcher por simplicidad
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

    await _fln.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (resp) {
        if (resp.payload case final p?) {
          try {
            final data = jsonDecode(p) as Map<String, dynamic>;
            onTap?.call(data);
          } catch (_) {}
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    await _fln
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  Future<void> _showLocalFromRemote(RemoteMessage m) async {
    final title = m.notification?.title ?? m.data['title']?.toString() ?? 'Notificación';
    final body  = m.notification?.body  ?? m.data['body']?.toString()  ?? '';

    final androidDetails = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      styleInformation: const BigTextStyleInformation(''),
    );
    const iosDetails = DarwinNotificationDetails();
    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    final payload = jsonEncode(<String, dynamic>{
      ...m.data,
      if (!m.data.containsKey('title')) 'title': title,
      if (!m.data.containsKey('body'))  'body': body,
    });

    await _fln.show(m.hashCode, title, body, details, payload: payload);
  }

  Future<void> _registerTokenWithBackend({
    required int rpe,
    required String token,
  }) async {
    try {
      // Lee BASE_URL del .env (con un fallback útil para emulador)
      final base = dotenv.env['BASE_URL'] ?? 'http://10.0.2.2:3000';
      final baseUrl = base.endsWith('/') ? base.substring(0, base.length - 1) : base;

      final resp = await http.post(
        Uri.parse('$baseUrl/devices/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'rpe': rpe,
          'token': token,
          'platform': Platform.operatingSystem,
        }),
      );

      if (resp.statusCode != 200) {
        debugPrint('No se pudo registrar token: ${resp.statusCode} ${resp.body}');
      }
    } catch (e) {
      debugPrint('Error registrando token: $e');
    }
  }
}

// Tap cuando la app está totalmente terminada (no navegues aquí)
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse resp) {
  debugPrint('Tap desde background: payload=${resp.payload}');
}
