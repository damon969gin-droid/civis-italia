import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'config.dart';
import 'core/api.dart';
import 'core/app_data.dart';
import 'core/session.dart';
import 'core/theme.dart';
import 'features/auth/auth_page.dart';
import 'features/home/home_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CivisApp());
}

class CivisApp extends StatefulWidget {
  const CivisApp({super.key});

  @override
  State<CivisApp> createState() => _CivisAppState();
}

class _CivisAppState extends State<CivisApp> {
  late final ApiClient _api = ApiClient(baseUrl: AppConfig.apiUrl);
  late final Session _session = Session(_api);
  late final AppData _data = AppData(_api);

  @override
  void initState() {
    super.initState();
    _api.onUnauthorized = () {
      _data.clear();
      _session.logout(message: 'L\'accesso è scaduto. Accedi di nuovo.');
    };
    _session.restore();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      session: _session,
      data: _data,
      child: MaterialApp(
        title: 'Civis',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        locale: const Locale('it'),
        supportedLocales: const [Locale('it')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: ListenableBuilder(
          listenable: _session,
          builder: (context, _) {
            if (!AppConfig.isConfigured) return const _NotConfigured();
            if (!_session.loaded) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            return _session.signedIn ? const HomeShell() : const AuthPage();
          },
        ),
      ),
    );
  }
}

class _NotConfigured extends StatelessWidget {
  const _NotConfigured();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text(
              'Manca l\'indirizzo del server.\n\nApri lib/config.dart e incolla l\'indirizzo che ti ha dato Cloudflare dopo "wrangler deploy".',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
