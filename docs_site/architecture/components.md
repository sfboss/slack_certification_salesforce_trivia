# Components

Inventory of the moving parts. See [Apex reference](../api-reference/apex.md) for method
signatures and [LWC reference](../api-reference/lwc.md) for component details.

## Apex — entry points

| Class | Role |
| --- | --- |
| `SlackEventsRestResource` | `@RestResource` for Slack inbound. |
| `StripeWebhookHandler` | `@RestResource` for Stripe inbound. |
| `SlackRequestRouter` | Verify, idempotency, dispatch. |
| `SlackSignatureVerifier` | HMAC verification + token fallback. |
| `StripeSignatureVerifier` | Stripe HMAC verification. |

## Apex — handlers

| Class | Payload type |
| --- | --- |
| `SlackCertGameCommandHandler` | `slash_command` |
| `SlackCertGameInteractionHandler` | `block_actions` |
| `SlackCertGameModalHandler` | `view_submission`, `view_closed` |
| `SlackCertGameEventHandler` | `event_callback` |

## Apex — services

| Class | Owns |
| --- | --- |
| `CertGameTenantService` | `Tenant__c` / `Player__c` get-or-create. |
| `CertGameSessionService` | Solo and duel game loop. |
| `CertGameScoringService` | Pure scoring math. |
| `CertGameLeaderboardService` | Leaderboard and stats rendering. |
| `CertGameStudyPlanService` | `Study_Plan__c` modal + persistence. |
| `CertGameTournamentService` | Tournament scheduling and bracket play. |
| `CertGameBracketGenerator` | Bracket generation algorithms. |
| `CertGameAchievementService` | Achievement evaluation. |
| `CertGameDuelService` | Duel orchestration. |
| `CertGameAppHomeService` | App Home view rendering. |
| `CertGameBillingService` | Stripe Customer Portal links. |
| `CertGameExamCatalogService` | Exam catalog rendering. |
| `CertGameImportService` | Question pack import. |
| `CertGameQuestionService` | Question read/write helpers. |
| `CertGameSlackRenderService` | All Block Kit JSON. |
| `CertGameStrings` | All user-facing strings. |
| `EntitlementGuard` | Plan + quota checks. |
| `SlackApiClient` | Outbound Slack Web API. |
| `CertGameDoctorService` | `/certgame doctor` self-test. |
| `CertGameNotificationTestService` | `/certgame notify-test`. |

## Apex — async

| Class | Mechanism |
| --- | --- |
| `CertGameGenerationJobQueueable` | Queueable; LLM-driven question generation. |
| `CertGameNudgeScheduler` | Schedulable; daily study-plan nudges. |

## Apex — providers

| Class | Implements |
| --- | --- |
| `QuestionGenerationProvider` | Interface. |
| `OpenAIQuestionProvider` | OpenAI. |
| `GeminiQuestionProvider` | Google Gemini. |
| `ClaudeQuestionProvider` | Anthropic Claude. |
| `QuestionGenerationProviderFactory` | Provider selection by name. |

## Apex — validation / utility

| Class | Role |
| --- | --- |
| `QuestionJsonValidator` | Schema + business rule validation. |
| `QuestionDuplicateDetector` | SHA-256 hashing + collision detection. |
| `AppSettings` | Cached read of `App_Setting__mdt.Default`. |
| `AppLogger` | Structured log writes to `App_Log__c`. |
| `AuditLogger` | Tamper-evident audit trail to `Audit_Log__c`. |

## Apex — LWC controllers

| Class | LWC consumer |
| --- | --- |
| `QuestionReviewController` | `questionReviewConsole` |
| `CertGameAdminDashboardController` | `certGameAdminDashboard` |
| `CertGamePlayerDashboardController` | `certGamePlayerDashboard` |
| `CertGameLeaderboardController` | `certGameLeaderboard` |
| `CertGameBillingController` | `certGameBilling` |

## Lightning Web Components

| LWC | Purpose |
| --- | --- |
| `certGameAdminHome` | The 4-tab admin landing page. |
| `certGameAdminDashboard` | Org-wide metrics. |
| `certGamePlayerDashboard` | Per-player drill-down. |
| `certGameLeaderboard` | Internal leaderboard view. |
| `certGameBilling` | Tenant plan management. |
| `questionBankManager` | Import + bank listing. |
| `questionReviewConsole` | Draft review and publish. |
| `generationJobConsole` | Live stream of `QuestionGenerationJob__e`. |
| `tournamentBuilder` | Tournament + bracket UI. |

## Triggers / platform events

| Object | Event |
| --- | --- |
| `QuestionAnswered__e` | Achievement evaluation feed. |
| `QuestionGenerationJob__e` | Live job status. |

## Scripts

| File | Purpose |
| --- | --- |
| [scripts/validate-question-json.py](https://github.com/sfboss/slack_certification_salesforce_trivia/blob/main/scripts/import_all_packs.py) | Local JSON schema validation. |
| [scripts/import_all_packs.py](https://github.com/sfboss/slack_certification_salesforce_trivia/blob/main/scripts/import_all_packs.py) | Batch upload sample packs via `simple-salesforce`. |
| [scripts/verify-citations.py](https://github.com/sfboss/slack_certification_salesforce_trivia/blob/main/scripts/verify-citations.py) | HEAD-checks citation URLs. |
| [scripts/extract_soql_to_json.py](https://github.com/sfboss/slack_certification_salesforce_trivia/blob/main/scripts/extract_soql_to_json.py) | Captures SOQL query examples. |
| [scripts/apex/](https://github.com/sfboss/slack_certification_salesforce_trivia/tree/main/scripts/apex) | Anonymous Apex diagnostic snippets. |
