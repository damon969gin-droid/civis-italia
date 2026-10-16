import 'dart:convert';

import 'package:civis_italia/core/api.dart';
import 'package:civis_italia/core/format.dart';
import 'package:civis_italia/core/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _json(int status, Object body) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  test('login: legge token e utente', () async {
    final api = ApiClient(
      baseUrl: 'https://api.test',
      client: MockClient((req) async {
        expect(req.url.path, '/v1/auth/login');
        expect(jsonDecode(req.body), {'email': 'a@b.it', 'password': 'password1'});
        return _json(200, {'token': 'T', 'user': {'id': '1', 'email': 'a@b.it', 'name': 'Anna'}});
      }),
    );
    final r = await api.login('a@b.it', 'password1');
    expect(r['token'], 'T');
  });

  test('errore del server: messaggio in italiano e codice', () async {
    final api = ApiClient(
      baseUrl: 'https://api.test',
      client: MockClient((_) async => _json(401, {'error': 'Email o password non corrette.'})),
    );
    expect(
      api.login('a@b.it', 'x'),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Email o password non corrette.').having((e) => e.status, 'status', 401)),
    );
  });

  test('401 con un token attivo avvisa l\'app (accesso scaduto)', () async {
    var called = false;
    final api = ApiClient(
      baseUrl: 'https://api.test',
      client: MockClient((_) async => _json(401, {'error': 'Accesso scaduto.'})),
    )
      ..token = 'vecchio'
      ..onUnauthorized = () => called = true;
    await expectLater(api.documents(), throwsA(isA<ApiException>()));
    expect(called, isTrue);
  });

  test('senza rete: messaggio chiaro', () async {
    final api = ApiClient(
      baseUrl: 'https://api.test',
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    expect(api.documents(), throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('collegarmi'))));
  });

  test('invia il token e il caricamento di una pagina', () async {
    final api = ApiClient(
      baseUrl: 'https://api.test/',
      client: MockClient((req) async {
        expect(req.method, 'PUT');
        expect(req.url.toString(), 'https://api.test/v1/documents/d1/pages/2');
        expect(req.headers['authorization'], 'Bearer T');
        expect(req.headers['content-type'], 'image/jpeg');
        expect(req.bodyBytes, [1, 2, 3]);
        return _json(200, {'ok': true});
      }),
    )..token = 'T';
    await api.uploadPage('d1', 2, [1, 2, 3]);
  });

  test('formati: euro, date, giorni', () {
    expect(euro(1234.5), '€ 1.234,50');
    expect(euro(312.4), '€ 312,40');
    expect(itDate(DateTime(2026, 10, 6)), '6 ottobre 2026');
    expect(isoDay(DateTime(2026, 3, 5)), '2026-03-05');
    expect(parseDay('2026-12-16'), DateTime(2026, 12, 16));
    expect(relativeDays(DateTime.now()), 'oggi');
    expect(pagesLabel(1), '1 pagina');
    expect(pagesLabel(3), '3 pagine');
  });

  test('modelli: documento analizzato e scadenza', () {
    final d = DocItem.fromJson({
      'id': '1',
      'title': 'Cartella',
      'pages': 2,
      'status': 'analyzed',
      'createdAt': '2026-10-06T10:00:00.000Z',
      'analysis': {'priorita': 'alta'},
    });
    expect(d.isAnalyzed, isTrue);
    expect(d.analysis!['priorita'], 'alta');
    final bozza = DocItem.fromJson({'id': '2', 'title': 'X', 'pages': 1, 'status': 'draft', 'createdAt': '2026-10-06T10:00:00.000Z'});
    expect(bozza.isAnalyzed, isFalse);

    final s = DeadlineItem.fromJson({'id': '3', 'docId': null, 'title': 'IMU', 'date': '2026-12-16', 'note': '', 'done': false, 'auto': true});
    expect(s.date, DateTime(2026, 12, 16));
    expect(s.auto, isTrue);
  });
}
