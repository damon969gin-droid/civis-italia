# Civis Ita — app + server su Cloudflare

Fotografa una lettera, l'AI te la spiega, le scadenze finiscono nel tuo calendario.

- `lib/` — app Flutter (Android e iPhone)
- `worker/` — server su Cloudflare (accesso, database, archivio foto, analisi AI)

Il server tiene la chiave dell'AI: nell'app non c'è nessuna chiave.

## Parte 1 — Il server su Cloudflare (una volta sola)

Ti servono: un account Cloudflare (gratuito per iniziare), Node.js LTS da nodejs.org e una chiave API Anthropic da console.anthropic.com (con un po' di credito: ogni documento costa pochi centesimi).

Il database (D1, chiamato `civis`) è **già creato** nel tuo account Cloudflare, con tutte le tabelle (anche quella delle foto), e il suo id è già in `worker/wrangler.toml`. Non serve R2: le foto, ridotte dall'app a circa mezzo MB l'una, stanno nello stesso database.

Apri il terminale nella cartella `worker` ed esegui, **uno alla volta**:

```
npm install
npx wrangler login
```

Ora i due segreti. Il primo è una chiave lunga e casuale: generala con questo comando e incollala quando richiesto.

```
$b=New-Object byte[] 48; [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($b); [Convert]::ToBase64String($b)
npx wrangler secret put JWT_SECRET
npx wrangler secret put ANTHROPIC_API_KEY
```

Per `ANTHROPIC_API_KEY` incolla la chiave di Anthropic. Infine:

```
npx wrangler deploy
```

Al primo deploy `wrangler` può chiedere di scegliere il nome del tuo spazio `workers.dev`: scrivi un nome qualsiasi. Il terminale scrive l'indirizzo del server, per esempio `https://civis-api.tuonome.workers.dev`. Aprilo nel browser aggiungendo `/health`: deve rispondere `{"ok":true}`.

> **Piano Cloudflare.** Il piano gratuito dei Workers dà pochissimo tempo di calcolo per richiesta (10 ms). Il controllo della password e la preparazione delle foto per l'AI possono superarlo e dare errore. Se succede, passa a "Workers Paid" (circa 5 $/mese, da verificare sul sito di Cloudflare).

## Parte 2 — L'app

1. Apri `lib/config.dart` e incolla l'indirizzo del server al posto di `INCOLLA_QUI_L_INDIRIZZO_DEL_SERVER`.
2. Nella cartella principale:

```
flutter create --org it.civis --project-name civis_italia --platforms=android,ios .
flutter pub get
dart run flutter_launcher_icons
flutter run
```

Se `flutter create` chiede di sovrascrivere `pubspec.yaml`, rispondi no. Cancella `test\widget_test.dart` se Flutter lo ricrea.

3. **Android** — `android/app/src/main/AndroidManifest.xml`, dentro `<manifest>` (prima di `<application>`):

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.CAMERA"/>
```

   e in `android/app/build.gradle.kts` imposta `minSdk = 24` (o più).

4. **iPhone** — `ios/Runner/Info.plist`, dentro `<dict>`:

```xml
<key>NSCameraUsageDescription</key>
<string>Civis usa la fotocamera per leggere i tuoi documenti.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Civis può leggere un documento dalle tue foto, solo se lo scegli tu.</string>
```

Con `flutter run -d chrome` puoi provare accesso, scadenze e chat nel browser. La scansione con la fotocamera funziona solo su Android e iPhone.

## Prove automatiche

```
cd worker && node --test test/api.test.js     # server (22 prove, Node 22)
flutter analyze && flutter test               # app
```

## Cosa fa e cosa manca

Fatto: registrazione e accesso, foto private per utente (nel database), analisi AI delle foto (riassunto, cosa fare, importi, scadenze, priorità, avviso truffa), scadenze create in automatico, chat sul documento, bozze di PEC/email/lettera, esportazione ed eliminazione di tutti i dati.

Limite da sapere: il piano gratuito di D1 ha 500 MB per database, cioè circa 1000 pagine. Per più utenti si passa al piano a pagamento o a R2.

Non ancora: cifratura delle foto con una chiave solo tua (ora sono private ma Cloudflare può tecnicamente leggerle), blocco con Face ID, accesso con Apple/Google, notifiche sul telefono, abbonamenti. Il limite di documenti al mese è in `worker/wrangler.toml` (`FREE_DOCS_PER_MONTH`).
