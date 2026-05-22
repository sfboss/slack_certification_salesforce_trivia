# Authentication & Secrets

All secrets live in **Named Credentials + External Credentials**. Nothing is hard-coded.

## Named Credentials shipped by the package

Located at
[force-app/main/default/namedCredentials](https://github.com/sfboss/slack_certification_salesforce_trivia/tree/main/force-app/main/default/namedCredentials).

| Named Credential | Outbound usage | Bound secret |
| --- | --- | --- |
| `Slack_Bot` | `chat.postMessage`, `views.open`, `views.publish` via `SlackApiClient`. | Bot User OAuth Token (`xoxb-…`). |
| `Slack_Signing` | Used by `SlackSignatureVerifier` to verify inbound HMAC. | Slack Signing Secret. |
| `OpenAI` | `OpenAIQuestionProvider` chat completions. | OpenAI API key (`sk-…`). |
| `Stripe` | `CertGameBillingService` (Customer Portal); inbound webhook verification. | Stripe restricted/secret key + webhook signing secret. |

## How to attach secrets

For each Named Credential:

1. **Setup → Security → Named Credentials → External Credentials**.
2. Open the credential, then under **Permission Set Mappings** ensure
   `Cert_Game_All_Admin` (or the Site Guest User profile, for Slack/Stripe) is mapped.
3. Open **Principal** for that mapping and paste the secret into the appropriate header
   parameter (commonly `Authorization` with value `Bearer <secret>`).
4. For Slack and Stripe signing secrets, *additionally* set them in `App_Setting__mdt.Default`:
    - `Slack_Signing_Secret__c`
    - `Stripe_Webhook_Secret__c`

The verifier classes accept a `@TestVisible` `secretOverride` so unit tests sign with a
known key without touching production secrets.

## Inbound webhook authentication

### Slack

- Every JSON event must include `X-Slack-Signature` + `X-Slack-Request-Timestamp`.
- HMAC-SHA256 over `v0:{ts}:{body}` is compared in **constant time**.
- Requests outside `App_Setting__mdt.Slack_Timestamp_Skew_Seconds__c` are rejected.
- Form-encoded slash commands fall back to the Slack legacy `token` (also stored in
  `App_Setting__mdt.Slack_Verification_Token__c`) **plus** the timestamp window.

Code: [`SlackSignatureVerifier`](../api-reference/apex.md#slacksignatureverifier).

### Stripe

- `Stripe-Signature` HMAC verified by
  [`StripeSignatureVerifier`](../api-reference/apex.md#stripesignatureverifier).
- Timestamp tolerance is configurable.
- Verified payloads are stored on `License_Event__c` with `Stripe_Event_Id__c` as a
  unique key (idempotency).

## Outbound Slack API calls

[`SlackApiClient`](../api-reference/apex.md#slackapiclient) wraps `HttpRequest` and
sets `callout:Slack_Bot/...` as the endpoint. The credential supplies the Bearer token.

```apex
HttpRequest req = new HttpRequest();
req.setEndpoint('callout:Slack_Bot/chat.postMessage');
req.setMethod('POST');
req.setHeader('Content-Type', 'application/json; charset=utf-8');
req.setBody(jsonBody);
```

## Salesforce REST resource access control

`SlackEventsRestResource` is the only public endpoint — it is annotated
`@RestResource(urlMapping='/slack/events')` and exposed to the Site Guest User. All
business logic immediately re-establishes `with sharing` via service classes.
`StripeWebhookHandler` follows the same pattern.

## OWASP coverage

See [docs/security-review.md](https://github.com/sfboss/slack_certification_salesforce_trivia/blob/main/docs/security-review.md)
for the full mapping. Highlights:

- **Injection** — all SOQL uses bind variables; dynamic SOQL only with literal field names.
- **Broken Auth** — every external entry point verifies a signature before DML.
- **Crypto Failures** — `Crypto.generateMac('HmacSHA256', …)` + constant-time compare.
- **SSRF** — all outbound HTTP goes through Named Credentials; no user-supplied URLs.
