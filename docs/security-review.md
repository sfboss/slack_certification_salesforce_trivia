# Security Review Notes

This document summarizes how `CertGameSlackManager` satisfies the Salesforce AppExchange
Security Review checklist. Use it as the foundation for the ISVForce ticket.

## Sharing & FLS

- All Apex classes declare `with sharing` (the runtime default).
- Only two classes use `without sharing` and only for narrowly-scoped, signature-verified entry points:
    - `SlackEventsRestResource` — Slack webhook ingress; verifies HMAC SHA-256 before any DML.
    - `StripeWebhookHandler` — Stripe webhook ingress; verifies HMAC SHA-256 before any DML.
- Every SOQL query uses `WITH USER_MODE`. DML uses `as user` for end-user actions and `as system` only for low-level logging (`App_Log__c`).

## Inbound webhook authentication

- `SlackSignatureVerifier` rejects requests outside `App_Setting__mdt.Slack_Timestamp_Skew_Seconds__c` (default 300).
- `StripeSignatureVerifier` enforces signature + timestamp skew.
- Both verifiers expose a `@TestVisible secretOverride` to make signatures reproducible in tests without storing prod secrets.

## Idempotency

- `Slack_Event_Log__c.Slack_Event_Id__c` — Slack event_id or synthesized id (sha256 of body) is unique.
- `License_Event__c.Stripe_Event_Id__c` — Stripe `event.id` is unique.
- `Player_Answer__c.Unique_Key__c` — `roundId:playerId` is unique.
- `Usage_Metric__c.Unique_Key__c` — `tenantId:YYYY-MM` is unique. All metric writes are upserts.

## Secrets management

- Bot tokens, signing secrets, and API keys live in **Named Credentials / External Credentials**.
- No secrets are hard-coded in Apex; tests inject overrides via `@TestVisible`.

## PII handling

- Stored personal data is limited to Slack `team_id`, `user_id`, and player display name.
- All audit writes route through `AuditLogger` for tamper-evident history.

## OWASP Top-10 coverage

| Risk                           | Control                                                                                                       |
| ------------------------------ | ------------------------------------------------------------------------------------------------------------- |
| Injection                      | SOQL uses bind variables; `Database.query` strings are built from literal field/relationship names only.      |
| Broken Auth                    | All inbound webhooks verify HMAC. Salesforce REST resource is `globalAvailable=false` from external networks. |
| Cryptographic Failures         | `Crypto.computeHmac('hmacSHA256', …)` with constant-time `equals`.                                            |
| Insecure Design                | No callback URLs accept unauthenticated mutations.                                                            |
| Security Misconfiguration      | All custom objects opt into `WITH USER_MODE`. No public `with sharing` bypass.                                |
| Vulnerable Components          | Apex only — no shipped JS libraries beyond LWC framework.                                                     |
| Identification & Auth Failures | Slack request signing + Stripe webhook signing.                                                               |
| Software & Data Integrity      | Question imports require validated JSON; duplicate-detection hashes prevent collisions.                       |
| Logging & Monitoring           | `AppLogger` writes `App_Log__c`; `AuditLogger` writes `Audit_Log__c`.                                         |
| SSRF                           | All outbound callouts go through Named Credentials (no user-supplied URLs).                                   |

## Test coverage targets

- Overall ≥ 85%.
- `SlackSignatureVerifier`, `StripeSignatureVerifier`, `StripeWebhookHandler`, `CertGameScoringService`, `EntitlementGuard` ≥ 95%.

## Known limitations / accepted risks

- HTTP callouts from `CertGameNudgeScheduler` are best-effort; failures are logged and the next run re-attempts.
- Stripe Checkout link generation is out-of-band; the package only stores intent.
