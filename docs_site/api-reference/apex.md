# Apex Reference

Method-level reference for the Apex surface. Signatures cited from
[force-app/main/default/classes/](https://github.com/sfboss/slack_certification_salesforce_trivia/tree/main/force-app/main/default/classes).
Test classes (`*_Test.cls`) are documented in [Testing](../development/testing.md).

---

## Ingress

### `SlackEventsRestResource`

`@RestResource(urlMapping='/slack/events')` · `global without sharing`.

```apex
@HttpPost
global static void doPost()
```

- Reads raw body (or reconstructs canonical form-encoded body from `RestRequest.params`).
- Calls `SlackRequestRouter.dispatch(headers, body, contentType)`.
- Returns `200` with the router body. On unhandled error, returns `200` with empty body to
  prevent Slack retry storms; the exception is logged.

### `StripeWebhookHandler`

`@RestResource(urlMapping='/stripe/webhook')` · `global without sharing`.

- Verifies `Stripe-Signature` via `StripeSignatureVerifier`.
- Upserts `License_Event__c` keyed by `Stripe_Event_Id__c`.
- Mutates `Tenant__c.Plan__c` / `Status__c` per event type.

---

## Verification

### `SlackSignatureVerifier`

`with sharing`. ≥95% coverage required.

```apex
public static Boolean verify(Map<String,String> headers, String rawBody)
public static Boolean verifyByToken(Map<String,String> headers, String submittedToken)
@TestVisible private static String secretOverride
```

- `verify`: HMAC-SHA256 over `v0:{ts}:{body}` vs `X-Slack-Signature`. Enforces
  `App_Setting__mdt.Slack_Timestamp_Skew_Seconds__c` (default 300s).
- `verifyByToken`: legacy-token fallback for form-encoded slash commands (Sites strips raw
  bytes, breaking HMAC byte parity).
- Constant-time comparison.

### `StripeSignatureVerifier`

Same shape as Slack: HMAC + timestamp skew + `@TestVisible secretOverride`.

---

## Routing

### `SlackRequestRouter`

`with sharing`.

```apex
public class RouterResult {
    public Integer statusCode = 200;
    public String body = '';
    public Boolean alreadyProcessed = false;
}

public static RouterResult dispatch(
    Map<String,String> headers,
    String rawBody,
    String contentType
)
```

Behavior:

1. Short-circuit `url_verification` before any signature work.
2. Verify signature (HMAC, then token fallback for form-encoded).
3. Lookup `Slack_Event_Log__c` by synthesized id. If `Processed__c = true`, return early.
4. Dispatch by inferred type:
    - `slash_command` → `SlackCertGameCommandHandler.handle`
    - `block_actions` → `SlackCertGameInteractionHandler.handle`
    - `view_submission` / `view_closed` → `SlackCertGameModalHandler.handle`
    - `event_callback` → `SlackCertGameEventHandler.handle`
5. Insert `Slack_Event_Log__c` **after** dispatch (handlers may make callouts; no DML
   before callouts in same transaction).

---

## Handlers

### `SlackCertGameCommandHandler`

`with sharing`.

```apex
public static String handle(Map<String,Object> payload)
```

Dispatch table (from
[`SlackCertGameCommandHandler.cls`](https://github.com/sfboss/slack_certification_salesforce_trivia/blob/main/force-app/main/default/classes/SlackCertGameCommandHandler.cls)):

| Sub                  | Service call                                          |
| -------------------- | ----------------------------------------------------- |
| `help`               | `CertGameSlackRenderService.help()`                   |
| `play`               | `CertGameSessionService.startQuickGameFromSlack(...)` |
| `challenge` / `duel` | `CertGameDuelService.openChallengeFromSlack(...)`     |
| `games`              | `CertGameExamCatalogService.renderForSlack(...)`      |
| `leaderboard`        | `CertGameLeaderboardService.renderLeaderboard(...)`   |
| `stats`              | `CertGameLeaderboardService.renderStats(...)`         |
| `plan`               | `CertGameStudyPlanService.openPlanModal(...)`         |
| `billing`            | `CertGameBillingService.openBillingModal(...)`        |
| `debug`              | Inline render of last hour `App_Log__c`.              |
| `doctor`             | `CertGameDoctorService.run(...)`                      |
| `notify-test`        | `CertGameNotificationTestService.run(...)`            |

### `SlackCertGameInteractionHandler`

Handles `block_actions` payloads. Routes by `action_id` prefix
(`game:answer:`, `duel:accept:`, etc.) to the appropriate service.

### `SlackCertGameModalHandler`

Handles `view_submission` and `view_closed`. Dispatches by `callback_id` to study plan
save, billing actions, etc.

### `SlackCertGameEventHandler`

Handles `event_callback` payloads:

- `app_home_opened` → `CertGameAppHomeService.publishHome(...)`
- `app_mention` → analytics logging.

---

## Services

### `CertGameSessionService`

`without sharing` (Guest User identity is established via signature, not sharing rules).

```apex
public static String startQuickGameFromSlack(
    String slackTeamId, String slackUserId,
    String slackChannelId, List<String> args
)
public static String recordAnswerFromSlack(
    String slackTeamId, String slackUserId,
    String roundId, String choiceId
)
```

- Creates `Game_Session__c` with `Mode__c = 'Solo'`, `Total_Questions__c = 5`, timer 30s.
- `openNextRound` picks a `Published` `Trivia_Question__c` not yet asked in this session.
- `recordAnswerFromSlack` upserts `Player_Answer__c` by `Unique_Key__c` (`round:player`),
  scores via `CertGameScoringService`, advances round or finalizes.

### `CertGameScoringService`

`with sharing` · pure functions · ≥95% coverage.

```apex
public class Input  { Boolean correct; String difficulty; Integer timeRemainingSec, timeLimitSec, streakLength; Boolean penaltyEnabled; }
public class Output { Integer pointsAwarded, basePoints, timeBonus, streakBonus, penalty, newStreakLength; }

public static Output score(Input inp)
public static List<Output> scoreAll(List<Input> ins)
public static Integer baseFor(String difficulty)
```

Formula: see [Features → Scoring](../user-guide/features.md#scoring-formula).

### `EntitlementGuard`

`with sharing` · ≥95% coverage.

```apex
public static Boolean canStartGame(Id tenantId)
public static Boolean canGenerateQuestions(Id tenantId, Integer requested)
public static Boolean canCreateTournament(Id tenantId)
public static void requireCanStartGame(Id tenantId) // throws EntitlementException
public static String currentPeriod()
```

Reads `Tenant__c.Plan__c`, counts `Usage_Metric__c` for current period
(`YYYY-MM`), and compares against per-plan limits.

### `CertGameTenantService`

```apex
public static Tenant__c getOrCreateTenant(String slackTeamId)
public static Player__c getOrCreatePlayer(Id tenantId, String slackUserId)
```

Upserts by `Slack_Team_Id__c` and `Slack_User_Id__c` respectively.

### `CertGameImportService`

`with sharing` · `@AuraEnabled`.

```apex
public class ImportResult {
    Boolean success; List<String> errors;
    Id examId; Id questionBankId;
    Integer questionsCreated; Integer questionsUpdated;
    List<String> duplicateExternalIds;
}

@AuraEnabled
public static ImportResult importPack(String jsonBody)
```

Pipeline:

1. `QuestionJsonValidator.validate(json)` — fail closed on schema errors.
2. Upsert `Certification_Exam__c` by `Certification_Code__c`.
3. Upsert `Question_Bank__c` by `External_Id__c`.
4. Upsert `Trivia_Question__c` records by `External_Id__c` — **always as `Draft`**.
5. Insert `Trivia_Answer_Choice__c` and `Question_Citation__c` children.

### `QuestionJsonValidator`

```apex
public class Result { Boolean valid; List<String> errors; }
public static Result validate(String jsonBody)
```

Schema and business-rule validation (exactly one correct for Single Select, ≥2 choices,
required citations, allowed source types).

### `QuestionDuplicateDetector`

```apex
public static String hash(Trivia_Question__c q, List<Trivia_Answer_Choice__c> choices)
public static List<Id> findCollisions(List<Trivia_Question__c> qs)
```

SHA-256 over normalized stem + correct-choice text, stored on
`Trivia_Question__c.Hash__c`.

### `CertGameDuelService`

`without sharing`.

```apex
public static String openChallengeFromSlack(
    String slackTeamId, String slackUserId,
    String slackChannelId, List<String> args
)
public static String accept(String groupId, String slackUserId)
public static String decline(String groupId, String slackUserId)
public static void finalizeDuel(String groupId)
```

Creates paired `Game_Session__c` rows linked by `Duel_Group_Id__c`. The finale uses
`@future(callout=true)` posted from `CertGameSessionService.recordAnswerFromSlack` to
avoid "callout after DML."

### `CertGameTournamentService`

Tournament scheduling + bracket play. Bracket algorithms in `CertGameBracketGenerator`
(RoundRobin, SingleElimination, OpenLadder).

### `CertGameAchievementService`

```apex
public static void evaluate(Player_Answer__c pa)
public static void evaluateBulk(List<Player_Answer__c> pas)
```

Awards `Player_Achievement__c` rows and DMs the player when a badge is newly earned.

### `CertGameStudyPlanService`

Opens / persists study plan via Slack modals. Drives `CertGameNudgeScheduler`.

### `CertGameLeaderboardService`

```apex
public static String renderLeaderboard(String teamId, String channelId, List<String> args)
public static String renderStats(String teamId, String userId)
public static Leaderboard_Snapshot__c snapshot(Id tenantId, Id examId)
```

### `CertGameBillingService`

```apex
public static String openBillingModal(String teamId, String userId, String triggerId)
public static String openCustomerPortal(Id tenantId)
```

Only callable when `Feature_Flag_Billing__c = true` and the user is in
`Tenant__c.Admin_Slack_User_Ids__c`.

### `CertGameAppHomeService`

```apex
public static void publishHome(String teamId, String userId)
public static Map<String,Object> buildHomeView(Player__c player)
```

Calls `views.publish` via `SlackApiClient`.

### `CertGameSlackRenderService`

Single owner of every Block Kit response. Examples:

```apex
public static String help()
public static String text(String message, Boolean ephemeral)
public static String questionCard(Game_Session__c s, Game_Round__c r,
                                  Trivia_Question__c q, List<Trivia_Answer_Choice__c> choices)
public static String explanationCard(...)
public static String finaleCard(...)
public static List<Map<String,Object>> duelChallengeBlocks(...)
public static List<Map<String,Object>> duelStartedBlocks(...)
public static List<Map<String,Object>> duelFinaleBlocks(...)
public static String debugLogBlocks(List<App_Log__c> rows)
public static String errorEnvelope(String sub, String correlationId, Exception e)
```

### `SlackApiClient`

Outbound Slack Web API wrapper. Endpoint pattern:
`callout:Slack_Bot/<method>`.

```apex
public static HttpResponse postMessage(Map<String,Object> body)
public static HttpResponse postEphemeral(Map<String,Object> body)
public static HttpResponse openView(String triggerId, Map<String,Object> view)
public static HttpResponse publishView(String userId, Map<String,Object> view)
public static HttpResponse usersInfo(String userId)
```

### `CertGameDoctorService`

`/certgame doctor` self-test. Validates named credentials, custom metadata, presence of
published questions, ability to render the App Home view.

### `CertGameNotificationTestService`

`/certgame notify-test` — posts a sample card via `SlackApiClient`.

---

## Async

### `CertGameGenerationJobQueueable`

`Queueable, Database.AllowsCallouts`.

```apex
public CertGameGenerationJobQueueable(Id jobId)
public void execute(QueueableContext qc)
```

- Reads `Question_Generation_Job__c` row.
- Resolves `QuestionGenerationProvider` via `QuestionGenerationProviderFactory`.
- Calls provider, validates JSON via `QuestionJsonValidator`, inserts `Trivia_Question__c`
  rows as **Draft**.
- Publishes `QuestionGenerationJob__e` updates.
- Records token usage on `Usage_Metric__c`.

### `CertGameNudgeScheduler`

`Schedulable`.

```apex
public void execute(SchedulableContext sc)
```

Finds active `Study_Plan__c` records due for a nudge and DMs the player via
`SlackApiClient.postMessage`.

---

## Providers

### `QuestionGenerationProvider` (interface)

```apex
public interface QuestionGenerationProvider {
    String generate(Id jobId);
}
```

Implementations:

- `OpenAIQuestionProvider` — Named Credential `OpenAI`. Reads model from
  `App_Setting__mdt.Default_Model__c`.
- `GeminiQuestionProvider` — Named Credential `Gemini`.
- `ClaudeQuestionProvider` — Named Credential `Anthropic`.

### `QuestionGenerationProviderFactory`

```apex
public static QuestionGenerationProvider get(String providerName)
```

---

## Utility

### `AppSettings`

```apex
public static App_Setting__mdt get()  // cached
```

Reads the `Default` record of `App_Setting__mdt`.

### `AppLogger`

```apex
public static void info(String cls, String method, String message)
public static void warn(String cls, String method, String message)
public static void error(String cls, String method, String message, Exception e)
public static String currentCorrelationId()
```

Writes `App_Log__c` rows. Used inside handlers and services. Never called before a callout
in the same transaction.

### `AuditLogger`

```apex
public static void publish(Id recordId, String action, Map<String,Object> details)
```

Writes `Audit_Log__c` rows for security-relevant actions.
