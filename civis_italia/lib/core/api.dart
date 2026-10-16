import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.message, {this.status});

  final String message;
  final int? status;

  @override
  String toString() => message;
}

/// Parla con il server su Cloudflare. Tutti i messaggi d'errore sono già in italiano.
class ApiClient {
  ApiClient({required this.baseUrl, http.Client? client}) : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;
  String? token;

  /// Chiamata quando il server dice che l'accesso è scaduto.
  void Function()? onUnauthorized;

  Map<String, String> get authHeaders => token == null ? const {} : {'authorization': 'Bearer $token'};

  String pageUrl(String docId, int page) => '$baseUrl/v1/documents/$docId/pages/$page';

  Future<dynamic> _send(
    String method,
    String path, {
    Object? json,
    List<int>? bytes,
    String? contentType,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final req = http.Request(method, Uri.parse('$base$path'));
    req.headers.addAll(authHeaders);
    if (json != null) {
      req.headers['content-type'] = 'application/json';
      req.body = jsonEncode(json);
    } else if (bytes != null) {
      req.headers['content-type'] = contentType ?? 'application/octet-stream';
      req.bodyBytes = bytes;
    }

    http.Response res;
    try {
      final streamed = await _client.send(req).timeout(timeout);
      res = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw ApiException('Il server ci mette troppo a rispondere. Riprova.');
    } catch (_) {
      throw ApiException('Non riesco a collegarmi al server. Controlla la connessione e riprova.');
    }

    dynamic data;
    if (res.bodyBytes.isNotEmpty) {
      try {
        data = jsonDecode(utf8.decode(res.bodyBytes));
      } catch (_) {
        data = null;
      }
    }
    if (res.statusCode >= 400) {
      final msg = data is Map && data['error'] is String ? data['error'] as String : 'Errore del server (${res.statusCode}).';
      if (res.statusCode == 401 && token != null) onUnauthorized?.call();
      throw ApiException(msg, status: res.statusCode);
    }
    return data;
  }

  Map<String, dynamic> _map(dynamic d) => Map<String, dynamic>.from(d as Map);
  List<Map<String, dynamic>> _list(dynamic d) =>
      (d as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  // ---- accesso ----
  Future<Map<String, dynamic>> register(String email, String password, String name) async =>
      _map(await _send('POST', '/v1/auth/register', json: {'email': email, 'password': password, 'name': name}));

  Future<Map<String, dynamic>> login(String email, String password) async =>
      _map(await _send('POST', '/v1/auth/login', json: {'email': email, 'password': password}));

  Future<Map<String, dynamic>> me() async => _map(await _send('GET', '/v1/me'));

  Future<Map<String, dynamic>> updateName(String name) async =>
      _map(await _send('PATCH', '/v1/me', json: {'name': name}));

  Future<Map<String, dynamic>> exportAll() async => _map(await _send('GET', '/v1/me/export'));

  Future<void> deleteAccount() async => _send('DELETE', '/v1/me');

  // ---- documenti ----
  Future<List<Map<String, dynamic>>> documents() async => _list(await _send('GET', '/v1/documents'));

  Future<Map<String, dynamic>> document(String id) async => _map(await _send('GET', '/v1/documents/$id'));

  Future<Map<String, dynamic>> createDocument(String title, int pages) async =>
      _map(await _send('POST', '/v1/documents', json: {'title': title, 'pages': pages}));

  Future<void> uploadPage(String id, int page, List<int> bytes, {String contentType = 'image/jpeg'}) async {
    await _send('PUT', '/v1/documents/$id/pages/$page',
        bytes: bytes, contentType: contentType, timeout: const Duration(seconds: 90));
  }

  Future<Map<String, dynamic>> analyze(String id) async =>
      _map(await _send('POST', '/v1/documents/$id/analyze', timeout: const Duration(seconds: 150)));

  Future<Map<String, dynamic>> renameDocument(String id, String title) async =>
      _map(await _send('PATCH', '/v1/documents/$id', json: {'title': title}));

  Future<void> deleteDocument(String id) async => _send('DELETE', '/v1/documents/$id');

  // ---- scadenze ----
  Future<List<Map<String, dynamic>>> deadlines() async => _list(await _send('GET', '/v1/deadlines'));

  Future<Map<String, dynamic>> createDeadline(String title, String date, {String note = '', String? docId}) async =>
      _map(await _send('POST', '/v1/deadlines',
          json: {'title': title, 'date': date, 'note': note, if (docId != null) 'docId': docId}));

  Future<Map<String, dynamic>> updateDeadline(String id, Map<String, dynamic> fields) async =>
      _map(await _send('PATCH', '/v1/deadlines/$id', json: fields));

  Future<void> deleteDeadline(String id) async => _send('DELETE', '/v1/deadlines/$id');

  // ---- chat e bozze ----
  Future<String> chat(List<Map<String, String>> messages, {String? docId}) async {
    final r = _map(await _send('POST', '/v1/chat',
        json: {'messages': messages, if (docId != null) 'docId': docId}, timeout: const Duration(seconds: 120)));
    return r['reply'] as String;
  }

  Future<Map<String, dynamic>> draft(String docId, String kind, String purpose) async =>
      _map(await _send('POST', '/v1/drafts',
          json: {'docId': docId, 'kind': kind, 'purpose': purpose}, timeout: const Duration(seconds: 120)));
}
