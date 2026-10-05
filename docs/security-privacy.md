# Sicurezza e Privacy - Civis Italia

## Principi

- I documenti appartengono **esclusivamente** all’utente.
- Cifratura end-to-end applicativa (AES-256-GCM).
- Envelope encryption con Google Cloud KMS.
- Zero-knowledge dove possibile.
- Diritto all’oblio completo (hard delete < 72h).

## Misure implementate (target)

- TLS 1.3 ovunque
- Autenticazione biometrica (Face ID / Touch ID / Android Biometric)
- OAuth 2.1 + PKCE + refresh token rotativi
- 2FA opzionale
- Audit log immutabili
- Backup cifrati
- DPIA completa + DPO
- Row Level Security su PostgreSQL
- Rate limiting e WAF (Cloud Armor / Cloudflare)

## GDPR

- Data minimization
- Consensi granulari e revocabili
- Esportazione completa dei dati
- Eliminazione totale su richiesta
