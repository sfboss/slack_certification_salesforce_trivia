# AGENTS.md — Build Instructions for Slack Certification Trivia (Salesforce-Managed)

This file is the authoritative guide for any AI agent or human contributor building this application. Read [README.md](README.md) for the product/architecture spec. This file tells you **how to build it, in what order, with what conventions**.

---

## 0. Ground rules

1. **Salesforce is the source of truth.** Slack is a thin controller. Never store gameplay state only in Slack.
2. **Drafts never play live.** Generated questions are inert until a human flips `Trivia_Question__c.Status__c = Published`.
3. **No secrets in code.** All API keys (Slack signing secret, OpenAI/Gemini/Claude, Stripe) go through Named Credentials + External Credentials.
4. **CRUD/FLS + `with sharing`** on every user-touching Apex class. This is a Security Review hard requirement.
5. **Idempotency everywhere** that touches an external system (Slack retries, Stripe webhooks, LLM callbacks). Use `Slack_Event_Log__c` / `License_Event__c` external-id uniqueness.
6. **Bulkify.** No SOQL/DML in loops. Service methods accept `List<>` first, single-record convenience methods wrap them.
7. **Custom Metadata, not constants.** Quotas, model names, provider defaults, feature flags live in `App_Setting__mdt`.
8. **No emoji in code.** Emoji only in Block Kit user-facing strings.
9. **Tests required.** ≥85% coverage overall, ≥95% on `EntitlementGuard`, `SlackSignatureVerifier`, `CertGameScoringService`, `StripeWebhookHandler`.

---

## 1. Toolchain

Install / verify:

```bash
node --version          # 20+
sf --version            # Salesforce CLI v2+
python3 --version       # 3.11+
git --version
```

Recommended VS Code extensions: Salesforce Extension Pack, Apex PMD, ESLint, Prettier (with `prettier-plugin-apex`).

---

## 2. Repo scaffold

```bash
cd /Users/clayboss/projects/slack_certification_salesforce_trivia

sf project generate --name cert-trivia-slack-manager --output-dir .
mv cert-trivia-slack-manager/* . && rmdir cert-trivia-slack-manager

mkdir -p scripts sample_data docs \
  force-app/main/default/{customMetadata,namedCredentials,remoteSiteSettings,platformEventChannels,permissionsetgroups,sites}
```

Add `.gitignore` entries for `.sf/`, `.sfdx/`, `node_modules/`, `__pycache__/`, `*.log`, `dist/`.

Set up Python tooling for scripts:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install jsonschema requests simple-salesforce python-dotenv
pip freeze > scripts/requirements.txt
```

---

## 3. Phase-by-phase build plan

Each phase ends with a working, demoable slice. Do not start phase N+1 until phase N is green.

### Phase 1 — Data model + sample content (MVP foundation)

1. Create custom objects from [README.md §3](README.md#3-salesforce-data-model). Use master-detail where indicated (`Trivia_Answer_Choice__c → Trivia_Question__c`).
2. Create `App_Setting__mdt` with fields listed in README.
3. Create permission sets:
   - `Cert_Game_Admin`, `Cert_Game_Question_Reviewer`, `Cert_Game_Player_Manager`, `Cert_Game_Tenant_Admin`, `Cert_Game_Read_Only`, `Cert_Game_Integration_User`.
   - Bundle into `Cert_Game_All_Admin` Permission Set Group.
4. Write [sample_data/adm201-question-pack.sample.json](sample_data/adm201-question-pack.sample.json) — 10 questions, full citations.
5. Write [scripts/validate-question-json.py](scripts/validate-question-json.py) using `jsonschema` against the contract in README §7.
6. Spin a scratch org and deploy:

```bash
sf org create scratch -f config/project-scratch-def.json -a certgame -d -y 30
sf project deploy start -o certgame
sf org assign permsetgroup -n Cert_Game_All_Admin -o certgame
```

**Exit criteria:** Objects deploy, sample JSON validates, permission set group assigned.

### Phase 2 — Import pipeline + review LWC

1. Apex: `CertGameImportService.importPack(String json)` — parses pack, upserts `Certification_Exam__c` / `Exam_Domain__c` / `Question_Bank__c` / `Trivia_Question__c` / `Trivia_Answer_Choice__c` / `Question_Citation__c` by external id. All inserts `Status__c = Draft`.
2. Apex: `QuestionJsonValidator.validate(String json)` — schema + business rules (exactly one correct for Single Select, etc.).
3. Apex: `QuestionDuplicateDetector.hash(question)` — normalized SHA-256 of question text + correct choice text; flags collisions.
4. LWC `questionReviewConsole`: list drafts, edit choices/explanations/citations inline, set `Status__c = Reviewed` → `Published` with audit trail to `Audit_Log__c`.
5. LWC `questionBankManager`: file upload → calls `CertGameImportService` via `@AuraEnabled`.
6. Python helper [scripts/import-question-bank.py](scripts/import-question-bank.py) using `simple-salesforce` to invoke the Apex REST or anonymous import.

**Exit criteria:** Upload sample pack → see drafts → publish → query `Trivia_Question__c WHERE Status__c='Published'` returns rows.

### Phase 3 — Slack app shell (signing, routing, idempotency)

1. Create Slack app at `api.slack.com/apps`. Enable: slash commands, interactivity, App Home, bot scopes (`commands`, `chat:write`, `im:write`, `users:read`, `app_mentions:read`, `channels:read`).
2. Create a public Salesforce Site (or Experience Cloud site) with an Apex REST endpoint `/services/apexrest/slack/events`.
3. `SlackSignatureVerifier.verify(headers, body)` — HMAC-SHA256 of `v0:{timestamp}:{body}` against signing secret from Named Credential. Reject if `|now − timestamp| > 300s`.
4. `SlackRequestRouter`:
   - Verify signature.
   - Upsert `Slack_Event_Log__c` by `Slack_Event_Id__c`. If `Processed__c = true`, return 200 immediately.
   - Dispatch by payload type: `slash_command` → `SlackCertGameCommandHandler`; `block_actions` / `view_submission` → `SlackCertGameInteractionHandler` / `SlackCertGameModalHandler`; `event_callback` → `SlackCertGameEventHandler`.
5. Configure Named Credential for Slack Web API using a bot token; document setup in [docs/slack-app-setup.md](docs/slack-app-setup.md).

**Exit criteria:** `/certgame help` posts a response from Apex. Slack retries do not double-fire.

### Phase 4 — Single-game loop

1. `SlackCertGameCommandHandler` opens the setup modal via `views.open` (Block Kit JSON built by `CertGameSlackRenderService.buildSetupModal`).
2. On `view_submission`:
   - `EntitlementGuard.checkGameStart(tenant, exam)` — at MVP, allow all; stub in entitlement plumbing.
   - `CertGameSessionService.start(...)` creates `Game_Session__c`, picks N `Trivia_Question__c` (random within filters, only `Published`), shuffles choices per session.
   - Post first question card to the originating channel/DM.
3. `SlackCertGameInteractionHandler` on `block_actions`:
   - Locate `Game_Round__c` by `Slack_Message_Ts__c`.
   - Insert `Player_Answer__c` (unique constraint: Round + Player).
   - `CertGameScoringService.score()` → update `Player_Answer__c.Points_Awarded__c` and `Player__c` rollups.
   - Render explanation card; advance round or finalize.
4. Final card calls `CertGameLeaderboardService.snapshot()` and offers "Export to Salesforce".

**Exit criteria:** End-to-end Solo game in DM: setup → 5 questions → final leaderboard. All state in Salesforce.

### Phase 5 — App Home, study plans, nudges, achievements

1. `SlackCertGameEventHandler` handles `app_home_opened` → `views.publish` with stats from `Player__c`.
2. `Study_Plan__c` CRUD via App Home buttons (modals).
3. Scheduled Apex `CertGameNudgeScheduler` runs hourly; finds `Study_Plan__c` with `Next_Nudge_At__c <= NOW()` AND player timezone window matches; sends DM via Slack `chat.postMessage`.
4. `CertGameAchievementService.evaluate(playerAnswer)` runs on every answer; awards `Player_Achievement__c` and posts a Slack DM if newly earned.

**Exit criteria:** App Home shows real stats. Daily nudge fires. Streak achievement triggers on 5-in-a-row.

### Phase 6 — Tournaments

1. `Tournament__c` + LWC `tournamentBuilder`.
2. `CertGameTournamentService.schedule()` — Scheduled Apex posts kickoff messages.
3. Bracket logic: RoundRobin (all-pairs scores), Elimination (winners advance), OpenLadder (rolling ELO).
4. Sponsor logo rendered in tournament cards via `Tournament__c.Sponsor_Logo_URL__c`.

### Phase 7 — Dynamic generation

1. `QuestionGenerationProvider` interface with `generate(jobId)` returning JSON string.
2. Implement `OpenAIQuestionProvider` first (via Named Credential `OpenAI_API`). Add Gemini/Claude as parallel implementations.
3. Queueable `CertGameGenerationJobQueueable` runs the provider, validates via `QuestionJsonValidator`, inserts drafts, runs `QuestionDuplicateDetector`, records token cost on `Usage_Metric__c`.
4. LWC `generationJobConsole` shows live status via CometD subscription to `QuestionGenerationJob__e` Platform Event.
5. Hard rule: generation output never gets `Status__c = Published` from code. Reviewers only.

### Phase 8 — Multi-tenant + billing

1. `Tenant__c` populated on first Slack OAuth install. Store `Slack_Team_Id__c` as External ID.
2. `EntitlementGuard` fully wired: every handler reads `Tenant__c.Plan__c` + `App_Setting__mdt` quotas + `Usage_Metric__c` for current period.
3. Stripe:
   - Named Credential `Stripe_API`.
   - Public Site endpoint `/services/apexrest/stripe/webhook` → `StripeWebhookHandler` verifies signature with `Stripe-Signature` header, upserts `License_Event__c` keyed by `Stripe_Event_Id__c`, updates `Tenant__c.Plan__c` / `Status__c`.
   - `/certgame billing` modal links to Stripe Customer Portal (admins only — check `Tenant__c.Admin_Slack_User_Ids__c`).
4. Upsell Block Kit: when `EntitlementGuard` blocks, return a card with "Upgrade" button → opens billing modal.

### Phase 9 — Quality, auditing, hardening

1. `verify-citations.py` + Scheduled Apex citation crawler → flags `Question_Citation__c.Broken_Link__c`.
2. `Audit_Log__c` written on publish/edit/retire/generation-approval. Surface in `Audit Log` tab.
3. Add PMD ruleset; enforce in CI.
4. Apex test suite ≥85% coverage. Mock all callouts via `HttpCalloutMock`.
5. Run Salesforce Security Scanner (`sf scanner run`) and fix all High severity issues.

### Phase 10 — Package & list

1. Convert to 2GP unlocked package; cut a `0.1.0-beta` version.
2. When stable, transition to 2GP managed package for AppExchange.
3. Prepare AppExchange listing: screenshots of `certGameAdminHome`, sample Slack flows, security review checklist in [docs/security-review.md](docs/security-review.md).
4. Set up LMA (License Management App) in publisher org; choose Stripe-only OR LMA-only OR both with reconciliation.

---

## 4. Conventions

### Apex

- One class = one responsibility. Services are stateless static methods that accept and return DTOs (inner classes).
- Sharing keywords:
  - `with sharing` for handlers/services invoked from Slack/LWC/Site.
  - `without sharing` only for `StripeWebhookHandler` and integration internals, with justification comment.
- Naming: `*Service`, `*Handler`, `*Provider`, `*Validator`, `*Scheduler`, `*Queueable`.
- Tests live in `force-app/main/default/classes/` with `_Test` suffix; use `@TestSetup` and `Test.startTest()/stopTest()` properly.
- No `SeeAllData=true`.

### LWC

- One folder per component. Use `@wire` for read paths; `@AuraEnabled(cacheable=true)` for read Apex.
- Errors surfaced via `ShowToastEvent`.
- Lightning Design System tokens only — no hard-coded colors except tenant branding fields.

### Slack rendering

- All Block Kit JSON built in `CertGameSlackRenderService`. No inline JSON in handlers.
- Every interactive `action_id` follows `domain:verb:resourceId` (e.g., `game:answer:a01R0000...`).
- All user-facing strings go through a single `CertGameStrings` class so they can be localized later.

### Git

- Branches: `feat/…`, `fix/…`, `chore/…`, `phase-N-…`.
- Commits: Conventional Commits (`feat:`, `fix:`, `refactor:`, `test:`, `docs:`).
- One phase = one PR when feasible; tag releases `v0.<phase>.<patch>`.

---

## 5. Local commands cheat sheet

```bash
# Create / refresh scratch org
sf org create scratch -f config/project-scratch-def.json -a certgame -d -y 30
sf project deploy start -o certgame
sf org assign permsetgroup -n Cert_Game_All_Admin -o certgame
sf org open -o certgame

# Run tests
sf apex run test -o certgame -r human -w 20 --code-coverage

# Validate sample data
python scripts/validate-question-json.py sample_data/adm201-question-pack.sample.json

# Import sample data
python scripts/import-question-bank.py --org certgame --file sample_data/adm201-question-pack.sample.json

# Tail debug logs
sf apex tail log -o certgame

# Security scan
sf scanner run --target "force-app" --format table
```

---

## 6. Definition of Done (per phase)

A phase is done when **all** of these are true:

- [ ] All objects/fields/classes/LWCs in scope deploy clean to a fresh scratch org.
- [ ] Apex tests pass with required coverage thresholds.
- [ ] Manual demo script in `docs/` walks through the new capability end-to-end.
- [ ] No new Salesforce Security Scanner High findings.
- [ ] No hardcoded secrets or URLs.
- [ ] README and AGENTS updated if behavior or contracts changed.
- [ ] Phase tagged in git.

---

## 7. Non-goals (do not build these without explicit ask)

- Standalone web UI for players (Slack is the surface).
- Mobile native app.
- Free-text answer grading (out of scope until Phase 11+).
- Replacement of Salesforce auth with custom auth.
- Real-money prizes (stay in compliant rewards: SWAG, badges, sponsor-provided gifts).

---

## 8. Agent operating instructions

When acting on this repo as an AI agent:

1. Read [README.md](README.md) and this file before making any change.
2. Before adding a field/object/class, check if it already exists.
3. Prefer editing existing files over creating new ones.
4. When a phase's exit criteria are not met, **do not** start the next phase — finish the current one.
5. Surface every change that touches: security model, data model, billing, or Slack scopes. These require explicit human approval.
6. Never commit a Slack token, OpenAI key, Stripe key, or any other secret. If you find one, rotate it and remove it from history.
7. If unsure, write a question into `docs/open-questions.md` rather than guessing.
