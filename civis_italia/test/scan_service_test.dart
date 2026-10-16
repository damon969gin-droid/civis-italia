import 'package:civis_italia/features/scan/scan_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeScanner implements DocumentScanner {
  _FakeScanner({this.throws = false});
  final bool throws;

  @override
  Future<List<String>> scan({int maxPages = 12, bool allowGallery = true}) async {
    if (throws) throw Exception('camera denied');
    return const [];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('annullare la scansione restituisce un risultato vuoto', () async {
    final service = ScanService(scanner: _FakeScanner());
    final result = await service.scanDocument();
    expect(result.isEmpty, isTrue);
  });

  test('un errore della fotocamera diventa un messaggio comprensibile', () async {
    final service = ScanService(scanner: _FakeScanner(throws: true));
    expect(service.scanDocument(), throwsA(isA<ScanException>()));
  });

  test('buildPdf senza pagine segnala un errore', () async {
    final service = ScanService(scanner: _FakeScanner());
    expect(service.buildPdf(const ScanResult([])), throwsA(isA<ScanException>()));
  });
}
