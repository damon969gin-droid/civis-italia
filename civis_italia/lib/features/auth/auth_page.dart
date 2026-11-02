import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/app_data.dart';
import '../../core/widgets.dart';

/// Accesso e registrazione.
class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  bool _register = false;
  bool _reset = false;
  bool _consent = false;
  bool _hide = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_register && !_consent) {
      setState(() => _error = 'Per creare l\'account devi confermare di aver letto l\'informativa qui sopra.');
      return;
    }
    final session = AppScope.of(context).session;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final email = _email.text.trim();
      if (_reset) {
        await session.resetPassword(email, _code.text.trim(), _password.text);
      } else if (_register) {
        await session.register(email, _password.text, _name.text.trim());
      } else {
        await session.login(email, _password.text);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Qualcosa non ha funzionato. Riprova.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final notice = AppScope.of(context).session.notice;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.asset('assets/icon/app_icon.png', width: 96, height: 96),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _reset ? 'Reimposta la password' : (_register ? 'Crea il tuo account' : 'Bentornato'),
                      style: t.textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Fotografa una lettera e capisci subito cosa devi fare.',
                      style: t.textTheme.bodyLarge?.copyWith(color: t.colorScheme.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    if (_reset) ...[
                      const NoticeBox(
                        icon: Icons.key_outlined,
                        title: 'Usa il codice di recupero',
                        lines: [
                          'È il codice di 20 caratteri che ti abbiamo mostrato quando hai creato l\'account.',
                          'Se l\'hai perso, non c\'è modo di recuperare l\'account: puoi crearne uno nuovo.',
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (notice != null && !_register && !_reset) ...[
                      NoticeBox(icon: Icons.info_outline, title: notice),
                      const SizedBox(height: 16),
                    ],
                    if (_register) ...[
                      TextFormField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        autofillHints: const [AutofillHints.givenName],
                        decoration: const InputDecoration(labelText: 'Come ti chiami? (facoltativo)'),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (v) {
                        final s = (v ?? '').trim();
                        return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(s) ? null : 'Scrivi un\'email valida';
                      },
                    ),
                    if (_reset) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _code,
                        textCapitalization: TextCapitalization.characters,
                        autocorrect: false,
                        decoration: const InputDecoration(labelText: 'Codice di recupero', hintText: 'XXXXX-XXXXX-XXXXX-XXXXX'),
                        validator: (v) => (v ?? '').trim().length >= 20 ? null : 'Scrivi il codice di recupero',
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: _hide,
                      autofillHints: [_register || _reset ? AutofillHints.newPassword : AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: _reset ? 'Nuova password' : 'Password',
                        helperText: _register || _reset ? 'Almeno 8 caratteri' : null,
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _hide = !_hide),
                          icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          tooltip: _hide ? 'Mostra la password' : 'Nascondi la password',
                        ),
                      ),
                      validator: (v) => (v ?? '').length >= 8 ? null : 'Almeno 8 caratteri',
                      onFieldSubmitted: (_) => _busy ? null : _submit(),
                    ),
                    if (_register) ...[
                      const SizedBox(height: 16),
                      const NoticeBox(
                        icon: Icons.lock_outline,
                        title: 'Come vengono trattati i tuoi documenti',
                        lines: [
                          'Le foto restano nel tuo archivio privato e le vedi solo tu.',
                          'Per spiegartele, un servizio di intelligenza artificiale le legge. Non vengono usate per addestrarlo.',
                          'Puoi esportare o eliminare tutto, in qualsiasi momento, dal Profilo.',
                        ],
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: _consent,
                        onChanged: (v) => setState(() => _consent = v ?? false),
                        title: const Text('Ho letto e acconsento all\'analisi dei miei documenti con l\'AI'),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      ErrorBanner(message: _error!),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(_reset ? 'Reimposta e accedi' : (_register ? 'Crea account' : 'Accedi')),
                    ),
                    const SizedBox(height: 8),
                    if (!_register && !_reset)
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                  _reset = true;
                                  _error = null;
                                }),
                        child: const Text('Password dimenticata?'),
                      ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                if (_reset) {
                                  _reset = false;
                                } else {
                                  _register = !_register;
                                }
                                _error = null;
                              }),
                      child: Text(_reset
                          ? 'Torna all\'accesso'
                          : (_register ? 'Hai già un account? Accedi' : 'Non hai un account? Registrati')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
