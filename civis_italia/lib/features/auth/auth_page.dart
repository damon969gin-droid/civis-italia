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
  bool _register = false;
  bool _consent = false;
  bool _hide = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
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
      if (_register) {
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
                      _register ? 'Crea il tuo account' : 'Bentornato',
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
                    if (notice != null && !_register) ...[
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
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: _hide,
                      autofillHints: [_register ? AutofillHints.newPassword : AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: 'Password',
                        helperText: _register ? 'Almeno 8 caratteri' : null,
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
                      NoticeBox(
                        icon: Icons.lock_outline,
                        title: 'Come vengono trattati i tuoi documenti',
                        lines: const [
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
                          : Text(_register ? 'Crea account' : 'Accedi'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                _register = !_register;
                                _error = null;
                              }),
                      child: Text(_register ? 'Hai già un account? Accedi' : 'Non hai un account? Registrati'),
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
