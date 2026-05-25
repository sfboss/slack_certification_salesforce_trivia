---
title: Platform & Operations
icon: material/cog-outline
---

# :material-cog-outline: Platform & Operations

The plumbing: runtime configuration, idempotency logs, audit trail, async job tracking, and the two platform events that power live UI updates.

---

## :material-tune-vertical: App_Setting__mdt

**Purpose.** Custom Metadata Type holding **every runtime knob** — feature flags, quotas, model defaults, and Named-Credential pointers. The single `Default` record is read at startup by `AppSettings`.

!!! danger "`App_Setting.Default.md-meta.xml` is `.forceignore`d"
    The live `Default` record holds Slack tokens and is managed **in-org only**. Do not commit changes to it; do not deploy it.

| Field | Type | Set by | Purpose |
|-------|------|--------|---------|
| `Default_Provider__c` | Picklist | :material-pencil-outline: editable | `OpenAI` / `Gemini` / `Claude` / `Mock` — drives `QuestionGenerationProviderFactory`. |
| `Default_Model__c` | Text(80) | :material-pencil-outline: editable | Model id (e.g. `gpt-4.1-mini`). |
| `Feature_Flag_Generation__c` | Checkbox | :material-pencil-outline: editable | Kill switch for LLM generation. |
| `Feature_Flag_Billing__c` | Checkbox | :material-pencil-outline: editable | Kill switch for Stripe pathways. |
| `Feature_Flag_Tournaments__c` | Checkbox | :material-pencil-outline: editable | Hides tournament UI. |
| `Feature_Flag_Nudges__c` | Checkbox | :material-pencil-outline: editable | Disables the nudge scheduler. |
| `Max_Games_Per_Day_Free__c` | Number | :material-pencil-outline: editable | Per-player quota for Free tenants. |
| `Max_Generation_Per_Day_Free__c` | Number | :material-pencil-outline: editable | Per-tenant generation quota (Free). |
| `Max_Generation_Per_Day_Pro__c` | Number | :material-pencil-outline: editable | Per-tenant generation quota (Pro). |
| `Max_Questions_Per_Game__c` | Number | :material-pencil-outline: editable | Hard cap on session length. |
| `Slack_Bot_Named_Credential__c` | Text(80) | :material-pencil-outline: editable | Named Credential to use for Slack Web API calls. |
| `Slack_Signing_Secret_Named_Credential__c` | Text(80) | :material-pencil-outline: editable | NC holding the signing secret. |
| `Slack_Bot_Token__c` | Text(255) | :material-pencil-outline: editable | Bot token (legacy direct storage — prefer NC). |
| `Slack_Signing_Secret__c` | Text(255) | :material-pencil-outline: editable | Signing secret (legacy direct). |
| `Slack_Verification_Token__c` | Text(255) | :material-pencil-outline: editable | Fallback verification token for Sites form-encoded payloads. |
| `Slack_Timestamp_Skew_Seconds__c` | Number | :material-cog-sync-outline: system | HMAC tolerance (default 300). |
| `OpenAI_Named_Credential__c` | Text(80) | :material-pencil-outline: editable | NC for the OpenAI provider. |
| `Stripe_Named_Credential__c` | Text(80) | :material-pencil-outline: editable | NC for Stripe API calls. |
| `Web_Google_Client_Id__c` | Text(255) | :material-pencil-outline: editable | Google OAuth client id used by the web companion. |
| `Web_Session_Secret__c` | Text(128) | :material-pencil-outline: editable | HMAC secret for the web session tokens. |

---

## :material-message-text-clock-outline: Slack_Event_Log__c

**Purpose.** Idempotency log for every inbound Slack payload. `SlackRequestRouter` upserts here on every request; duplicate `Slack_Event_Id__c` short-circuits processing.

| Field | Type | Set by | Purpose |
|-------|------|--------|---------|
| `Slack_Event_Id__c` | Text(120) ext-id | :material-cog-sync-outline: system | Synthesized id (event id for `event_callback`; hash of timestamp+payload for slash/interactive). |
| `Slack_Team_Id__c` | Text(40) | :material-cog-sync-outline: system | Team scope. |
| `Event_Type__c` | Text(80) | :material-cog-sync-outline: system | `slash_command` / `view_submission` / `block_actions` / etc. |
| `Received_At__c` | DateTime | :material-cog-sync-outline: system | Server receipt time. |
| `Payload_Hash__c` | Text(128) | :material-cog-sync-outline: system | SHA-256 of body for tamper detection on replays. |
| `Processed__c` | Checkbox | :material-cog-sync-outline: system | True after handler dispatch returned without throwing. |
| `Processing_Error__c` | LongText | :material-cog-sync-outline: system | Stack/message if dispatch threw. |

!!! warning "Insertion order with `views.open`"
    The log row is inserted **after** dispatch on purpose. Handlers like `/certgame plan|billing` call `views.open` (a callout); Apex forbids callouts after DML in the same transaction. Don't reorder this.

---

## :material-file-document-edit-outline: Audit_Log__c

**Purpose.** Immutable admin-action audit trail. Every "admin did a thing" path writes one row here.

| Field | Type | Set by | Purpose |
|-------|------|--------|---------|
| `Action__c` | Text(80) | :material-cog-sync-outline: system | Verb (`PUBLISH_QUESTION`, `RETIRE_EXAM`, `IMPORT_PACK`). |
| `Target_Type__c` | Text(80) | :material-cog-sync-outline: system | Object API name. |
| `Target_Id__c` | Text(40) | :material-cog-sync-outline: system | Record id. |
| `Actor_Salesforce_User__c` | Lookup → User | :material-cog-sync-outline: system | The internal user. |
| `Actor_Slack_User_Id__c` | Text(40) | :material-cog-sync-outline: system | When the action came from Slack. |
| `Before_JSON__c` | LongText | :material-cog-sync-outline: system | Pre-image. |
| `After_JSON__c` | LongText | :material-cog-sync-outline: system | Post-image. |
| `Occurred_At__c` | DateTime | :material-cog-sync-outline: system | When. |

---

## :material-bug-outline: App_Log__c

**Purpose.** Structured application/error log. Verbosity controlled by `Level__c`.

| Field | Type | Set by | Purpose |
|-------|------|--------|---------|
| `Tenant__c` | Lookup | :material-cog-sync-outline: system | Tenant scope (optional). |
| `Class_Name__c` | Text(120) | :material-cog-sync-outline: system | Apex class. |
| `Method_Name__c` | Text(80) | :material-cog-sync-outline: system | Method. |
| `Level__c` | Picklist | :material-cog-sync-outline: system | `DEBUG` / `INFO` / `WARN` / `ERROR`. |
| `Message__c` | LongText | :material-cog-sync-outline: system | Free-form message. |
| `Stack__c` | LongText | :material-cog-sync-outline: system | Stack trace when applicable. |
| `Correlation_Id__c` | Text(80) | :material-cog-sync-outline: system | Cross-class request correlation id. |
| `Occurred_At__c` | DateTime | :material-cog-sync-outline: system | When. |

---

## :material-robot-outline: Question_Generation_Job__c

**Purpose.** Persistent record of one LLM generation request. Survives the Queueable for forensic replay and bills against `Usage_Metric__c`.

| Field | Type | Set by | Purpose |
|-------|------|--------|---------|
| `Tenant__c` | Lookup | :material-cog-sync-outline: system | Owner. |
| `Certification_Exam__c` | Lookup | :material-pencil-outline: editable | Target exam. |
| `Requested_By__c` | Lookup → User | :material-cog-sync-outline: system | Who clicked Generate. |
| `Provider__c` | Picklist | :material-pencil-outline: editable | `OpenAI` / `Gemini` / `Claude` / `Mock`. Defaults from `App_Setting__mdt`. |
| `Model__c` | Text(80) | :material-pencil-outline: editable | Override of the setting default. |
| `Requested_Question_Count__c` | Number | :material-pencil-outline: editable | Capped 1–25. |
| `Generated_Question_Count__c` | Number | :material-cog-sync-outline: system | Actual rows imported after dedup. |
| `Domain_Focus__c` | LongText(4000) | :material-pencil-outline: editable | Comma-separated domain names to bias toward. |
| `Difficulty_Focus__c` | Picklist | :material-pencil-outline: editable | `Mixed` / `Beginner` / `Intermediate` / `Advanced` / `Expert`. |
| `Prompt_Text__c` | LongText(32k) | :material-pencil-outline: editable | Free-form notes/adjustments from the requester. **Currently captured but not passed to the OpenAI provider — see [Prompts](../generation/prompts.md#future-prompt-text).** |
| `Output_JSON__c` | LongText(131k) | :material-cog-sync-outline: system | Raw provider response (truncated at 131k chars). |
| `Status__c` | Picklist | :material-cog-sync-outline: system | `Queued` / `Running` / `Completed` / `Failed` / `Cancelled`. |
| `Error_Message__c` | LongText | :material-cog-sync-outline: system | Set on failure. |
| `Token_Cost_USD__c` | Currency | :material-cog-sync-outline: system | Estimated cost. |

---

## :material-flash-outline: Platform Events

### QuestionGenerationJob__e

Fires on every state transition of a generation job. Consumed by the `generationJobConsole` LWC to stream progress without polling.

| Field | Type | Purpose |
|-------|------|---------|
| `Job_Id__c` | Text(120) | Record id of the `Question_Generation_Job__c`. |
| `Tenant_Id__c` | Text(120) | Tenant scope for the LWC filter. |
| `Status__c` | Text(120) | Current status. |
| `Generated_Count__c` | Number | Running count. |
| `Message__c` | LongText | Progress message or error. |

### QuestionAnswered__e

Fires on every player answer. Consumed by `AchievementService` to evaluate badge thresholds without coupling to the scoring transaction.

| Field | Type | Purpose |
|-------|------|---------|
| `Session_Id__c` | Text(40) | The `Game_Session__c` id. |
| `Round_Id__c` | Text(40) | The `Game_Round__c` id. |
| `Player_Id__c` | Text(40) | The `Player__c` id. |
| `Is_Correct__c` | Checkbox | Scoring result. |
| `Points__c` | Number | Points awarded. |
