// lib/services/session_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/usuario.dart';

class SessionService {
  static const _kUserKey = 'session_user';

  static Future<void> saveUser(Usuario u) async {
    final sp = await SharedPreferences.getInstance();
    // Asegúrate de que Usuario tenga toJson(); si no, arma tu propio Map.
    await sp.setString(_kUserKey, jsonEncode(u.toJson()));
  }

  static Future<Usuario?> getUser() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kUserKey);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return Usuario.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> isLoggedIn() async => (await getUser()) != null;

  static Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kUserKey);
  }
}
