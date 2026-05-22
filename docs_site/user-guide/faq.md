# FAQ

### Why is Slack a thin controller?

So Salesforce stays the source of truth. Every record — question, answer, achievement,
license event — is durable in Salesforce. Slack outages don't lose history; tenant
migrations don't need data export.

### Why does the import never publish?

Drafts must be reviewed by a human. The Security Review hard-requires it. From
[AGENTS.md §0](https://github.com/sfboss/slack_certification_salesforce_trivia/blob/main/AGENTS.md):
"Generated questions are inert until a human flips `Trivia_Question__c.Status__c = Published`."

### Can players play in DMs only?

Yes. `/certgame play` works in any channel or DM where the bot is present. Duels post a
challenge card in the channel where the command was run, but the actual play happens in
each player's DM.

### How is duplicate detection done?

[`QuestionDuplicateDetector`](../api-reference/apex.md#questionduplicatedetector) hashes a
normalized form of the question stem + correct-choice text with SHA-256 and stores it on
`Trivia_Question__c.Hash__c`. On import, collisions are flagged for the reviewer.

### Why two signature verifiers?

HMAC over the canonical Slack base string is the proper verification. But Salesforce Sites
consume `application/x-www-form-urlencoded` bodies into `RestRequest.params` and discard
the raw bytes, which makes HMAC impossible for slash commands. The router falls back to
verifying the Slack legacy `token` field plus enforcing the timestamp skew window. JSON
event callbacks still require HMAC.

See [`SlackSignatureVerifier`](../api-reference/apex.md#slacksignatureverifier).

### What happens on Slack retries?

The router upserts `Slack_Event_Log__c` keyed by a synthesized event id (sha256 of the
body). The second arrival short-circuits with `200` and no DML.

### How are scores calculated?

[`CertGameScoringService`](../api-reference/apex.md#certgamescoringservice) — formula:

```text
points = correct ? (base + timeBonus + streakBonus) : penalty
```

with `base` set by difficulty (Easy 10 / Medium 20 / Hard 30), `timeBonus` proportional to
time remaining, and `streakBonus` capped at +20.

### Are real-money prizes supported?

No. The package is a learning tool, not a sweepstakes platform. Out-of-band SWAG, badges,
or sponsor-provided gifts are fine; real-money prizes are explicitly out of scope per
[AGENTS.md §7](https://github.com/sfboss/slack_certification_salesforce_trivia/blob/main/AGENTS.md).

### Can I run this without billing?

Yes. `Feature_Flag_Billing__c` defaults to `false`. Stripe is only invoked when that flag
is on and an admin runs `/certgame billing`.

### Do I need OpenAI to use the app?

No. Question generation is optional. You can import question packs as JSON without any
LLM. Generation is gated by `Feature_Flag_Generation__c`.

### How do I add a new exam?

Either:

- Import a JSON pack whose `exam.code` is new — `CertGameImportService.upsertExam` will
  create it.
- Or insert a `Certification_Exam__c` directly via UI / data loader.

### How do I add a new achievement?

Insert an `Achievement__c` record (definition). The runtime evaluator is
[`CertGameAchievementService`](../api-reference/apex.md#certgameachievementservice) — extend
it for new evaluation rules.

### How do I run the test suite?

```bash
sf apex run test -o certgame -r human -w 20 --code-coverage
```

See [Testing](../development/testing.md).

### Where do logs go?

- `App_Log__c` — structured Apex logs.
- `Audit_Log__c` — tamper-evident audit trail.
- `Slack_Event_Log__c` — every inbound Slack payload.
- `License_Event__c` — every Stripe webhook event.

### Why are some classes `without sharing`?

Only narrow, signature-verified entry points need it (`SlackEventsRestResource`,
`StripeWebhookHandler`, parts of `CertGameSessionService` and `EntitlementGuard`). The
reason is documented in code comments — the Site Guest User has no record-level sharing on
gameplay objects, but identity is established by the verified signature, so row-level
sharing is not the security boundary.
