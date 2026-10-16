/// Indirizzo del server su Cloudflare.
///
/// Dopo "wrangler deploy" il terminale scrive l'indirizzo, per esempio
/// https://civis-api.tuonome.workers.dev . Incollalo qui sotto, oppure passalo
/// all'avvio: flutter run --dart-define=API_URL=https://...
class AppConfig {
  static const apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://civis-api.damon969gin.workers.dev',
  );

  static bool get isConfigured => apiUrl.startsWith('https://') || apiUrl.startsWith('http://');
}
