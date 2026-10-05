# Architettura Software - Civis Italia

## Panoramica

Monorepo con:
- **apps/mobile**: Flutter (unico codebase Android + iOS)
- **backend**: NestJS (TypeScript)
- **packages/shared**: tipi TypeScript e costanti condivise

## Decisioni Chiave

### Mobile: Flutter (scelto)
Alternative valutate: React Native, Kotlin + Swift nativo.  
Flutter vince per time-to-market, performance OCR, un solo team e costi di manutenzione inferiori.

### Backend: NestJS
Alternative: FastAPI, Go.  
NestJS scelto per ecosistema enterprise, TypeScript end-to-end e facilità di integrazione AI.

### Cloud: Google Cloud Platform
- Cloud Run (backend)
- Cloud SQL PostgreSQL
- Cloud Storage (documenti cifrati)
- Vertex AI + Document AI (OCR + LLM)
- Cloud KMS (chiavi di cifratura)
- Pub/Sub (elaborazione asincrona)

### Sicurezza
- Cifratura end-to-end applicativa (AES-256-GCM)
- Envelope encryption con Cloud KMS
- TLS 1.3
- Biometric auth + OAuth 2.1 + 2FA
- Audit log immutabili
- GDPR by design
