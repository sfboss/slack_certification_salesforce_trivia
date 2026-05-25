---
title: Conventions & Legend
icon: material/map-legend
---

# :material-map-legend: Conventions & Legend

This page is the reading key for every other page in the [Data Model](index.md) section.

## Field category icons

Every field row carries one of these icons in the **Set by** column. They tell you, at a glance, whether a human or the system owns the value — which is the single most important fact when you're debugging "why is this field empty?" or "can I edit this on a record page?"

| Icon | Category | Meaning | Examples |
|------|----------|---------|----------|
| :material-pencil-outline: | **editable** | A human sets this via UI, import, or admin script. Layouts include it as editable. | `Trivia_Question__c.Question_Text__c`, `Tenant__c.Plan__c`, `Achievement__c.Threshold__c` |
| :material-cog-sync-outline: | **system** | Only Apex/queueables write this. External-id fields, hashes, timestamps, denormalized snapshots, dedup keys. Layouts should show read-only. | `Trivia_Question__c.Hash__c`, `Player_Answer__c.Question_Domain__c`, `Slack_Event_Log__c.Slack_Event_Id__c` |
| :material-calculator-variant-outline: | **formula** | A `<formula>` element. Derived at read time, no DML possible. | `Player_Topic_Stat__c.Accuracy_Pct__c` |
| :material-table-sync: | **rollup** | Salesforce roll-up summary (none in current model — rollups are computed in Apex on `Player__c`). | _(none)_ |
| :material-link-variant: | **lookup/MD** | Relationship field. Master-Detail is annotated explicitly. | `Trivia_Answer_Choice__c.Trivia_Question__c` (MD) |
| :fontawesome-solid-skull-crossbones: | **deprecated** | Field exists but is no longer written or read. Slated for removal in a future cleanup pass. | _(see individual pages)_ |

!!! warning "System fields are not metadata you can ignore"
    A field marked **system** is still defined in `force-app/main/default/objects/<Object>/fields/`. It's "system" only in the sense that **no human should set it through the UI or a data import**. If you ever find a system field populated by a human, treat it as a bug.

## Sharing model

| Class | Sharing | Why |
|-------|---------|-----|
| `SlackEventsRestResource` | `without sharing` | Slack POSTs as the Sites guest user — guest has no record access. Resource immediately re-enters a `with sharing` service. |
| `WebApiRestResource` | `without sharing` | Same story for the web companion's Google-Sign-In origin. |
| `StripeWebhookHandler` | `without sharing` | Stripe has no user context at all. |
| **Everything else** | `with sharing` | The default and the rule. |

Field-Level Security is enforced on every service path. The `Cert_Game_All_Admin` permission set group bundles `Cert_Game_Admin` + `Cert_Game_Player`; either may need updating when adding fields.

## External-ID idempotency keys

External-id upserts are the spine of every cross-system writeback. **Never** insert these objects with `INSERT`; always `UPSERT` against the keyed field.

| Object | External ID field | Format | Owner |
|--------|-------------------|--------|-------|
| `Certification_Exam__c` | `Certification_Code__c` | e.g. `ADM-201` | Import |
| `Question_Bank__c` | `External_Id__c` | `<examCode>-<pack-slug>` | Import |
| `Trivia_Question__c` | `External_Id__c` | `<examCode-lower>-<topic-slug>-<NN>` | Import / Generator |
| `Tenant__c` | `Slack_Team_Id__c` | Slack `T…` id | `SlackInstallService` |
| `Player__c` | `Slack_User_Id__c` _and_ `Google_Sub__c` | dual-key | `SlackInstallService` / `WebAuthService` |
| `Slack_Event_Log__c` | `Slack_Event_Id__c` | synth id from router | `SlackRequestRouter` |
| `License_Event__c` | `Stripe_Event_Id__c` | Stripe `evt_…` | `StripeWebhookHandler` |
| `Usage_Metric__c` | `Unique_Key__c` | `<tenantId>:<YYYY-MM>` | `EntitlementGuard` |
| `Player_Answer__c` | `Unique_Key__c` | `<roundId>:<playerId>` | `CertGameSessionService` |
| `Player_Achievement__c` | `Unique_Key__c` | `<playerId>:<achievementCode>` | `AchievementService` |
| `Tournament_Participant__c` | `Unique_Key__c` | `<tournamentId>:<playerId>` | `TournamentService` |
| `Player_Topic_Stat__c` | `Topic_Key__c` | `<playerId>\|<type>\|<lower(value)>` | `CertGamePlayerInsightsService` |

## Naming conventions

- **Objects**: noun, `__c` suffix. Junction objects use the two parent names joined (`Player_Achievement__c`, `Tournament_Participant__c`).
- **Picklists**: PascalCase or Title Case values; never mix in one field.
- **Booleans**: positive phrasing — `Active__c`, `Premium_Only__c`, `Public_Join_Enabled__c`. Never `Disabled__c`.
- **Timestamps**: `*_At__c` for DateTime, `*_Date__c` for Date.
- **IDs from foreign systems**: `<System>_<Thing>_Id__c` — e.g. `Slack_Team_Id__c`, `Stripe_Customer_Id__c`.
- **JSON blobs**: `*_JSON__c` LongText — always parse defensively; never trust shape.

## What's deliberately denormalized

Several `Player_Answer__c` fields snapshot question metadata at answer time (`Question_Domain__c`, `Question_Keywords__c`, `Question_Difficulty__c`, `Question_Tags__c`). This is **on purpose** — questions can be edited or retired after the answer, and analytics need to keep telling the truth.

!!! note "Rule of thumb"
    If you find yourself adding a formula or trigger to keep these in sync with the live question, stop. The snapshot is the source of truth for the answer.
