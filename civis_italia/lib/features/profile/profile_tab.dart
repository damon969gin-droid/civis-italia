import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api.dart';
import '../../core/app_data.dart';
import '../../core/widgets.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  Future<void> _editName(BuildContext context) async {
    final scope = AppScope.of(context);
    final controller = TextEditingController(text: scope.session.name);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Il tuo nome'),
        content: TextField(controller: controller, autofocus: true, textCapitalization: TextCapitalization.words),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(controller.text), child: const Text('Salva')),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;
    try {
      await scope.session.setName(result.trim());
    } on ApiException catch (e) {
      if (context.mounted) showSnack(context, e.message);
    }
  }

  Future<void> _export(BuildContext context) async {
    final scope = AppScope.of(context);
    try {
      final data = await scope.api.exportAll();
      await Clipboard.setData(ClipboardData(text: const JsonEncoder.withIndent('  ').convert(data)));
      if (context.mounted) showSnack(context, 'Dati copiati negli appunti. Incollali in un file per conservarli.');
    } on ApiException catch (e) {
      if (context.mounted) showSnack(context, e.message);
    }
  }

  Future<void> _logout(BuildContext context) async {
    final scope = AppScope.of(context);
    scope.data.clear();
    await scope.session.logout();
  }

  Future<void> _delete(BuildContext context) async {
    final scope = AppScope.of(context);
    final ok = await confirmDialog(
      context,
      title: 'Eliminare l\'account e tutti i dati?',
      text: 'Vengono cancellati dal server il tuo account, tutti i documenti, le foto e le scadenze. Non si può annullare.',
      confirmLabel: 'Elimina tutto',
      destructive: true,
    );
    if (!ok) return;
    try {
      await scope.api.deleteAccount();
      scope.data.clear();
      await scope.session.logout(message: 'Account eliminato.');
    } on ApiException catch (e) {
      if (context.mounted) showSnack(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final t = Theme.of(context);
    return ListenableBuilder(
      listenable: scope.session,
      builder: (context, _) {
        final s = scope.session;
        final initial = s.name.isNotEmpty ? s.name[0].toUpperCase() : (s.email.isNotEmpty ? s.email[0].toUpperCase() : '?');
        return Scaffold(
          appBar: AppBar(title: const Text('Profilo')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(radius: 28, child: Text(initial, style: t.textTheme.titleLarge)),
                title: Text(s.name.isEmpty ? 'Senza nome' : s.name),
                subtitle: Text(s.email),
                trailing: IconButton(
                  onPressed: () => _editName(context),
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Modifica nome',
                ),
              ),
              const SectionTitle('I tuoi dati'),
              Text(
                'Le foto sono nel tuo archivio privato sul server e le vede solo il tuo account. Per spiegartele, un servizio di AI le legge al momento dell\'analisi.',
                style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.copy_all_outlined),
                title: const Text('Esporta i miei dati'),
                subtitle: const Text('Copia documenti, analisi e scadenze negli appunti.'),
                onTap: () => _export(context),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.delete_forever_outlined, color: t.colorScheme.error),
                title: Text('Elimina account e dati', style: TextStyle(color: t.colorScheme.error)),
                onTap: () => _delete(context),
              ),
              const SectionTitle('Account'),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.logout),
                title: const Text('Esci'),
                onTap: () => _logout(context),
              ),
              const SectionTitle('Informazioni'),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.info_outline),
                title: Text('Civis Ita'),
                subtitle: Text('Versione 0.3.0'),
              ),
            ],
          ),
        );
      },
    );
  }
}
