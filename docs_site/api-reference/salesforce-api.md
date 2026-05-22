# Salesforce REST API

Salesforce exposes two public REST endpoints via a Salesforce Site. See
[Salesforce APIs](../salesforce/apis.md) for the operational summary; this page is the
detailed contract.

---

## `POST /services/apexrest/slack/events`

**Implementation:** [`SlackEventsRestResource`](apex.md#slackeventsrestresource)
→ [`SlackRequestRouter.dispatch`](apex.md#slackrequestrouter).

**Content-Type:** `application/x-www-form-urlencoded` (slash commands, interactivity) or
`application/json` (event callbacks).

### Required headers

| Header | Required when | Notes |
| --- | --- | --- |
| `X-Slack-Signature` | All HMAC paths | `v0=hex(hmacSHA256(signingSecret, "v0:{ts}:{body}"))`. |
| `X-Slack-Request-Timestamp` | Always | Unix seconds; enforced ±300s. |
| `Content-Type` | Always | See above. |

### Payload types

| `type` | Source | Dispatched to |
| --- | --- | --- |
| `url_verification` | Slack handshake | Echo `challenge` (no auth). |
| `slash_command` | `/certgame ...` | `SlackCertGameCommandHandler` |
| `block_actions` | Button / select click | `SlackCertGameInteractionHandler` |
| `view_submission` | Modal submit | `SlackCertGameModalHandler` |
| `view_closed` | Modal cancel | `SlackCertGameModalHandler` |
| `event_callback` | Subscribed events | `SlackCertGameEventHandler` |

### Responses

| Code | When |
| --- | --- |
| `200` + JSON body | Successful slash command (Block Kit JSON). |
| `200` + `challenge` | URL verification. |
| `200` + empty | Acknowledged event / duplicate / non-error. |
| `401` `invalid signature` | HMAC + token fallback both failed. |

### URL verification example

```bash
curl -i -X POST 'https://<site>/services/apexrest/slack/events' \
  -H 'Content-Type: application/json' \
  -d '{"type":"url_verification","challenge":"hello123"}'
```

Response:

```text
HTTP/1.1 200 OK
hello123
```

### Slash command example

Slack sends form-encoded:

```text
POST /services/apexrest/slack/events
Content-Type: application/x-www-form-urlencoded
X-Slack-Signature: v0=...
X-Slack-Request-Timestamp: 1714000000

token=xxxx&team_id=T01&user_id=U01&channel_id=C01&command=%2Fcertgame&text=play+ADM-201&trigger_id=...
```

Response body is Block Kit JSON the user sees as the slash command's reply.

### Idempotency

- Every dispatched payload is logged to `Slack_Event_Log__c`.
- External Id `Slack_Event_Id__c` = Slack-provided `event_id` or SHA-256 of body.
- Second arrival short-circuits with empty `200` (no DML).

---

## `POST /services/apexrest/stripe/webhook`

**Implementation:** [`StripeWebhookHandler`](apex.md#stripewebhookhandler).

### Required headers

| Header | Notes |
| --- | --- |
| `Stripe-Signature` | `t=...,v1=...`. Verified with timestamp skew. |
| `Content-Type` | `application/json`. |

### Handled events

| Event | Effect |
| --- | --- |
| `checkout.session.completed` | Set `Tenant__c.Plan__c = 'Pro'` (or `Enterprise`), `Status__c = 'Active'`. |
| `customer.subscription.updated` | Update plan + `Current_Period_End__c`. |
| `customer.subscription.deleted` | `Plan__c = 'Free'`, `Status__c = 'Cancelled'`. |
| `invoice.payment_failed` | `Status__c = 'Past_Due'`. |
| anything else | Stored on `License_Event__c`, no mutation. |

### Responses

- `200` on success or duplicate.
- `400` on signature failure.

### Idempotency

`License_Event__c.Stripe_Event_Id__c` (External Id) deduplicates by Stripe's `event.id`.

---

## `@AuraEnabled` Apex (LWC bridge)

These are reachable only from authenticated LWCs; they enforce `WITH USER_MODE` SOQL and
`with sharing`.

| Method | Class |
| --- | --- |
| `importPack(String json)` | `CertGameImportService` |
| `listDrafts(filters)` | `QuestionReviewController` |
| `publishQuestion(Id)` | `QuestionReviewController` |
| `rejectQuestion(Id, String reason)` | `QuestionReviewController` |
| `getDashboardStats(...)` | `CertGameAdminDashboardController` |
| `getPlayerStats(...)` | `CertGamePlayerDashboardController` |
| `getLeaderboard(...)` | `CertGameLeaderboardController` |
| `openCustomerPortal(Id tenantId)` | `CertGameBillingController` |

Method signatures live in the source under
[force-app/main/default/classes/](https://github.com/sfboss/slack_certification_salesforce_trivia/tree/main/force-app/main/default/classes).
