import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_data.dart';
import '../../core/format.dart';
import '../../core/image_shrink.dart';
import '../../core/models.dart';
import '../../core/widgets.dart';
import '../documents/document_page.dart';
import 'scan_service.dart';

/// Apre la scansione e, a caricamento fatto, il documento con l'analisi in corso.
Future<void> openScan(BuildContext context) async {
  final nav = Navigator.of(context);
  final id = await nav.push<String>(MaterialPageRoute<String>(builder: (_) => const ScanPage()));
  if (id != null) {
    nav.push(MaterialPageRoute<void>(builder: (_) => DocumentPage(documentId: id, autoAnalyze: true)));
  }
}

/// Fotografa → controlla le pagine → carica nel tuo archivio privato.
class ScanPage extends StatefulWidget {
  const ScanPage({super.key, this.service});

  /// Iniettabile nei test.
  final ScanService? service;

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  late final ScanService _service = widget.service ?? ScanService();
  final TextEditingController _title = TextEditingController();
  ScanResult? _result;
  bool _busy = false;
  bool _uploaded = false;
  String? _status;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
  }

  @override
  void dispose() {
    _title.dispose();
    // Pagine scansionate ma non caricate: si cancellano dal telefono.
    final r = _result;
    if (r != null) _service.discard(r);
    super.dispose();
  }

  Future<void> _scan() async {
    final previous = _result;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await _service.scanDocument();
      if (!mounted) return;
      if (!res.isEmpty) {
        if (previous != null) await _service.discard(previous);
        setState(() {
          _result = res;
          if (_title.text.trim().isEmpty) _title.text = 'Documento del ${itDate(DateTime.now())}';
        });
      }
    } on ScanException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Qualcosa non ha funzionato. Riprova.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _upload() async {
    final r = _result;
    if (r == null) return;
    final scope = AppScope.of(context);
    final nav = Navigator.of(context);
    setState(() {
      _busy = true;
      _error = null;
      _status = 'Preparo il documento…';
    });
    try {
      final pages = <Uint8List>[];
      for (var i = 0; i < r.pagePaths.length; i++) {
        if (mounted) setState(() => _status = 'Preparo la pagina ${i + 1} di ${r.pagePaths.length}…');
        pages.add(await shrinkForUpload(File(r.pagePaths[i])));
      }
      final title = _title.text.trim().isEmpty ? 'Documento del ${itDate(DateTime.now())}' : _title.text.trim();
      final created = await scope.api.createDocument(title, pages.length);
      final id = created['id'] as String;
      scope.data.upsertDoc(DocItem.fromJson(created));
      for (var i = 0; i < pages.length; i++) {
        if (mounted) setState(() => _status = 'Carico la pagina ${i + 1} di ${pages.length}…');
        await scope.api.uploadPage(id, i + 1, pages[i], contentType: 'image/jpeg');
      }
      // Le pagine sono al sicuro sul server: via la copia dal telefono.
      _uploaded = true;
      await _service.discard(r);
      _result = null;
      nav.pop(id);
    } on ShrinkException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Non sono riuscito a caricare il documento. Riprova.');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _status = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;
    final result = _result;

    return Scaffold(
      appBar: AppBar(title: const Text('Nuovo documento')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (result == null)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.document_scanner_outlined, size: 88, color: scheme.primary),
                        const SizedBox(height: 16),
                        Text(
                          'Fotografa una lettera, una cartella o una PEC',
                          textAlign: TextAlign.center,
                          style: t.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Appoggia il foglio su un piano, con buona luce. L\'app trova i bordi da sola.',
                          textAlign: TextAlign.center,
                          style: t.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        if (kIsWeb) ...[
                          const SizedBox(height: 12),
                          Text(
                            'La fotocamera funziona solo sull\'app per Android e iPhone, non nel browser.',
                            textAlign: TextAlign.center,
                            style: t.textTheme.bodyMedium?.copyWith(color: scheme.error),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              else ...[
                TextField(
                  controller: _title,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Nome del documento'),
                ),
                const SizedBox(height: 12),
                Text(pagesLabel(result.pageCount), style: t.textTheme.titleMedium),
                const SizedBox(height: 8),
                Expanded(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.72,
                    ),
                    itemCount: result.pageCount,
                    itemBuilder: (_, i) => Semantics(
                      label: 'Pagina ${i + 1} di ${result.pageCount}',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(File(result.pagePaths[i]), fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ),
              ],
              if (_status != null)
                Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_status!, textAlign: TextAlign.center)),
              if (_error != null)
                Padding(padding: const EdgeInsets.only(bottom: 12), child: ErrorBanner(message: _error!)),
              if (result != null) ...[
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _busy || _uploaded ? null : _upload,
                    child: const Text('Salva e spiegami il documento'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: _busy ? null : _scan,
                    child: const Text('Rifai la scansione'),
                  ),
                ),
              ] else
                SizedBox(
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _scan,
                    icon: _busy
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.photo_camera_outlined),
                    label: const Text('Fotografa un documento'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
