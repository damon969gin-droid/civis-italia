import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api.dart';

/// Chi è collegato. Il token sta nel portachiavi del telefono (Keychain su iPhone,
/// Keystore su Android), mai in un file in chiaro.
class Session extends ChangeNotifier {
  Session(this.api);

  static const _tokenKey = 'civis_token';
  static const _userKey = 'civis_user';

  final ApiClient api;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  bool loaded = false;
  Map<String, dynamic>? user;

  /// Messaggio da mostrare nella schermata di accesso (per esempio "accesso scaduto").
  String? notice;

  bool get signedIn => api.token != null && user != null;
  String get name => (user?['name'] as String?) ?? '';
  String get email => (user?['email'] as String?) ?? '';

  Future<String?> _read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      return null;
    }
  }

  Future<void> _write(String key, String? value) async {
    try {
      if (value == null) {
        await _storage.delete(key: key);
      } else {
        await _storage.write(key: key, value: value);
      }
    } catch (_) {
      // Archivio non disponibile: l'accesso vale solo finché l'app è aperta.
    }
  }

  Future<void> restore() async {
    final token = await _read(_tokenKey);
    if (token != null) {
      api.token = token;
      final cached = await _read(_userKey);
      if (cached != null) {
        try {
          user = Map<String, dynamic>.from(jsonDecode(cached) as Map);
        } catch (_) {}
      }
      try {
        user = await api.me();
        await _write(_userKey, jsonEncode(user));
      } on ApiException catch (e) {
        if (e.status == 401) {
          await _clear();
        } else if (user == null) {
          // Senza rete e senza dati salvati non possiamo mostrare l'app: si riparte dall'accesso.
          api.token = null;
        }
      }
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> _store(Map<String, dynamic> r) async {
    api.token = r['token'] as String;
    user = Map<String, dynamic>.from(r['user'] as Map);
    notice = null;
    await _write(_tokenKey, api.token);
    await _write(_userKey, jsonEncode(user));
    notifyListeners();
  }

  Future<void> login(String email, String password) async => _store(await api.login(email, password));

  Future<void> register(String email, String password, String name) async =>
      _store(await api.register(email, password, name));

  Future<void> setName(String name) async {
    user = await api.updateName(name);
    await _write(_userKey, jsonEncode(user));
    notifyListeners();
  }

  Future<void> _clear() async {
    api.token = null;
    user = null;
    await _write(_tokenKey, null);
    await _write(_userKey, null);
  }

  Future<void> logout({String? message}) async {
    await _clear();
    notice = message;
    notifyListeners();
  }
}
