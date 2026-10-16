import 'dart:io';

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Risultato di una scansione: le pagine sono file JPEG nella cartella
/// privata dell'app. In seguito verranno cifrate nel vault (vedi piano, 7.5).
class ScanResult {
  const ScanResult(this.pagePaths);

  final List<String> pagePaths;

  bool get isEmpty => pagePaths.isEmpty;
  int get pageCount => pagePaths.length;
}

/// Astrazione sullo scanner di sistema, così la schermata si può testare
/// senza fotocamera.
abstract class DocumentScanner {
  /// Restituisce i percorsi delle pagine, oppure lista vuota se l'utente annulla.
  Future<List<String>> scan({int maxPages = 12, bool allowGallery = true});
}

class NativeDocumentScanner implements DocumentScanner {
  @override
  Future<List<String>> scan({int maxPages = 12, bool allowGallery = true}) async {
    final pictures = await CunningDocumentScanner.getPictures(
      noOfPages: maxPages,
      isGalleryImportAllowed: allowGallery,
    );
    return pictures ?? const [];
  }
}

class ScanException implements Exception {
  ScanException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ScanService {
  ScanService({DocumentScanner? scanner}) : _scanner = scanner ?? NativeDocumentScanner();

  final DocumentScanner _scanner;

  /// Apre lo scanner e copia le pagine in una cartella privata dell'app.
  /// Se l'utente annulla, restituisce un risultato vuoto.
  Future<ScanResult> scanDocument() async {
    final List<String> temp;
    try {
      temp = await _scanner.scan();
    } catch (_) {
      throw ScanException(
        'Non riesco ad aprire la fotocamera. Controlla che l\'app abbia il permesso di usarla.',
      );
    }
    if (temp.isEmpty) return const ScanResult([]);

    final dir = await _workDir();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final saved = <String>[];
    for (var i = 0; i < temp.length; i++) {
      final dest = p.join(dir.path, 'scan_${stamp}_${i + 1}.jpg');
      await File(temp[i]).copy(dest);
      saved.add(dest);
    }
    return ScanResult(saved);
  }

  /// Unisce le pagine in un unico PDF A4 (per anteprima, invio e archivio).
  Future<File> buildPdf(ScanResult result) async {
    if (result.isEmpty) throw ScanException('Nessuna pagina da convertire.');
    final doc = pw.Document();
    for (final path in result.pagePaths) {
      final bytes = await File(path).readAsBytes();
      final image = pw.MemoryImage(bytes);
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
        ),
      );
    }
    final dir = await _workDir();
    final out = File(p.join(dir.path, 'documento_${DateTime.now().millisecondsSinceEpoch}.pdf'));
    await out.writeAsBytes(await doc.save());
    return out;
  }

  /// Elimina i file di lavoro di una scansione.
  Future<void> discard(ScanResult result) async {
    for (final path in result.pagePaths) {
      final f = File(path);
      if (await f.exists()) await f.delete();
    }
  }

  Future<Directory> _workDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'scans'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
}
