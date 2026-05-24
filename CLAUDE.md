# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Salesforce DX (2GP) package — `CertGameSlackManager` — that delivers a certification-exam trivia game with two surfaces:

1. **Slack app** (primary): slash commands, Block Kit, App Home, modals. Slack is a thin controller; Salesforce holds all state.
2. **Web companion** (`CertGameWeb` Visualforce page + `/services/apexrest/web/*`): solo play, tournaments, Google Sign-In.

`force-app/main/default/sfdx-project.json` pins API version 60.0. Source-of-truth invariants and the phase-by-phase build plan live in [`AGENTS.md`](AGENTS.md) — read it before adding objects, classes, or Slack scopes. DevOps/CI conventions are in [`AGENTS_devops.md`](AGENTS_devops.md). The runtime spec for question-pack JSON lives in [`README.md`](README.md) / sample at `sample_data/`.

## Commands

```bash
# Scratch org bootstrap (Dev Hub required)
sf org create scratch -f config/project-scratch-def.json -a certgame -d -y 30
sf project deploy start -o certgame
sf org assign permsetgroup -n Cert_Game_All_Admin -o certgame
sf org open -o certgame

# Apex tests (run-local; gate at 85% org-wide, 95% on the four critical classes — see below)
sf apex run test -o certgame -r human -w 20 --code-coverage
sf apex run test -o certgame -n CertGameDuelService_Test -r human -w 20    # single class
sf apex run test -o certgame -l RunLocalTests -w 60 -c -r json > reports/tests.json

# LWC unit tests (Jest via sfdx-lwc-jest)
npm test                                # full suite
npx sfdx-lwc-jest -- --testPathPattern questionReviewConsole  # one component
npm run test:unit:watch

# Lint + format (run before committing — husky pre-commit also runs these on staged files)
npm run lint
npm run prettier         # write
npm run prettier:verify  # check only

# Static analysis (Apex; ruleset at pmd-ruleset.xml)
sf scanner run --target "force-app" --format table
sf scanner run --target force-app --severity-threshold 2    # CI gate: 0 high-severity findings

# Sample data
python scripts/validate-question-json.py sample_data/adm201-question-pack.sample.json
python scripts/import-question-bank.py --org certgame --file sample_data/adm201-question-pack.sample.json

# Tail debug logs while exercising Slack/web flows
sf apex tail log -o certgame
```

Anonymous-Apex diagnostic scripts live in `scripts/apex/` (e.g. `diag_slack_bot.apex`, `harness_play_loop.apex`, `tail_slack_log.apex`); run with `sf apex run -o certgame -f scripts/apex/<file>.apex`.

## Architecture

### Slack request flow (the critical path)

External traffic enters at a single endpoint exposed by a public Salesforce Site:

`Slack → POST /services/apexrest/slack/events` → `SlackEventsRestResource` → `SlackRequestRouter.dispatch(headers, body, contentType)` → handler.

`SlackEventsRestResource` is `without sharing` because the guest user posts the request; every downstream service re-establishes `with sharing`. Because Sites consume `application/x-www-form-urlencoded` bodies into `RestRequest.params` before Apex sees the raw bytes, the resource **rebuilds the canonical Slack key order** (`SLACK_CANONICAL_ORDER`) so HMAC verification can succeed — do not change that ordering casually.

`SlackRequestRouter` enforces:

- **HMAC** via `SlackSignatureVerifier.verify` — `v0:{timestamp}:{body}`, reject if timestamp drift > 300s. Form-encoded slash commands/interactions have a documented fallback to Slack's verification token because Sites strip the raw bytes; JSON event callbacks still require HMAC.
- **URL verification handshake** short-circuits before signature checks (the body is Slack-controlled — `{type, challenge, token}`).
- **Idempotency** via `Slack_Event_Log__c` keyed on a synthesized event id. The insert happens *after* dispatch — handlers like `/certgame plan|billing` call `views.open`, and Apex forbids callouts after DML in the same transaction. Don't reorder this.
- **Dispatch table**: `slash_command` → `SlackCertGameCommandHandler`; `block_actions`/`view_submission` → `SlackCertGameInteractionHandler` / `SlackCertGameModalHandler`; `event_callback` → `SlackCertGameEventHandler`.

All Block Kit JSON is built in `CertGameSlackRenderService` — handlers do **not** inline JSON. Interactive `action_id`s follow `domain:verb:resourceId` (e.g. `game:answer:a01R0000…`, `duel:accept:…`). User-facing strings route through `CertGameStrings` (localization seam).

### Game loop

`CertGameSessionService` creates `Game_Session__c`, picks N `Trivia_Question__c` rows (only `Status__c = Published`), and shuffles answer choices per session. `CertGameScoringService.score()` updates `Player_Answer__c.Points_Awarded__c` and `Player__c` rollups. Duels (`Mode__c = 'Duel'`) link two sessions via `Duel_Group_Id__c`; the finale callout is deferred with `@future(callout=true)` from `recordAnswerFromSlack` to avoid "callout after DML."

### Question generation

`QuestionGenerationProvider` interface + `QuestionGenerationProviderFactory` selects an implementation (`OpenAIQuestionProvider`, `GeminiQuestionProvider`, `ClaudeQuestionProvider`) by `App_Setting__mdt`. `CertGameGenerationJobQueueable` runs the provider, validates output via `QuestionJsonValidator`, deduplicates via `QuestionDuplicateDetector.hash`, and inserts **drafts only**. Hard rule: code never sets `Status__c = Published` on generated questions — only the `questionReviewConsole` LWC, driven by a human.

### Multi-tenant + billing

`Tenant__c.Slack_Team_Id__c` is the external id populated on first Slack install. Every user-facing path runs through `EntitlementGuard` which compares `Tenant__c.Plan__c` against `App_Setting__mdt` quotas and `Usage_Metric__c` for the current period. Stripe enters at `/services/apexrest/stripe/webhook` → `StripeWebhookHandler` (the other `without sharing` class — webhooks have no user context), idempotent on `Stripe_Event_Id__c`.

### Web companion

`WebApiRestResource` (`/services/apexrest/web/*`) is a parallel public surface for the Visualforce app. Routes are documented in the class header. Auth is Google Sign-In → `WebAuthService` → opaque session token stored on `Player__c`; LWCs/JS pass `Authorization: Bearer <token>` and Apex resolves via `WebSessionToken`.

## Conventions (don't fight these)

- **Sharing**: `with sharing` everywhere; `without sharing` is reserved for the Sites guest-entry resources (`SlackEventsRestResource`, `WebApiRestResource`) and `StripeWebhookHandler`. Comment the justification when adding one.
- **Bulkify**: services accept `List<>` first; single-record convenience methods wrap. No SOQL/DML in loops.
- **Custom Metadata over constants**: quotas, model names, provider defaults, feature flags live in `App_Setting__mdt`.
- **No emoji in code.** Emoji only in Block Kit user-facing strings.
- **Naming**: `*Service`, `*Handler`, `*Provider`, `*Validator`, `*Scheduler`, `*Queueable`. Tests use `_Test` suffix and `@TestSetup` + `Test.startTest()/stopTest()`. Never `SeeAllData=true`.
- **Coverage gates**: ≥85% org-wide; **≥95%** on `EntitlementGuard`, `SlackSignatureVerifier`, `CertGameScoringService`, `StripeWebhookHandler`.
- **External-id idempotency**: every external-system writeback uses external-id upserts (`Slack_Event_Log__c.Slack_Event_Id__c`, `License_Event__c.Stripe_Event_Id__c`).
- **Secrets** go through Named Credentials (`Slack_Bot`, `Slack_Signing`, `OpenAI`, `Stripe`) + External Credentials. Never commit values. `App_Setting.Default.md-meta.xml` is `.forceignore`d because the live copy carries Slack tokens — manage in-org.
- **LWC**: one folder per component; `@AuraEnabled(cacheable=true)` for reads; SLDS tokens only; errors via `ShowToastEvent`.

## CI/CD

GitHub Actions in `.github/workflows/`:

- `validate-build.yml` — PR / non-main push validation. Creates an ephemeral scratch org (or uses `SFDX_AUTH_URL_SCRATCH` if present), deploys, runs `RunLocalTests`, then **deletes the scratch org on `if: always()`** (Dev Hub limit is 2 active orgs — leaks break the pipeline).
- `deploy.yml` — `push` to `main` / `release: published`. Concurrency-grouped per ref (no `cancel-in-progress`). On failure, the `summarize` step writes `reports/failure_summary.txt` (component failures + Apex test failures + stderr tail) and posts it to Slack via `.github/actions/slack-notify`.
- `scratch-cleanup.yml` — daily reaper for stray `ci-ephemeral-*` orgs.
- `pr-notifications.yml` — PR lifecycle to Slack.

Required secrets: `SFDX_AUTH_URL` (Dev Hub), `SLACK_WEBHOOK_URL`; optional: `SFDX_AUTH_URL_SCRATCH` (pre-provisioned target — when set, scratch creation is skipped and the org is **not** deleted), `SLACK_BOT_TOKEN`, `SLACK_CHANNEL_ID`.

## Where to look

- Apex services and handlers: `force-app/main/default/classes/`
- LWCs: `force-app/main/default/lwc/`
- Custom objects/fields: `force-app/main/default/objects/`
- Custom Metadata defs (e.g. `App_Setting__mdt`): `force-app/main/default/objects/App_Setting__mdt/` (records under `customMetadata/`)
- Site config: `force-app/main/default/sites/certgame.site-meta.xml`
- Visualforce pages (web companion + standard site templates): `force-app/main/default/pages/`
- Permission sets / group: `force-app/main/default/permissionsets/`, `permissionsetgroups/`
- Build plan, conventions, non-goals: [`AGENTS.md`](AGENTS.md)
- CI authoring rules: [`AGENTS_devops.md`](AGENTS_devops.md)
- Slack app setup, security review, LMA: `docs/`
- Sample question packs + JSON schema reference: `sample_data/`, `README.md`
