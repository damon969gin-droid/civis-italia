import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Mostra il codice di recupero. Si può chiudere solo dopo aver confermato di averlo salvato:
/// senza email, è l'unico modo per rientrare se si dimentica la password.
Future<void> showRecoveryCodeDialog(BuildContext context, String code) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      var saved = false;
      var copied = false;
      return StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Salva il tuo codice di recupero'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Se dimentichi la password, questo codice è l\'unico modo per rientrare nel tuo account. '
                  'Non lo vedrai più: scrivilo o salvalo in un posto sicuro.',
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SelectableText(
                    code,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 1),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: code));
                      setState(() => copied = true);
                    },
                    icon: Icon(copied ? Icons.check : Icons.copy_outlined),
                    label: Text(copied ? 'Copiato' : 'Copia il codice'),
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: saved,
                  onChanged: (v) => setState(() => saved = v ?? false),
                  title: const Text('Ho salvato il codice'),
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: saved ? () => Navigator.of(ctx).pop() : null,
              child: const Text('Continua'),
            ),
          ],
        ),
      );
    },
  );
}
