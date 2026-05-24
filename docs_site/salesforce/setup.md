# Salesforce Setup

## Org options

Any of the following will work:

- **Scratch org** (recommended for development) — see
  [Installation §2](../getting-started/installation.md#2-create-a-scratch-org).
- **Sandbox** — deploy via `sf project deploy start -o <sandboxAlias>`.
- **Production / Developer Edition** — install the 2GP package once published.

The scratch definition is in
[config/project-scratch-def.json](https://github.com/sfboss/slack_certification_salesforce_trivia/blob/main/config/project-scratch-def.json).

## Deployment

```bash
sf project deploy start -o certgame --ignore-conflicts
```

For a deeper guide (including partial deploys and validation), see
[Deployment](deployment.md).

## Custom Metadata defaults

Open **Setup → Custom Metadata Types → App Setting → Manage → Default** and review:

| Field                             | Default              | Purpose                                          |
| --------------------------------- | -------------------- | ------------------------------------------------ |
| `Max_Questions_Per_Game__c`       | 65                   | Cap per `Game_Session__c`.                       |
| `Max_Games_Per_Day_Free__c`       | 5                    | Free-plan rate limit.                            |
| `Max_Generation_Per_Day_Pro__c`   | 100                  | Generation cap.                                  |
| `Feature_Flag_Generation__c`      | true                 | Toggle LLM-based question generation.            |
| `Feature_Flag_Tournaments__c`     | true                 | Tournament UI + `/certgame` support.             |
| `Feature_Flag_Billing__c`         | false                | Enables Stripe webhook + `/certgame billing`.    |
| `Feature_Flag_Nudges__c`          | true                 | Daily nudges from `CertGameNudgeScheduler`.      |
| `Slack_Timestamp_Skew_Seconds__c` | 300                  | HMAC replay window.                              |
| `Slack_Signing_Secret__c`         | _(blank)_            | HMAC secret used by `SlackSignatureVerifier`.    |
| `Slack_Verification_Token__c`     | _(blank)_            | Legacy token fallback for form-encoded requests. |
| `Default_Model__c`                | _(provider default)_ | Model name for `OpenAIQuestionProvider`.         |

## Permission sets

The package ships these permission sets (under
[force-app/main/default/permissionsets](https://github.com/sfboss/slack_certification_salesforce_trivia/tree/main/force-app/main/default/permissionsets)):

| Permission Set                | Grant to                 | Includes                                                                              |
| ----------------------------- | ------------------------ | ------------------------------------------------------------------------------------- |
| `Cert_Game_Admin`             | Internal admins          | Full CRUD on all 27 objects, tab + app visibility for Cert Game Manager.              |
| `Cert_Game_Question_Reviewer` | Reviewers                | CRUD on `Trivia_Question__c`, `Trivia_Answer_Choice__c`, `Question_Citation__c`.      |
| `Cert_Game_Player_Manager`    | Support                  | CRUD on `Player__c`, `Game_Session__c`, `Player_Answer__c`.                           |
| `Cert_Game_Tenant_Admin`      | Org owners               | CRUD on `Tenant__c`, `Usage_Metric__c`, `License_Event__c`.                           |
| `Cert_Game_Integration_User`  | Slack / Stripe site user | Minimum to write `Slack_Event_Log__c`, `License_Event__c`, and read entitlement data. |
| `Cert_Game_Read_Only`         | Auditors                 | Read-only across the suite.                                                           |

Bundle: **`Cert_Game_All_Admin`** (Permission Set Group) combines admin + reviewer +
player-manager + tenant-admin. Assign with:

```bash
sf org assign permsetgroup -n Cert_Game_All_Admin -o certgame
```

## Named Credentials

The package contains four named credentials as no-auth shells. Bind the secrets at install:

| Named Credential | Purpose                                                                              |
| ---------------- | ------------------------------------------------------------------------------------ |
| `Slack_Bot`      | Outbound calls to Slack Web API (`chat.postMessage`, `views.open`, `views.publish`). |
| `Slack_Signing`  | Stores the Slack signing secret.                                                     |
| `OpenAI`         | Outbound calls to OpenAI for question generation.                                    |
| `Stripe`         | Outbound calls to Stripe API + signing secret for inbound webhook verification.      |

Per-credential setup details: [Authentication](authentication.md).

## Public site

Slack and Stripe webhooks reach Salesforce through a public Site that exposes the Apex
REST resource:

- `/services/apexrest/slack/events` → `SlackEventsRestResource`
- `/services/apexrest/stripe/webhook` → `StripeWebhookHandler`

Site config lives at
[force-app/main/default/sites](https://github.com/sfboss/slack_certification_salesforce_trivia/tree/main/force-app/main/default/sites)
with a Guest User profile that has access only to those endpoints.

The default site URL in a fresh scratch org follows the pattern:

```text
https://<scratch-domain>.scratch.my.salesforce-sites.com/services/apexrest/slack/events
```

Use that URL in all three Slack manifest fields.
