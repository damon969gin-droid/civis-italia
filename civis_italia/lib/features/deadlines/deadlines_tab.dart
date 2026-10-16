import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_data.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/widgets.dart';

/// Scadenze frequenti: compilano solo il titolo, la data la scegli tu.
const deadlinePresets = <String>[
  'Bollo auto',
  'IMU',
  'TARI',
  'ISEE',
  'Dichiarazione 730',
  'Revisione auto',
  'Assicurazione',
  'Carta d\'identità',
  'Passaporto',
  'Patente',
  'Rinnovo SPID',
  'Rinnovo PEC',
  'Firma digitale',
  'Permesso di soggiorno',
];

class DeadlinesTab extends StatelessWidget {
  const DeadlinesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final data = AppScope.of(context).data;
    return ListenableBuilder(
      listenable: data,
      builder: (context, _) {
        final open = data.openDeadlines;
        final done = data.deadlines.where((d) => d.done).toList()..sort((a, b) => b.date.compareTo(a.date));
        return Scaffold(
          appBar: AppBar(title: const Text('Scadenze')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => showDeadlineEditor(context),
            icon: const Icon(Icons.add),
            label: const Text('Aggiungi'),
          ),
          body: RefreshIndicator(
            onRefresh: data.refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                if (data.error != null) ...[ErrorBanner(message: data.error!, onRetry: data.refresh), const SizedBox(height: 8)],
                if (open.isEmpty && done.isEmpty && data.loadedOnce)
                  const SizedBox(
                    height: 380,
                    child: EmptyState(
                      icon: Icons.event_available_outlined,
                      title: 'Nessuna scadenza',
                      text: 'Quando fotografi un documento, le scadenze che trovo compaiono qui. Puoi aggiungere anche bollo, ISEE, IMU e rinnovi.',
                    ),
                  ),
                for (final d in open) DeadlineTile(deadline: d),
                if (done.isNotEmpty) ...[
                  const SectionTitle('Fatte'),
                  for (final d in done) DeadlineTile(deadline: d),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class DeadlineTile extends StatelessWidget {
  const DeadlineTile({super.key, required this.deadline});

  final DeadlineItem deadline;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final t = Theme.of(context);
    final d = deadline;
    final days = daysUntil(d.date);
    final overdue = !d.done && days < 0;
    final soon = !d.done && days >= 0 && days <= 7;
    final color = overdue
        ? t.colorScheme.error
        : soon
            ? const Color(0xFF9A5B00)
            : t.colorScheme.onSurfaceVariant;

    return Dismissible(
      key: ValueKey('deadline-${d.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: t.colorScheme.errorContainer,
        child: Icon(Icons.delete_outline, color: t.colorScheme.onErrorContainer),
      ),
      confirmDismiss: (_) => confirmDialog(
        context,
        title: 'Eliminare la scadenza?',
        text: d.title,
        confirmLabel: 'Elimina',
        destructive: true,
      ),
      onDismissed: (_) async {
        scope.data.removeDeadlineLocal(d.id);
        try {
          await scope.api.deleteDeadline(d.id);
        } on ApiException catch (e) {
          if (context.mounted) showSnack(context, e.message);
        }
        await scope.data.refresh();
      },
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Checkbox(
          value: d.done,
          onChanged: (v) async {
            try {
              await scope.api.updateDeadline(d.id, {'done': v ?? false});
              await scope.data.refresh();
            } on ApiException catch (e) {
              if (context.mounted) showSnack(context, e.message);
            }
          },
        ),
        title: Text(
          d.title,
          style: d.done ? const TextStyle(decoration: TextDecoration.lineThrough) : null,
        ),
        subtitle: Text(
          '${itDate(d.date)}${d.done ? '' : ' · ${relativeDays(d.date)}'}${d.auto ? ' · trovata nel documento' : ''}',
          style: TextStyle(color: color),
        ),
        trailing: const Icon(Icons.edit_outlined, size: 20),
        onTap: () => showDeadlineEditor(context, existing: d),
      ),
    );
  }
}

Future<void> showDeadlineEditor(BuildContext context, {DeadlineItem? existing, String? docId}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _DeadlineForm(existing: existing, docId: docId),
    ),
  );
}

class _DeadlineForm extends StatefulWidget {
  const _DeadlineForm({this.existing, this.docId});

  final DeadlineItem? existing;
  final String? docId;

  @override
  State<_DeadlineForm> createState() => _DeadlineFormState();
}

class _DeadlineFormState extends State<_DeadlineForm> {
  late final TextEditingController _title = TextEditingController(text: widget.existing?.title ?? '');
  late final TextEditingController _note = TextEditingController(text: widget.existing?.note ?? '');
  late DateTime _date = widget.existing?.date ?? DateTime.now().add(const Duration(days: 30));
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Scegli la scadenza',
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Scrivi cosa scade.');
      return;
    }
    final scope = AppScope.of(context);
    final nav = Navigator.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final e = widget.existing;
      if (e == null) {
        await scope.api.createDeadline(title, isoDay(_date), note: _note.text.trim(), docId: widget.docId);
      } else {
        await scope.api.updateDeadline(e.id, {'title': title, 'date': isoDay(_date), 'note': _note.text.trim()});
      }
      await scope.data.refresh();
      nav.pop();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.existing == null ? 'Nuova scadenza' : 'Modifica scadenza', style: t.textTheme.titleLarge),
          const SizedBox(height: 12),
          if (widget.existing == null)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final p in deadlinePresets)
                  ActionChip(label: Text(p), onPressed: () => setState(() => _title.text = p)),
              ],
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Cosa scade'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text(itDate(_date)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            minLines: 1,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Appunti (facoltativo)'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: t.colorScheme.error)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Salva'),
          ),
        ],
      ),
    );
  }
}
