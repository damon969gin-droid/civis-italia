import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api.dart';
import '../../core/app_data.dart';
import '../../core/models.dart';
import '../../core/widgets.dart';

/// Bozza di PEC, email o lettera: sempre modificabile, mai inviata da Civis.
class DraftPage extends StatefulWidget {
  const DraftPage({super.key, required this.doc});

  final DocItem doc;

  @override
  State<DraftPage> createState() => _DraftPageState();
}

class _DraftPageState extends State<DraftPage> {
  static const _kinds = {'pec': 'PEC', 'email': 'Email', 'lettera': 'Lettera'};
  static const _purposes = [
    'Chiedere la rateizzazione',
    'Chiedere chiarimenti',
    'Contestare l\'importo',
    'Chiedere l\'annullamento (autotutela)',
  ];

  final _purpose = TextEditingController();
  final _subject = TextEditingController();
  final _body = TextEditingController();
  String _kind = 'pec';
  bool _busy = false;
  bool _ready = false;
  String? _error;
  String? _warning;
  List<String> _attachments = [];

  @override
  void dispose() {
    _purpose.dispose();
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final purpose = _purpose.text.trim();
    if (purpose.isEmpty) {
      setState(() => _error = 'Scrivi cosa vuoi ottenere.');
      return;
    }
    final api = AppScope.of(context).api;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await api.draft(widget.doc.id, _kind, purpose);
      if (!mounted) return;
      setState(() {
        _subject.text = (r['oggetto'] as String?) ?? '';
        _body.text = (r['corpo'] as String?) ?? '';
        _warning = r['avviso'] as String?;
        _attachments = ((r['allegati'] as List?) ?? const []).whereType<String>().toList();
        _ready = true;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Qualcosa non ha funzionato. Riprova.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy(String label, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) showSnack(context, '$label copiato.');
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Prepara una bozza')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(widget.doc.title, style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: [for (final e in _kinds.entries) ButtonSegment(value: e.key, label: Text(e.value))],
            selected: {_kind},
            onSelectionChanged: (s) => setState(() => _kind = s.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _purpose,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Cosa vuoi ottenere?'),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [for (final p in _purposes) ActionChip(label: Text(p), onPressed: () => setState(() => _purpose.text = p))],
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _generate,
            child: _busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(_ready ? 'Rigenera la bozza' : 'Prepara la bozza'),
          ),
          if (_error != null) ...[const SizedBox(height: 12), ErrorBanner(message: _error!)],
          if (_ready) ...[
            const SectionTitle('La tua bozza'),
            NoticeBox(
              icon: Icons.edit_outlined,
              title: _warning ?? 'Controlla e modifica la bozza prima di inviarla.',
              lines: const ['Sostituisci le parti tra parentesi quadre [ ] con i tuoi dati. Civis non invia nulla: la invii tu.'],
            ),
            const SizedBox(height: 12),
            if (_kind != 'lettera') ...[
              TextField(controller: _subject, decoration: const InputDecoration(labelText: 'Oggetto')),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _body,
              minLines: 10,
              maxLines: null,
              decoration: const InputDecoration(labelText: 'Testo', alignLabelWithHint: true),
            ),
            if (_attachments.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Allegati suggeriti', style: t.textTheme.titleSmall),
              for (final a in _attachments) Text('• $a'),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                if (_kind != 'lettera')
                  Expanded(
                    child: OutlinedButton(onPressed: () => _copy('Oggetto', _subject.text), child: const Text('Copia oggetto')),
                  ),
                if (_kind != 'lettera') const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(onPressed: () => _copy('Testo', _body.text), child: const Text('Copia testo')),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
