import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_data.dart';
import '../../core/widgets.dart';

class _Msg {
  _Msg(this.role, this.text);
  final String role; // user | assistant
  final String text;
}

/// Chat. Senza [docId] è la scheda "Chiedi"; con [docId] parla di un documento preciso.
class ChatPage extends StatefulWidget {
  const ChatPage({super.key, this.docId, this.docTitle});

  final String? docId;
  final String? docTitle;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<_Msg> _messages = [];
  bool _busy = false;
  String? _error;

  static const _examples = [
    'Che significa questa lettera?',
    'Devo pagare?',
    'Cosa succede se non faccio nulla?',
    'Cosa devo fare per prima cosa?',
  ];

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _busy) return;
    final api = AppScope.of(context).api;
    setState(() {
      _messages.add(_Msg('user', text));
      _input.clear();
      _busy = true;
      _error = null;
    });
    _scrollDown();
    try {
      // Si inviano gli ultimi messaggi; la conversazione deve iniziare e finire con l'utente.
      var recent = _messages.length > 12 ? _messages.sublist(_messages.length - 12) : List<_Msg>.from(_messages);
      while (recent.isNotEmpty && recent.first.role != 'user') {
        recent = recent.sublist(1);
      }
      final reply = await api.chat(
        [for (final m in recent) {'role': m.role, 'content': m.text}],
        docId: widget.docId,
      );
      if (mounted) setState(() => _messages.add(_Msg('assistant', reply)));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Qualcosa non ha funzionato. Riprova.');
    } finally {
      if (mounted) setState(() => _busy = false);
      _scrollDown();
    }
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final s = t.colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.docTitle == null ? 'Chiedi a Civis' : 'Domande: ${widget.docTitle}')),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 48, color: s.primary),
                      const SizedBox(height: 12),
                      Text(
                        widget.docId == null ? 'Chiedimi quello che vuoi sulla burocrazia' : 'Chiedimi del documento',
                        style: t.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.docId == null
                            ? 'Per domande su una lettera precisa, aprila dai Documenti e usa il pulsante "Fai una domanda".'
                            : 'Conosco già il contenuto del documento.',
                        style: t.textTheme.bodyMedium?.copyWith(color: s.onSurfaceVariant),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final q in _examples) ActionChip(label: Text(q), onPressed: () => _send(q)),
                        ],
                      ),
                    ],
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_busy ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == _messages.length) {
                        return const Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
                        );
                      }
                      final m = _messages[i];
                      final mine = m.role == 'user';
                      return Align(
                        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
                          decoration: BoxDecoration(
                            color: mine ? s.primaryContainer : s.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: SelectableText(m.text),
                        ),
                      );
                    },
                  ),
          ),
          if (_error != null) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: ErrorBanner(message: _error!)),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 4000,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(hintText: 'Scrivi una domanda', counterText: ''),
                      onSubmitted: _send,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _busy ? null : () => _send(_input.text),
                    icon: const Icon(Icons.send),
                    tooltip: 'Invia',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
