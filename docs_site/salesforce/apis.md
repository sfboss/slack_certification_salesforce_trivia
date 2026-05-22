# Salesforce APIs

Two public REST endpoints are exposed through a Salesforce Site. Both are HMAC-verified
before any DML.

## `POST /services/apexrest/slack/events`

Implementation:
[`SlackEventsRestResource`](../api-reference/apex.md#slackeventsrestresource) →
[`SlackRequestRouter.dispatch`](../api-reference/apex.md#slackrequestrouter).

Used by:

- Slash commands (`application/x-www-form-urlencoded`)
- Interactivity payloads (`application/x-www-form-urlencoded`)
- Event subscriptions (`application/json`)
- URL verification handshake (`application/json`)

### Headers

| Header | Required | Purpose |
| --- | --- | --- |
| `X-Slack-Signature` | yes (JSON callbacks) | HMAC-SHA256 over `v0:{ts}:{body}`. |
| `X-Slack-Request-Timestamp` | yes | Replay window enforced (default 300s). |
| `Content-Type` | yes | `application/x-www-form-urlencoded` or `application/json`. |

For form-encoded slash commands, Salesforce Sites strips raw bytes; the router falls back
to verifying via Slack's legacy `token` field plus the timestamp window. See
[`SlackSignatureVerifier.verifyByToken`](../api-reference/apex.md#slacksignatureverifier).

### Response

- `200 OK` with a Block Kit JSON body (slash commands), or the URL verification
  `challenge` string, or empty body for fire-and-forget events.
- `401` `invalid signature` on HMAC failure.

### URL verification

```bash
curl -i -X POST 'https://<your-site>.my.salesforce-sites.com/services/apexrest/slack/events' \
  -H 'Content-Type: application/json' \
  -d '{"type":"url_verification","challenge":"hello123"}'
```

Expected: `200` with body `hello123`.

### Idempotency

Every dispatched payload is logged to `Slack_Event_Log__c` with a synthesized id
(`event_id` from Slack, or SHA-256 of the body for slash/interactivity). A second arrival
of the same id short-circuits with `200` and no side effects.

---

## `POST /services/apexrest/stripe/webhook`

Implementation:
[`StripeWebhookHandler`](../api-reference/apex.md#stripewebhookhandler).

Verifies `Stripe-Signature` via
[`StripeSignatureVerifier`](../api-reference/apex.md#stripesignatureverifier), upserts a
`License_Event__c` keyed by `Stripe_Event_Id__c`, then mutates `Tenant__c.Plan__c` and
`Tenant__c.Status__c` based on the event type.

### Supported events

| Stripe event | Effect |
| --- | --- |
| `checkout.session.completed` | Activate plan + status. |
| `customer.subscription.updated` | Update plan, period end. |
| `customer.subscription.deleted` | Downgrade to Free. |
| `invoice.payment_failed` | Mark `Past_Due`. |

Unknown events are stored but otherwise ignored.

### Response

- `200 OK` on success or duplicate.
- `400` on signature failure.

---

## `AuraEnabled` Apex (called from LWCs)

These are not HTTP endpoints; they are invoked by Lightning Web Components via the
`@AuraEnabled` decorator. See [LWC reference](../api-reference/lwc.md) for the calling
components.

| Method | Class | Purpose |
| --- | --- | --- |
| `importPack(String json)` | `CertGameImportService` | Import a question pack JSON. |
| `listDrafts(...)` | `QuestionReviewController` | List reviewable drafts. |
| `publishQuestion(Id)` | `QuestionReviewController` | Flip draft → published. |
| `rejectQuestion(Id, String reason)` | `QuestionReviewController` | Flip draft → rejected. |
| `getDashboardStats(...)` | `CertGameAdminDashboardController` | Admin metrics. |
| `getPlayerStats(...)` | `CertGamePlayerDashboardController` | Per-player metrics. |
| `getLeaderboard(...)` | `CertGameLeaderboardController` | Internal leaderboard view. |
| `openCustomerPortal(...)` | `CertGameBillingController` | Stripe Customer Portal link. |

All `@AuraEnabled` methods declare `with sharing` and enforce CRUD/FLS.
