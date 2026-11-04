import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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

class DeadlinesTab extends StatefulWidget {
  const DeadlinesTab({super.key});

  @override
  State<DeadlinesTab> createState() => _DeadlinesTabState();
}

class _DeadlinesTabState extends State<DeadlinesTab> {
  bool _calendar = true;
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  late DateTime _selected = _today();

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  void _goTo(DateTime day) => setState(() {
        _selected = day;
        _month = DateTime(day.year, day.month);
      });

  @override
  Widget build(BuildContext context) {
    final data = AppScope.of(context).data;
    return ListenableBuilder(
      listenable: data,
      builder: (context, _) {
        final open = data.openDeadlines;
        final done = data.deadlines.where((d) => d.done).toList()..sort((a, b) => b.date.compareTo(a.date));
        final empty = open.isEmpty && done.isEmpty && data.loadedOnce;
        return Scaffold(
          appBar: AppBar(title: const Text('Scadenze')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => showDeadlineEditor(context, initialDate: _calendar ? _selected : null),
            icon: const Icon(Icons.add),
            label: const Text('Aggiungi'),
          ),
          body: RefreshIndicator(
            onRefresh: data.refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                if (data.error != null) ...[ErrorBanner(message: data.error!, onRetry: data.refresh), const SizedBox(height: 8)],
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, icon: Icon(Icons.calendar_month_outlined), label: Text('Calendario')),
                    ButtonSegment(value: false, icon: Icon(Icons.list_alt_outlined), label: Text('Elenco')),
                  ],
                  selected: {_calendar},
                  onSelectionChanged: (v) => setState(() => _calendar = v.first),
                ),
                const SizedBox(height: 12),
                if (empty && !_calendar)
                  const SizedBox(
                    height: 380,
                    child: EmptyState(
                      icon: Icons.event_available_outlined,
                      title: 'Nessuna scadenza',
                      text: 'Quando fotografi un documento, le scadenze che trovo compaiono qui. Puoi aggiungere anche bollo, ISEE, IMU e rinnovi.',
                    ),
                  ),
                if (_calendar) ...[
                  _MonthHeader(
                    month: _month,
                    onPrev: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
                    onNext: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
                    onToday: () => _goTo(_today()),
                  ),
                  const SizedBox(height: 8),
                  _MonthGrid(
                    month: _month,
                    selected: _selected,
                    deadlines: data.deadlines,
                    catalog: data.catalog,
                    onSelect: _goTo,
                  ),
                  const SizedBox(height: 8),
                  const _Legend(),
                  const SizedBox(height: 8),
                  SectionTitle(itDate(_selected)),
                  ..._dayList(context, data),
                  if (open.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const SectionTitle('Prossime scadenze'),
                    for (final d in open.take(5)) DeadlineTile(deadline: d),
                  ],
                  ..._upcomingGeneral(data),
                ] else ...[
                  for (final d in open) DeadlineTile(deadline: d),
                  ..._upcomingGeneral(data),
                  if (done.isNotEmpty) ...[
                    const SectionTitle('Fatte'),
                    for (final d in done) DeadlineTile(deadline: d),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  static bool _isAdded(AppData data, CatalogItem c) =>
      data.deadlines.any((d) => d.title == c.title && isoDay(d.date) == isoDay(c.date));

  /// Prossime scadenze generali che l'utente non ha ancora aggiunto ai suoi promemoria.
  List<Widget> _upcomingGeneral(AppData data) {
    final upcoming = data.catalog.where((c) => daysUntil(c.date) >= 0 && !_isAdded(data, c)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    if (upcoming.isEmpty) return const [];
    return [
      const SizedBox(height: 8),
      const SectionTitle('Scadenze generali in arrivo'),
      for (final c in upcoming.take(3)) _CatalogTile(item: c, added: false),
    ];
  }

  List<Widget> _dayList(BuildContext context, AppData data) {
    final day = isoDay(_selected);
    final items = data.deadlines.where((d) => isoDay(d.date) == day).toList();
    final general = data.catalog.where((c) => isoDay(c.date) == day).toList();
    if (items.isEmpty && general.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Nessuna scadenza in questo giorno.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => showDeadlineEditor(context, initialDate: _selected),
            icon: const Icon(Icons.add),
            label: const Text('Aggiungi una scadenza per questo giorno'),
          ),
        ),
      ];
    }
    return [
      for (final d in items) DeadlineTile(deadline: d),
      for (final c in general) _CatalogTile(item: c, added: _isAdded(data, c)),
    ];
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(color: s.onSurfaceVariant);
    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: s.primary, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text('Le tue scadenze', style: style),
        ]),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(border: Border.all(color: s.primary, width: 1.5), shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text('Scadenze generali', style: style),
        ]),
      ],
    );
  }
}

/// Scadenza generale dal catalogo: mostra regola, fonte e data di verifica, e si può aggiungere ai propri promemoria.
class _CatalogTile extends StatefulWidget {
  const _CatalogTile({required this.item, required this.added});

  final CatalogItem item;
  final bool added;

  @override
  State<_CatalogTile> createState() => _CatalogTileState();
}

class _CatalogTileState extends State<_CatalogTile> {
  bool _busy = false;

  Future<void> _add() async {
    final scope = AppScope.of(context);
    final c = widget.item;
    setState(() => _busy = true);
    try {
      await scope.api.createDeadline(
        c.title,
        isoDay(c.date),
        note: 'Scadenza generale. Controlla la data sul sito ufficiale: proroghe e decreti possono cambiarla.',
      );
      await scope.data.refresh();
      if (mounted) showSnack(context, 'Aggiunta ai tuoi promemoria.');
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = widget.item;
    final muted = t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ExpansionTile(
        leading: Icon(Icons.account_balance_outlined, color: t.colorScheme.primary),
        title: Text(c.title),
        subtitle: Text('Scadenza generale · ${itDate(c.date)} · ${relativeDays(c.date)}'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Chi deve pagare', style: t.textTheme.labelLarge),
          Text(c.who, style: muted),
          const SizedBox(height: 8),
          Text('Come', style: t.textTheme.labelLarge),
          Text(c.how, style: muted),
          if (c.moved) ...[
            const SizedBox(height: 8),
            Text(
              'La data prevista cade in un giorno non lavorativo, quindi si sposta al primo giorno lavorativo successivo.',
              style: muted,
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Fonte: ${c.sourceName} · ${c.rule}. Verificata il ${itDate(c.verifiedOn)}. '
            'Controlla sempre la data sul sito ufficiale: proroghe e decreti possono cambiarla.',
            style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => launchUrl(Uri.parse(c.sourceUrl), mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Sito ufficiale'),
              ),
              if (widget.added)
                const Chip(avatar: Icon(Icons.check, size: 18), label: Text('Già nei tuoi promemoria'))
              else
                FilledButton.tonalIcon(
                  onPressed: _busy ? null : _add,
                  icon: const Icon(Icons.add_alert_outlined, size: 18),
                  label: const Text('Aggiungi ai miei promemoria'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.month, required this.onPrev, required this.onNext, required this.onToday});

  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left), tooltip: 'Mese precedente'),
        Expanded(
          child: Text(
            itMonthYear(month),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        TextButton(onPressed: onToday, child: const Text('Oggi')),
        IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right), tooltip: 'Mese successivo'),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.selected,
    required this.deadlines,
    required this.catalog,
    required this.onSelect,
  });

  final DateTime month;
  final DateTime selected;
  final List<DeadlineItem> deadlines;
  final List<CatalogItem> catalog;
  final ValueChanged<DateTime> onSelect;

  static const _weekdays = ['L', 'M', 'M', 'G', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final s = t.colorScheme;
    final byDay = <String, List<DeadlineItem>>{};
    for (final d in deadlines) {
      (byDay[isoDay(d.date)] ??= []).add(d);
    }
    final generalDays = {for (final c in catalog) isoDay(c.date)};
    final first = DateTime(month.year, month.month, 1);
    final lead = first.weekday - 1; // lunedì = 0
    final days = DateTime(month.year, month.month + 1, 0).day;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    Color? dotColor(List<DeadlineItem>? items, DateTime day) {
      if (items == null || items.isEmpty) return null;
      final open = items.where((d) => !d.done).toList();
      if (open.isEmpty) return s.outline;
      if (day.isBefore(today)) return s.error;
      if (day.difference(today).inDays <= 7) return const Color(0xFF9A5B00);
      return s.primary;
    }

    return Column(
      children: [
        Row(
          children: [
            for (final w in _weekdays)
              Expanded(
                child: Center(
                  child: Text(w, style: t.textTheme.labelMedium?.copyWith(color: s.onSurfaceVariant)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.05,
          children: [
            for (var i = 0; i < lead; i++) const SizedBox.shrink(),
            for (var n = 1; n <= days; n++)
              _DayCell(
                day: DateTime(month.year, month.month, n),
                isToday: DateTime(month.year, month.month, n) == today,
                isSelected: DateTime(month.year, month.month, n) == selected,
                dot: dotColor(byDay[isoDay(DateTime(month.year, month.month, n))], DateTime(month.year, month.month, n)),
                count: byDay[isoDay(DateTime(month.year, month.month, n))]?.length ?? 0,
                general: generalDays.contains(isoDay(DateTime(month.year, month.month, n))),
                onTap: onSelect,
              ),
          ],
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.dot,
    required this.count,
    required this.general,
    required this.onTap,
  });

  final DateTime day;
  final bool isToday;
  final bool isSelected;
  final Color? dot;
  final int count;
  final bool general;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: isSelected,
      label: '${itDate(day)}${count > 0 ? ', $count ${count == 1 ? 'scadenza' : 'scadenze'}' : ''}${general ? ', scadenza generale' : ''}',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onTap(day),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isSelected ? s.primary : null,
            border: isToday && !isSelected ? Border.all(color: s.primary, width: 1.5) : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${day.day}',
                style: TextStyle(
                  color: isSelected ? s.onPrimary : s.onSurface,
                  fontWeight: isToday || count > 0 ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
              const SizedBox(height: 3),
              SizedBox(
                height: 8,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (dot != null)
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(color: isSelected ? s.onPrimary : dot, shape: BoxShape.circle),
                      ),
                    if (dot != null && general) const SizedBox(width: 3),
                    if (general)
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          border: Border.all(color: isSelected ? s.onPrimary : s.primary, width: 1.5),
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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

Future<void> showDeadlineEditor(BuildContext context, {DeadlineItem? existing, String? docId, DateTime? initialDate}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _DeadlineForm(existing: existing, docId: docId, initialDate: initialDate),
    ),
  );
}

class _DeadlineForm extends StatefulWidget {
  const _DeadlineForm({this.existing, this.docId, this.initialDate});

  final DeadlineItem? existing;
  final String? docId;
  final DateTime? initialDate;

  @override
  State<_DeadlineForm> createState() => _DeadlineFormState();
}

class _DeadlineFormState extends State<_DeadlineForm> {
  late final TextEditingController _title = TextEditingController(text: widget.existing?.title ?? '');
  late final TextEditingController _note = TextEditingController(text: widget.existing?.note ?? '');
  late DateTime _date = widget.existing?.date ?? widget.initialDate ?? DateTime.now().add(const Duration(days: 30));
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
