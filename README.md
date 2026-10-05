# Civis Italia

**Assistente personale intelligente per la burocrazia italiana**

Fotografa una lettera, una cartella, una PEC o qualsiasi documento ufficiale.  
L’intelligenza artificiale te lo spiega in italiano semplice, evidenzia scadenze, importi, cosa fare e crea promemoria automatici.

## Stack Tecnologico

| Layer          | Tecnologia                          |
|----------------|-------------------------------------|
| Mobile         | Flutter (Android + iOS)             |
| Backend        | NestJS + TypeScript                 |
| Database       | PostgreSQL (Cloud SQL)              |
| AI / OCR       | Google Document AI + Gemini + Claude|
| Cloud          | Google Cloud Platform               |
| Auth           | OAuth 2.1 + Biometric + 2FA         |
| Billing        | RevenueCat + Stripe                 |

## Struttura del Monorepo

```
civis-italia/
├── apps/
│   └── mobile/              # App Flutter
├── backend/                # API NestJS
├── packages/
│   └── shared/             # Tipi, costanti, utils condivisi
├── docs/                   # Documentazione tecnica e di prodotto
├── assets/
│   └── logo/
├── .github/
│   └── workflows/
└── README.md
```

## Funzionalità Principali

- OCR ad altissima accuratezza su foto, PDF, PEC, screenshot
- Spiegazione in italiano semplice (livello A2-B1)
- Checklist azioni + priorità + tempo stimato
- Calendario intelligente (ISEE, 730, IMU, TARI, bollo, patente, SPID…)
- Generazione assistita di PEC, email e lettere
- Chat AI 24/7 contestuale al documento
- Privacy by design (GDPR completo, cifratura end-to-end)

## Monetizzazione

- **Free**: 3-5 documenti/mese
- **Premium**: €4,99/mese (o €49,99/anno)
- **Famiglia**: €7,99/mese
- **Professionisti**: da €14,99/mese

## Roadmap

Vedi [docs/roadmap-12-months.md](docs/roadmap-12-months.md)

## Licenza

Proprietaria – Tutti i diritti riservati © Civis Italia
