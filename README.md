# Civis Italia

**Il tuo assistente personale intelligente per la burocrazia italiana**

Fotografa una lettera, una cartella, una PEC, un avviso o qualsiasi documento ufficiale.  
L’intelligenza artificiale lo legge, lo comprende e te lo spiega in **italiano semplice**, evidenziando:

- cosa significa
- cosa devi fare
- scadenze
- importi
- documenti necessari
- priorità e conseguenze

Poi crea automaticamente i promemoria (ISEE, 730, bollo, patente, SPID…).

---

## Stack Tecnologico

| Layer            | Tecnologia                                      | Motivazione                              |
|------------------|-------------------------------------------------|------------------------------------------|
| **Mobile**       | Flutter (Android + iOS)                         | Un solo codebase, performance native, time-to-market |
| **Backend**      | NestJS + TypeScript                             | Enterprise-ready, TypeScript end-to-end  |
| **Database**     | PostgreSQL (Cloud SQL) + Redis                  | Affidabilità + performance               |
| **AI / OCR**     | Google Document AI + Gemini + Claude            | Massima accuratezza su documenti italiani|
| **Cloud**        | Google Cloud Platform (Cloud Run, KMS, Pub/Sub) | Compliance GDPR + Vertex AI nativo       |
| **Auth**         | OAuth 2.1 + Biometric (Face ID / Touch ID) + 2FA| Sicurezza e UX                           |
| **Billing**      | RevenueCat + Stripe                             | Abbonamenti cross-platform               |
| **Storage**      | Cloud Storage cifrato (AES-256-GCM)             | Privacy by design                        |

---

## Struttura del Monorepo

```text
civis-italia/
├── apps/
│   └── mobile/                 # App Flutter (Android + iOS)
│       ├── lib/
│       │   ├── main.dart
│       │   ├── app.dart
│       │   ├── core/
│       │   ├── features/
│       │   └── shared/
│       ├── assets/
│       └── pubspec.yaml
├── backend/                   # API NestJS
│   ├── src/
│   │   ├── main.ts
│   │   ├── app.module.ts
│   │   ├── modules/
│   │   ├── common/
│   │   └── config/
│   ├── package.json
│   └── nest-cli.json
├── packages/
│   └── shared/                # Tipi e costanti condivise
├── docs/                      # Documentazione completa
├── assets/
│   └── logo/
├── .github/
│   └── workflows/
└── README.md
```

---

## Funzionalità Principali

- **OCR** ad altissima accuratezza (foto, PDF, PEC, screenshot, scanner)
- **Spiegazione** in italiano semplice (livello A2-B1)
- Checklist interattive + priorità + tempo stimato
- **Calendario intelligente** con promemoria automatici
- Generazione assistita di PEC, email e lettere
- Chat AI 24/7 contestuale al documento
- Modalità Famiglia e Professionisti
- Privacy totale (GDPR, cifratura end-to-end, diritto all’oblio)

---

## Monetizzazione (Freemium)

| Piano            | Prezzo              | Limiti / Vantaggi                          |
|------------------|---------------------|--------------------------------------------|
| **Free**         | Gratuito            | 3-5 documenti/mese, funzioni base          |
| **Premium**      | €4,99/mese o €49,99/anno | Documenti illimitati, AI avanzata, calendario, backup |
| **Famiglia**     | €7,99/mese          | Fino a 5 profili                           |
| **Professionisti** | da €14,99/mese    | Multi-utente, export contabile, priorità   |

---

## Come iniziare (sviluppo)

### Prerequisiti
- Flutter 3.24+
- Node.js 20+
- Docker (opzionale per PostgreSQL locale)

### Mobile
```bash
cd apps/mobile
flutter pub get
flutter run
```

### Backend
```bash
cd backend
npm install
npm run start:dev
```

---

## Documentazione

- [Architettura](docs/architecture.md)
- [Product Spec](docs/product-spec.md)
- [Roadmap 12 mesi](docs/roadmap-12-months.md)
- [Sicurezza & Privacy](docs/security-privacy.md) *(in arrivo)*

---

## Licenza

Proprietaria – Tutti i diritti riservati © 2026 Civis Italia
