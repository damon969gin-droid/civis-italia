import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/app_data.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/widgets.dart';
import '../chat/chat_page.dart';
import '../deadlines/deadlines_tab.dart';
import '../draft/draft_page.dart';

class DocumentPage extends StatefulWidget {
  const DocumentPage({super.key, required this.documentId, this.autoAnalyze = false});

  final String documentId;

  /// Avvia subito la lettura (dopo una scansione appena caricata).
  final bool autoAnalyze;

  @override
  State<DocumentPage> createState() => _DocumentPageState();
}

class _DocumentPageState extends State<DocumentPage> {
  bool _analyzing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.autoAnalyze) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final doc = AppScope.of(context).data.docById(widget.documentId);
        if (doc != null && !doc.isAnalyzed) _analyze();
      });
    }
  }

  Future<void> _analyze() async {
    final scope = AppScope.of(context);
    setState(() {
      _analyzing = true;
      _error = null;
    });
    try {
      final r = await scope.api.analyze(widget.documentId);
      scope.data.upsertDoc(DocItem.fromJson(r));
      await scope.data.refresh(); // le scadenze trovate sono state create dal server
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
      await scope.data.refresh();
    } catch (_) {
      if (mounted) setState(() => _error = 'Non sono riuscito a leggere il documento. Riprova.');
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  Future<void> _rename(DocItem doc) async {
    final scope = AppScope.of(context);
    final controller = TextEditingController(text: doc.title);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rinomina documento'),
        content: TextField(controller: controller, autofocus: true, textCapitalization: TextCapitalization.sentences),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(controller.text.trim()), child: const Text('Salva')),
        ],
      ),
    );
    controller.dispose();
    if (result == null || result.isEmpty) return;
    try {
      final r = await scope.api.renameDocument(doc.id, result);
      scope.data.upsertDoc(DocItem.fromJson(r));
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message);
    }
  }

  Future<void> _delete(DocItem doc) async {
    final scope = AppScope.of(context);
    final nav = Navigator.of(context);
    final ok = await confirmDialog(
      context,
      title: 'Eliminare il documento?',
      text: 'Le foto e l\'analisi vengono cancellate dal server. Le scadenze che hai creato tu restano.',
      confirmLabel: 'Elimina',
      destructive: true,
    );
    if (!ok) return;
    try {
      await scope.data.deleteDoc(doc.id);
      nav.pop();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message);
    }
  }

  void _openPage(String url, Map<String, String> headers) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                child: Image.network(
                  url,
                  headers: headers,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Center(child: Text('Non riesco ad aprire questa pagina.')),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: IconButton.filledTonal(
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: const Icon(Icons.close),
                  tooltip: 'Chiudi',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ListenableBuilder(
      listenable: scope.data,
      builder: (context, _) {
        final doc = scope.data.docById(widget.documentId);
        if (doc == null) {
          return Scaffold(appBar: AppBar(), body: const Center(child: Text('Documento non trovato')));
        }
        final t = Theme.of(context);
        return Scaffold(
          appBar: AppBar(
            title: Text(doc.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            actions: [
              PopupMenuButton<String>(
                onSelected: (v) => v == 'rename' ? _rename(doc) : _delete(doc),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'rename', child: Text('Rinomina')),
                  PopupMenuItem(value: 'delete', child: Text('Elimina')),
                ],
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Aggiunto il ${itDate(doc.createdAt)} · ${pagesLabel(doc.pages)}',
                style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 150,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: doc.pages,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final url = scope.api.pageUrl(doc.id, i + 1);
                    return InkWell(
                      onTap: () => _openPage(url, scope.api.authHeaders),
                      child: RemotePage(url: url, headers: scope.api.authHeaders, width: 108, height: 150),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              if (_analyzing)
                const _Reading()
              else ...[
                if (_error != null) ...[ErrorBanner(message: _error!, onRetry: _analyze), const SizedBox(height: 12)],
                if (doc.isAnalyzed)
                  ..._analysisSections(context, doc)
                else if (doc.status == 'failed' && doc.analysis != null && _error == null)
                  ..._unreadable(context, doc)
                else if (_error == null)
                  _AnalyzeCard(onAnalyze: _analyze, failed: doc.status == 'failed'),
              ],
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: () => _delete(doc),
                style: TextButton.styleFrom(foregroundColor: t.colorScheme.error),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Elimina documento'),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _unreadable(BuildContext context, DocItem doc) {
    final summary = (doc.analysis?['riassunto'] as String?) ?? '';
    return [
      NoticeBox(
        icon: Icons.photo_camera_outlined,
        title: 'Non riesco a leggere questo documento',
        lines: [if (summary.isNotEmpty) summary, 'Prova a rifare la foto con più luce, con il foglio dritto e ben inquadrato.'],
      ),
      const SizedBox(height: 12),
      OutlinedButton(onPressed: _analyze, child: const Text('Riprova a leggerlo')),
    ];
  }

  List<Widget> _analysisSections(BuildContext context, DocItem doc) {
    final scope = AppScope.of(context);
    final a = doc.analysis!;
    final t = Theme.of(context);

    List<Map<String, dynamic>> list(String key) =>
        ((a[key] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    String? text(String key) {
      final v = a[key];
      return v is String && v.isNotEmpty ? v : null;
    }

    final fare = list('cosa_devi_fare');
    final scadenze = list('scadenze');
    final importi = list('importi');
    final necessari = ((a['documenti_necessari'] as List?) ?? const []).whereType<String>().toList();
    final contatti = list('contatti');
    final truffa = (a['sospetto_truffa'] as Map?)?.cast<String, dynamic>();
    final livello = (truffa?['livello'] as String?) ?? 'nessuno';
    final motiviTruffa = ((truffa?['motivi'] as List?) ?? const []).whereType<String>().toList();
    final prof = (a['consiglia_professionista'] as Map?)?.cast<String, dynamic>();
    final minuti = a['tempo_stimato_minuti'];
    final linked = scope.data.deadlines.where((d) => d.docId == doc.id).toList()
      ..sort((x, y) => x.date.compareTo(y.date));

    Widget gap() => const SizedBox(height: 12);

    return [
      Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          PriorityChip(a['priorita'] as String?),
          if (minuti is num) Chip(avatar: const Icon(Icons.timer_outlined, size: 18), label: Text('Circa ${minuti.round()} min'), visualDensity: VisualDensity.compact),
        ],
      ),
      if (text('motivo_priorita') != null) Text(text('motivo_priorita')!, style: t.textTheme.bodyMedium),
      gap(),
      if (a['da_controllare'] == true) ...[
        const NoticeBox(
          icon: Icons.visibility_outlined,
          title: 'Controlla con il foglio in mano',
          lines: ['Non sono del tutto sicuro di aver letto bene alcuni dati. Confronta importi e date con il documento.'],
        ),
        gap(),
      ],
      if (livello == 'medio' || livello == 'alto' || livello == 'basso') ...[
        NoticeBox(
          icon: Icons.shield_outlined,
          severe: livello != 'basso',
          title: livello == 'basso' ? 'Qualcosa da verificare' : 'Attenzione: potrebbe essere una truffa',
          lines: [...motiviTruffa, 'Prima di pagare, verifica il mittente sul sito ufficiale dell\'ente.'],
        ),
        gap(),
      ],
      if (prof?['valore'] == true) ...[
        NoticeBox(
          icon: Icons.support_agent_outlined,
          title: 'Conviene sentire un professionista',
          lines: [if (prof?['motivo'] is String) prof!['motivo'] as String],
        ),
        gap(),
      ],
      if (text('riassunto') != null) ...[
        SectionCard(title: 'Riassunto', icon: Icons.short_text, child: Text(text('riassunto')!)),
        gap(),
      ],
      if (text('cosa_significa') != null) ...[
        SectionCard(title: 'Cosa significa', icon: Icons.translate, child: Text(text('cosa_significa')!)),
        gap(),
      ],
      if (fare.isNotEmpty) ...[
        SectionCard(
          title: 'Cosa devi fare',
          icon: Icons.checklist,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final f in fare)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(f['obbligatoria'] == false ? Icons.radio_button_unchecked : Icons.check_box_outline_blank, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text('${f['azione']}${f['obbligatoria'] == false ? ' (facoltativo)' : ''}')),
                    ],
                  ),
                ),
            ],
          ),
        ),
        gap(),
      ],
      if (scadenze.isNotEmpty) ...[
        SectionCard(
          title: 'Entro quando',
          icon: Icons.event_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final s in scadenze)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text(
                    s['data'] is String
                        ? '${s['etichetta']}: ${itDate(parseDay(s['data'] as String))} (${relativeDays(parseDay(s['data'] as String))})'
                        : '${s['etichetta']}: ${s['regola'] ?? 'data non indicata'}',
                  ),
                ),
              if (linked.any((d) => d.auto))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Le date certe sono già nelle tue Scadenze.',
                      style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => showDeadlineEditor(context, docId: doc.id),
                  icon: const Icon(Icons.add),
                  label: const Text('Aggiungi una scadenza'),
                ),
              ),
            ],
          ),
        ),
        gap(),
      ],
      if (importi.isNotEmpty) ...[
        SectionCard(
          title: 'Quanto devi pagare',
          icon: Icons.euro,
          child: Column(
            children: [
              for (final i in importi)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(child: Text('${i['etichetta']}')),
                      Text(euro((i['valore'] as num)), style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        gap(),
      ],
      if (necessari.isNotEmpty) ...[
        SectionCard(
          title: 'Documenti necessari',
          icon: Icons.folder_copy_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final n in necessari) Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text('• $n'))],
          ),
        ),
        gap(),
      ],
      if (text('conseguenze_se_non_intervieni') != null) ...[
        SectionCard(
          title: 'Se non fai nulla',
          icon: Icons.warning_amber_outlined,
          child: Text(text('conseguenze_se_non_intervieni')!),
        ),
        gap(),
      ],
      if (contatti.isNotEmpty) ...[
        SectionCard(
          title: 'Chi contattare',
          icon: Icons.language,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final c in contatti)
                InkWell(
                  onTap: () => launchUrl(Uri.parse(c['sito'] as String), mode: LaunchMode.externalApplication),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(child: Text('${c['nome']}\n${c['sito']}')),
                        const Icon(Icons.open_in_new, size: 18),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        gap(),
      ],
      FilledButton.icon(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => ChatPage(docId: doc.id, docTitle: doc.title)),
        ),
        icon: const Icon(Icons.chat_bubble_outline),
        label: const Text('Fai una domanda su questo documento'),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DraftPage(doc: doc))),
        icon: const Icon(Icons.edit_note),
        label: const Text('Prepara una PEC, email o lettera'),
      ),
      const SizedBox(height: 16),
      Text(
        'Civis è un aiuto per capire i documenti: non sostituisce un commercialista, un CAF, un patronato o un avvocato. Controlla sempre i dati con il documento originale.',
        style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
      ),
    ];
  }
}

class _Reading extends StatelessWidget {
  const _Reading();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Sto leggendo il documento…', style: t.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Di solito bastano pochi secondi, fino a un minuto per più pagine.',
              textAlign: TextAlign.center,
              style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalyzeCard extends StatelessWidget {
  const _AnalyzeCard({required this.onAnalyze, required this.failed});

  final VoidCallback onAnalyze;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(failed ? 'La lettura non è andata a buon fine' : 'Documento salvato', style: t.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              failed ? 'Puoi riprovare: le pagine sono già nel tuo archivio.' : 'Vuoi che te lo spieghi?',
              style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: onAnalyze, child: Text(failed ? 'Riprova' : 'Spiegami il documento')),
          ],
        ),
      ),
    );
  }
}
