# Permissions & Scopes

## OAuth scopes requested by the bot

From [slack-app-manifest.yaml](https://github.com/sfboss/slack_certification_salesforce_trivia/blob/main/slack-app-manifest.yaml):

| Scope | Why we need it |
| --- | --- |
| `app_mentions:read` | Receive `app_mention` events. |
| `channels:read` | Resolve channel names for leaderboards and tournaments. |
| `chat:write` | Post question cards, explanations, finales, nudges. |
| `commands` | Receive `/certgame` slash command invocations. |
| `im:write` | DM players (duels, nudges). |
| `users:read` | Resolve Slack user display names for `Player__c`. |

The detailed setup guide
([docs/slack-app-setup.md](https://github.com/sfboss/slack_certification_salesforce_trivia/blob/main/docs/slack-app-setup.md))
additionally lists these optional scopes for production:

- `chat:write.public` — post to public channels without joining.
- `groups:read` — private channel leaderboards.
- `im:history`, `im:read` — for richer DM flows.
- `team:read` — workspace metadata.
- `users:read.email` *(optional)* — player profile enrichment.

## Why we do **not** request

| Not requested | Why |
| --- | --- |
| `chat:write.customize` | We use the bot identity directly. |
| `files:*` | No file uploads or attachments. |
| `reactions:*` | Score state lives in Salesforce, not on emoji reactions. |
| `users.profile:read` | Display name from `users.info` is sufficient. |
| `admin:*` | The app does not need workspace-admin scopes. |

## Salesforce-side authorization

The Slack-facing Salesforce REST endpoint is reachable only by the Site Guest User. That
user has CRUD access **only** to:

- `Slack_Event_Log__c` (insert)
- `Tenant__c`, `Player__c` (read+upsert via `getOrCreate*`)
- The gameplay objects necessary to start a session and record an answer

Every Apex service that the Guest User reaches re-establishes `with sharing` semantics
through deliberate `without sharing` shims only where Guest user CRUD restrictions would
otherwise block legitimate access — see comments in
[`CertGameSessionService`](../api-reference/apex.md#certgamesessionservice) and
[`EntitlementGuard`](../api-reference/apex.md#entitlementguard) for the rationale.

## Token storage

| Token | Stored in |
| --- | --- |
| Bot User OAuth (`xoxb-…`) | External Credential `Slack_Bot` principal header. |
| Signing Secret | External Credential `Slack_Signing` **and** `App_Setting__mdt.Default.Slack_Signing_Secret__c`. |
| Legacy Verification Token | `App_Setting__mdt.Default.Slack_Verification_Token__c` (optional fallback for form-encoded payloads). |

Never commit any of these. See
[Security review notes](https://github.com/sfboss/slack_certification_salesforce_trivia/blob/main/docs/security-review.md).
