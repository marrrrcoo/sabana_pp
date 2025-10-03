import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;

/// Handler de mensajes en background (requerido por FCM)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Si necesitas inicializar Firebase aquí, hazlo, pero con firebase_core 4.x
  // lo normal es que NO sea necesario si solo logueas/manejas data.
  // await Firebase.initializeApp(); // <-- solo si tu app lo requiere aquí
  debugPrint('BG message: ${message.messageId} data=${message.data}');
}

class PushNotifications {
  PushNotifications._();
  static final PushNotifications instance = PushNotifications._();

  final FirebaseMessaging _fm = FirebaseMessaging.instance;
  String? _currentToken;
  int? _currentRpe;

  /// Llama esto tras el login (cuando ya tienes el RPE del usuario)
  Future<void> initForUser({required int rpe}) async {
    _currentRpe = rpe;

    // Android 13+ (permiso de notificaciones). En Android no es estrictamente necesario,
    // pero pedirlo no hace daño y habilita la notificación del sistema si es requerido.
    await _fm.requestPermission();

    // Manejo background
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Token actual
    _currentToken = await _fm.getToken();
    if (_currentToken != null) {
      await _registerTokenWithBackend(rpe: rpe, token: _currentToken!);
      debugPrint('FCM token: $_currentToken');
    }

    // Si el token se refresca
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      _currentToken = newToken;
      if (_currentRpe != null) {
        await _registerTokenWithBackend(rpe: _currentRpe!, token: newToken);
      }
    });

    // App en foreground: aquí NO se muestra notificación de sistema.
    // Si algún día quieres banner en foreground, integra flutter_local_notifications
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('FG message: ${message.notification?.title} - ${message.notification?.body}'
          ' data=${message.data}');
      // Aquí podrías mostrar un Snackbar/Dialog si quieres feedback visual.
    });

    // Usuario toca la notificación y abre la app
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('Notification tap: data=${message.data}');
      // Ejemplo: si mandas { "proyecto_id": "123" } en data,
      // aquí podrías navegar a la pantalla de detalles.
      // Navigator.of(context).push(...); <-- necesitas contexto, haz un callback global si quieres.
    });
  }

  Future<void> _registerTokenWithBackend({
    required int rpe,
    required String token,
  }) async {
    try {
      final resp = await http.post(
        Uri.parse('http://10.0.2.2:3000/devices/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'rpe': rpe, 'token': token, 'platform': Platform.operatingSystem}),
      );
      if (resp.statusCode != 200) {
        debugPrint('No se pudo registrar token: ${resp.statusCode} ${resp.body}');
      }
    } catch (e) {
      debugPrint('Error registrando token: $e');
    }
  }
}
