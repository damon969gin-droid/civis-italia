import 'package:flutter/material.dart';

import '../../core/app_data.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/widgets.dart';
import '../scan/scan_page.dart';
import 'document_page.dart';

class DocumentsTab extends StatelessWidget {
  const DocumentsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final data = scope.data;
    return ListenableBuilder(
      listenable: data,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Documenti')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => openScan(context),
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Fotografa'),
          ),
          body: RefreshIndicator(
            onRefresh: data.refresh,
            child: _body(context, scope),
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, AppScope scope) {
    final data = scope.data;
    if (!data.loadedOnce && data.loading) {
      return ListView(children: const [SizedBox(height: 200), Center(child: CircularProgressIndicator())]);
    }
    if (data.error != null && !data.loadedOnce) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [ErrorBanner(message: data.error!, onRetry: data.refresh)],
      );
    }
    if (data.docs.isEmpty) {
      return ListView(
        children: [
          SizedBox(
            height: 420,
            child: EmptyState(
              icon: Icons.folder_open_outlined,
              title: 'Nessun documento',
              text: 'Fotografa una lettera, una cartella o una PEC: te la spiego e salvo le scadenze.',
              actionLabel: 'Fotografa un documento',
              onAction: () => openScan(context),
            ),
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        if (data.error != null) ...[ErrorBanner(message: data.error!, onRetry: data.refresh), const SizedBox(height: 8)],
        for (final d in data.docs) _DocTile(doc: d, headers: scope.api.authHeaders, url: scope.api.pageUrl(d.id, 1)),
      ],
    );
  }
}

class _DocTile extends StatelessWidget {
  const _DocTile({required this.doc, required this.headers, required this.url});

  final DocItem doc;
  final Map<String, String> headers;
  final String url;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final a = doc.analysis;
    final String sub;
    if (doc.isAnalyzed) {
      sub = [a?['tipo_documento'], itDate(doc.createdAt)].whereType<String>().join(' · ');
    } else if (doc.status == 'failed') {
      sub = 'Da rivedere · ${itDate(doc.createdAt)}';
    } else {
      sub = 'Da analizzare · ${itDate(doc.createdAt)}';
    }
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: RemotePage(url: url, headers: headers, width: 48, height: 64),
      title: Text(doc.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: doc.isAnalyzed
          ? PriorityDot(priority: a?['priorita'] as String?)
          : Icon(Icons.chevron_right, color: t.colorScheme.outline),
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DocumentPage(documentId: doc.id))),
    );
  }
}

class PriorityDot extends StatelessWidget {
  const PriorityDot({super.key, required this.priority});

  final String? priority;

  @override
  Widget build(BuildContext context) {
    final label = switch (priority) {
      'alta' => 'Alta',
      'media' => 'Media',
      'bassa' => 'Bassa',
      _ => '',
    };
    if (label.isEmpty) return const SizedBox.shrink();
    final color = switch (priority) {
      'alta' => const Color(0xFFB3261E),
      'media' => const Color(0xFF9A5B00),
      _ => const Color(0xFF0F7B5F),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 10, color: color),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
