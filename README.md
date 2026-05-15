# Slack Certification Trivia — Salesforce-Managed App

A **Salesforce-managed Slack trivia game** for certification study, team learning, and enablement programs. Salesforce owns content, identity, scoring, billing, and audit. Slack is the game surface.

> Source of truth: Salesforce. Game controller: Slack. Everything packageable, auditable, and AppExchange-ready.

See [AGENTS.md](AGENTS.md) for the step-by-step build guide.

---

## 1. Target architecture

```text
Slack User
  ↓ slash command / shortcut / App Home / button / modal submit
Slack App Interactivity (signed request)
  ↓
Apex Slack Event Router  (signature verify + idempotency)
  ↓
Trivia Game Service Layer  (sessions, scoring, generation, billing)
  ↓
Salesforce Custom Objects + Platform Events
  ↓
Question Bank / Attempts / Scores / Citations / Explanations / Audit / Usage
  ↓
Slack Block Kit messages, modals, App Home, scheduled nudges
```

Slack supports rich Block Kit messages, modals, App Home, buttons, menus, and other interactive components across messages and modals. Messages support up to 50 blocks; modals and Home tabs support up to 100 blocks. ([Slack Developer Docs][1])

Do **not** rely on incoming webhooks alone. Webhooks post static messages; buttons, menus, modals, and game actions require Slack app interactivity with signed request handling. ([Slack Developer Docs][2])

---

## 2. Tech stack

### Salesforce layer

| Area                  | Stack                                          |
| --------------------- | ---------------------------------------------- |
| Backend               | Apex                                           |
| Slack integration     | Salesforce Apex SDK for Slack                  |
| UI admin console      | Lightning Web Components                       |
| Data model            | Custom Objects                                 |
| Config                | Custom Metadata Types                          |
| Feature flags         | Custom Metadata + Permission Sets              |
| Async jobs            | Queueable / Scheduled / Batch Apex             |
| Real-time fan-out     | Platform Events + Change Data Capture          |
| External AI providers | Named Credentials + External Credentials       |
| Secrets               | Named Credentials (no hard-coded API keys)     |
| Permissions           | Permission Sets + Permission Set Groups        |
| Billing               | Stripe via Named Credential (or AppExchange)   |
| Deployment            | SFDX scratch → 2GP unlocked → managed package  |
| Observability         | Custom logging object + Event Monitoring hooks |

The Apex SDK for Slack is purpose-built for Slack apps interacting with Salesforce data through events, shortcuts, and slash commands, and can respond with modals or Slack API calls from Apex. ([Developer][3])

Platform Events power real-time game events: `question_answered`, `round_completed`, `pack_ready`, `leaderboard_updated`, `license_changed`. ([Developer][4])

### Slack layer

| Feature           | Use                                                                                      |
| ----------------- | ---------------------------------------------------------------------------------------- |
| Slash command     | `/certgame …` entry points                                                               |
| Global shortcut   | "Start Certification Trivia"                                                             |
| Message shortcut  | "Challenge this thread"                                                                  |
| Interactivity     | Answer buttons, hints, next question, reveal citation                                    |
| Modals            | Exam pick, game setup, generation request, billing, settings                             |
| App Home          | Dashboard, stats, streaks, exams, billing status                                         |
| Scheduled msgs    | Daily study nudges, weekly recap, tournament reminders                                   |
| Workflow Builder  | Custom org-defined steps ("Start Friday Trivia at 3pm")                                  |
| OAuth scopes      | `commands`, `chat:write`, `users:read`, `im:write`, `app_mentions:read`, `channels:read` |

### AI / question generation layer

```text
QuestionGenerationProvider (interface)
├── OpenAIProvider
├── GeminiProvider
├── ClaudeProvider
├── LocalJsonImportProvider
└── ManualAuthoringProvider
```

Order of trust:

1. Static imported JSON packs (highest reliability)
2. LLM-generated **drafts**
3. Human review in Salesforce (required gate)
4. Published pools playable in Slack

Generated questions **never** reach live gameplay until `Status__c = Published` after reviewer approval.

---

## 3. Salesforce data model

> All custom objects below get `Active__c`, `Tenant__c` (Slack team) where applicable, and audit-friendly history tracking. Indexed external IDs where shown.

### Core content

#### `Certification_Exam__c`

```text
Name
Vendor__c                       // Salesforce, AWS, Google, etc.
Certification_Code__c           (External ID)
Role_Family__c
Difficulty__c
Description__c
Official_Exam_Guide_URL__c
Active__c
Default_Timer_Seconds__c
Passing_Score_Percent__c
Premium_Only__c                 // gating for paid tier
Icon_Emoji__c
```

Seed examples: Salesforce Administrator, Platform App Builder, Platform Developer I, AI Associate, Sales Cloud Consultant, Service Cloud Consultant, Data Cloud Consultant, Agentforce Specialist.

#### `Exam_Domain__c`

```text
Certification_Exam__c (lookup)
Name
Weight_Percent__c
Domain_Order__c
Official_Objective_Text__c
```

#### `Question_Bank__c`

```text
Name
Certification_Exam__c (lookup)
Source_Type__c           // Manual, Generated, Imported, OfficialNotesDerived
Status__c                // Draft, Review, Published, Retired
Version__c
Generated_By_Model__c
Prompt_Version__c
Created_From_File__c
Tenant__c                // null = global; set = tenant-private pack
Premium__c
```

#### `Trivia_Question__c`

```text
Question_Bank__c (lookup)
Certification_Exam__c (lookup)
Exam_Domain__c (lookup)
Question_Text__c (long text)
Scenario_Text__c (long text)
Question_Type__c            // Single Select, Multi Select, True False
Difficulty__c
Status__c                   // Draft, Reviewed, Published, Retired
Correct_Answer_Mode__c      // Exact, AnyOf, MultiRequired
Explanation__c (long text)
Reference_Summary__c (long text)
Citation_Mode__c            // Official, Internal, Generated, Mixed
External_Id__c              (External ID, unique)
Quality_Score__c            // 0-100, AI + reviewer composite
Times_Asked__c
Times_Correct__c
Last_Verified_Date__c
Hash__c                     // for duplicate detection
```

#### `Trivia_Answer_Choice__c`

```text
Trivia_Question__c (master-detail)
Choice_Label__c             // A, B, C, D, E
Choice_Text__c
Is_Correct__c
Explanation__c
Sort_Order__c
```

#### `Question_Citation__c`

```text
Trivia_Question__c (lookup)
Title__c
URL__c
Source_Type__c              // Salesforce Help, Trailhead, Release Notes, Internal Guide
Quote_Or_Reference__c
Relevance_Note__c
Last_Verified_Date__c
Verified_By__c
Broken_Link__c              // periodic crawler flag
```

### Gameplay

#### `Game_Session__c`

```text
Name
Slack_Channel_Id__c
Slack_Team_Id__c            (indexed)
Started_By_Slack_User_Id__c
Certification_Exam__c (lookup)
Mode__c                     // Solo, Channel, Team Battle, Lightning, Study, Exam Sim, Tournament
Status__c                   // Setup, Active, Paused, Complete, Abandoned
Current_Question_Index__c
Total_Questions__c
Timer_Seconds__c
Started_At__c
Completed_At__c
Anti_Cheat_Seed__c          // shuffles choice order deterministically per player
Tournament__c (lookup, optional)
```

#### `Game_Round__c`

```text
Game_Session__c (lookup)
Round_Number__c
Trivia_Question__c (lookup)
Slack_Message_Ts__c
Status__c                   // Posted, Answered, Expired, Explained
Correct_Answer_Revealed__c
Started_At__c
Ended_At__c
```

#### `Player__c`

```text
Slack_User_Id__c            (External ID with team)
Slack_Team_Id__c
Salesforce_User__c (lookup, optional)
Display_Name__c
Mapped_Contact__c (lookup, optional)
Total_Points__c
Total_Games__c
Accuracy__c
Current_Streak_Days__c
Longest_Streak_Days__c
Last_Played_At__c
Notifications_Opt_In__c
Timezone__c
```

#### `Player_Answer__c`

```text
Game_Session__c (lookup)
Game_Round__c (lookup)
Trivia_Question__c (lookup)
Player__c (lookup)
Selected_Choice_Labels__c
Is_Correct__c
Points_Awarded__c
Answered_At__c
Response_Time_Ms__c
Explanation_Shown__c
Hint_Used__c
```

Unique key: `Game_Round__c` + `Player__c` (enforced via duplicate rule or trigger).

#### `Leaderboard_Snapshot__c`

```text
Game_Session__c (lookup)
Snapshot_JSON__c (long text)
Round_Number__c
Posted_To_Slack__c
Slack_Message_Ts__c
```

### Engagement & monetization

#### `Tournament__c`

```text
Name
Slack_Team_Id__c
Certification_Exam__c (lookup)
Start_At__c, End_At__c
Bracket_Type__c             // RoundRobin, Elimination, OpenLadder
Prize_Description__c
Status__c                   // Scheduled, Active, Complete
Sponsor_Logo_URL__c         // enterprise branding
```

#### `Achievement__c` / `Player_Achievement__c`

```text
Achievement__c:
  Name, Code__c (External ID), Description__c, Icon_Emoji__c, Points__c, Premium_Only__c
Player_Achievement__c:
  Player__c (lookup), Achievement__c (lookup), Awarded_At__c, Game_Session__c (lookup)
```

Seed achievements: First Win, Hot Streak (5 in a row), Domain Master, Speed Demon, Comeback Kid, Perfect Round, Exam-Ready.

#### `Study_Plan__c`

```text
Player__c (lookup)
Certification_Exam__c (lookup)
Target_Exam_Date__c
Daily_Questions__c
Weak_Domains_JSON__c
Next_Nudge_At__c
Active__c
```

Drives daily DM nudges via Scheduled Apex.

#### `Tenant__c` (Workspace / Slack team)

```text
Slack_Team_Id__c            (External ID)
Workspace_Name__c
Installed_By_User_Id__c
Installed_At__c
Plan__c                     // Free, Pro, Enterprise
Seats_Purchased__c
Seats_Used__c (formula)
Trial_Ends_At__c
Stripe_Customer_Id__c
Stripe_Subscription_Id__c
Status__c                   // Trial, Active, PastDue, Cancelled, Suspended
Branding_Logo_URL__c
Branding_Primary_Color__c
Data_Region__c              // for residency
Admin_Slack_User_Ids__c     // JSON array
```

#### `License_Event__c`

```text
Tenant__c (lookup)
Event_Type__c               // TrialStarted, Upgraded, Downgraded, Renewed, Cancelled, PaymentFailed
Stripe_Event_Id__c          (External ID, unique → idempotency)
Payload_JSON__c
Occurred_At__c
```

#### `Usage_Metric__c`

```text
Tenant__c (lookup)
Period__c                   // YYYY-MM
Games_Started__c
Questions_Served__c
LLM_Tokens_In__c
LLM_Tokens_Out__c
LLM_Cost_USD__c
Active_Players__c
```

Rolled up nightly by batch; powers billing overage and analytics.

#### `Question_Generation_Job__c`

```text
Certification_Exam__c (lookup)
Tenant__c (lookup)
Requested_By__c
Prompt_Text__c (long text)
Provider__c
Model__c
Status__c                   // Queued, Running, Completed, Failed, Needs Review
Requested_Question_Count__c
Generated_Question_Count__c
Output_JSON__c (long text)
Token_Cost_USD__c
Error_Message__c
```

### Plumbing

#### `Slack_Event_Log__c` (idempotency + audit)

```text
Slack_Event_Id__c           (External ID, unique)
Slack_Team_Id__c
Event_Type__c
Payload_Hash__c
Received_At__c
Processed__c
Processing_Error__c
```

Apex rejects duplicate Slack retries by checking this object before doing work.

#### `Audit_Log__c`

```text
Actor_Slack_User_Id__c
Actor_Salesforce_User__c
Action__c                   // QuestionPublished, QuestionEdited, GenerationApproved, etc.
Target_Type__c, Target_Id__c
Before_JSON__c, After_JSON__c
Occurred_At__c
```

#### `App_Setting__mdt` (Custom Metadata)

```text
Default_Provider__c
Default_Model__c
Max_Questions_Per_Game__c
Max_Generation_Per_Day_Free__c
Max_Generation_Per_Day_Pro__c
Slack_Signing_Secret_Named_Credential__c
Stripe_Named_Credential__c
Feature_Flag_*               // toggles per feature without deploys
```

---

## 4. Slack game UX

### Entry points

```text
/certgame                       → opens setup modal
/certgame admin                 → quick-start Admin exam
/certgame pd1 10 lightning      → quick start PD1, 10 Qs, lightning mode
/certgame leaderboard           → channel leaderboard
/certgame generate admin 10     → request generation (Pro)
/certgame plan                  → show study plan / set exam date
/certgame billing               → opens billing modal (admins only)
/certgame help
```

### App Home

```text
Certification Trivia Manager

Your Stats
  Games Played • Accuracy • Best Exam • Weakest Domain • Streak 🔥

Study Plan
  Target: Platform Developer I — May 30, 2026
  Today: 0 / 10 questions  [Start Today's Set]

Quick Start
  [Solo Game] [Channel Game] [Tournament] [Leaderboard] [Generate Pack]

Available Exams
  Free:  Admin • App Builder • AI Associate
  Pro:   PD1 • PD2 • Data Cloud • Agentforce Specialist  🔒

Workspace Plan
  Pro — 12 / 25 seats used  [Manage Billing]
```

### Setup modal

```text
Exam (picklist; locked items show 🔒 Upgrade)
Mode (Solo, Channel, Team Battle, Lightning, Study, Exam Sim)
Number of questions (5 / 10 / 25 / 65)
Timer per question (15 / 30 / 60 / no timer)
Difficulty filter
Domain filter (multi)
Show explanations immediately?
Include citations?
Shuffle answer order?  (anti-cheat default ON)
```

Modals are the right surface for focused workflows with Block Kit + interactivity. ([Slack Developer Docs][6])

### Question card

```text
📚 Salesforce Admin Trivia — Question 3 of 10
Domain: Security and Access • Difficulty: Intermediate • ⏱ 30s

Scenario:
A sales manager needs users to see records owned by users below them in the role hierarchy…

Q: Which Salesforce feature is most directly responsible?

[ A. Permission Set Group ]
[ B. Organization-Wide Defaults ]
[ C. Role Hierarchy ]
[ D. Login IP Ranges ]

[ 🔍 Hint (-30 pts) ]
```

### After-answer card

```text
✅ Correct  • +120 pts (100 base + 20 speed)

Your answer: C. Role Hierarchy

Explanation:
The role hierarchy opens record access vertically above the owner when sharing settings allow it…

[ Next Question ] [ Full Explanation ] [ Show Citation ] [ Leaderboard ]
```

### Leaderboard card

```text
🏆 Round 5 Leaderboard

1. Clay — 420 pts — 80%
2. Alex — 360 pts — 70%
3. Sam  — 310 pts — 60%

🔥 Clay: 3-in-a-row.  ⚡ Alex: fastest avg 4.2s.

[ Next Question ] [ End Game ] [ Export to Salesforce ]
```

### Daily nudge (DM)

```text
Good morning, Clay 👋
PD1 exam in 16 days. Today's plan: 10 questions, ~7 min.
Weak domains: Process Automation, Apex Testing.

[ Start Today's Set ]   [ Skip Today ]   [ Edit Plan ]
```

---

## 5. Salesforce admin app UI

**Lightning App:** `Certification Trivia Manager`

Tabs: Certification Exams • Question Banks • Questions • Generation Jobs • Game Sessions • Tournaments • Leaderboards • Tenants & Billing • Usage • Audit Log • Settings

### LWC components

| Component                | Purpose                                                               |
| ------------------------ | --------------------------------------------------------------------- |
| `certGameAdminHome`      | Published/draft counts, active games, jobs, top exams, MRR widget     |
| `questionBankManager`    | Upload JSON, validate, preview, bulk publish/retire                   |
| `questionReviewConsole`  | Side-by-side review: text, choices, explanations, citations, AI score |
| `gameSessionMonitor`     | Live sessions, current Q, players, pause/resume/terminate             |
| `leaderboardDashboard`   | Top players, weakest domains, most-missed, readiness scores           |
| `generationJobConsole`   | Prompt config, draft preview, cost estimate, send to review queue     |
| `tournamentBuilder`      | Schedule tournaments, brackets, prizes, sponsor branding              |
| `tenantBillingConsole`   | Plan, seats, Stripe status, invoices, suspend/resume                  |
| `usageAnalytics`         | Tokens, cost, sessions, retention per tenant                          |
| `citationLinkAuditor`    | Crawls citation URLs; flags broken/changed                            |

---

## 6. Apex service architecture

```text
slack/
  SlackRequestRouter.cls            // verify signature, idempotency, dispatch
  SlackCertGameCommandHandler.cls
  SlackCertGameInteractionHandler.cls
  SlackCertGameModalHandler.cls
  SlackCertGameEventHandler.cls     // app_home_opened, app_uninstalled

services/
  CertGameSessionService.cls
  CertGameQuestionService.cls
  CertGameScoringService.cls
  CertGameSlackRenderService.cls    // Block Kit builders
  CertGameCitationService.cls
  CertGameGenerationService.cls
  CertGameImportService.cls
  CertGameLeaderboardService.cls
  CertGameTournamentService.cls
  CertGameStudyPlanService.cls
  CertGameAchievementService.cls
  CertGameNudgeService.cls          // scheduled DMs

billing/
  StripeWebhookHandler.cls          // Site/Experience endpoint
  LicenseService.cls
  UsageMeteringService.cls
  EntitlementGuard.cls              // gate features by plan

providers/
  QuestionGenerationProvider.cls    // interface
  OpenAIQuestionProvider.cls
  GeminiQuestionProvider.cls
  ClaudeQuestionProvider.cls
  QuestionJsonValidator.cls
  QuestionDuplicateDetector.cls     // hash + embedding similarity

platform/
  SlackSignatureVerifier.cls
  AuditLogger.cls
  AppSettings.cls                   // Custom Metadata accessor
  AppLogger.cls
```

### Handler flow

```text
/certgame
  → SlackRequestRouter (verify HMAC, log event, idempotency)
  → SlackCertGameCommandHandler → opens setup modal

setup modal submitted
  → SlackCertGameModalHandler
  → EntitlementGuard.check(Tenant, "GameStart", exam)
  → CertGameSessionService.start()
  → CertGameQuestionService.pickQuestions()
  → CertGameSlackRenderService.postQuestionCard()

answer button clicked
  → SlackCertGameInteractionHandler
  → CertGameScoringService.score()
  → CertGameAchievementService.evaluate()
  → render explanation → advance round
  → publish Platform Event QuestionAnswered__e

leaderboard
  → CertGameLeaderboardService.snapshot() → render
```

---

## 7. Question JSON contract

```json
{
  "exam": { "name": "Salesforce Administrator", "code": "ADM-201" },
  "questionBank": {
    "name": "ADM-201 Practice Pack 001",
    "version": "1.0.0",
    "sourceType": "Generated",
    "status": "Draft"
  },
  "questions": [
    {
      "externalId": "ADM201-SEC-001",
      "domain": "Security and Access",
      "difficulty": "Intermediate",
      "questionType": "Single Select",
      "scenario": "A sales manager needs access to records owned by direct reports.",
      "question": "Which Salesforce feature most directly supports this requirement?",
      "choices": [
        { "label": "A", "text": "Permission Set Group",          "isCorrect": false, "explanation": "PSGs aggregate permissions but do not create hierarchical record access." },
        { "label": "B", "text": "Organization-Wide Defaults",    "isCorrect": false, "explanation": "OWD establishes baseline access only." },
        { "label": "C", "text": "Role Hierarchy",                "isCorrect": true,  "explanation": "Role hierarchy opens record access upward to managers." },
        { "label": "D", "text": "Login IP Ranges",               "isCorrect": false, "explanation": "IP ranges control login, not record access." }
      ],
      "explanation": "Role hierarchy is the most direct mechanism for upward record access through management structure.",
      "citations": [
        {
          "title": "Salesforce Help: Control Access to Records",
          "url": "https://help.salesforce.com/",
          "sourceType": "Salesforce Help",
          "relevanceNote": "Explains record access and role hierarchy."
        }
      ]
    }
  ]
}
```

Validator rejects packs missing: `externalId`, `domain`, ≥3 choices for Single Select, exactly one `isCorrect`, ≥1 citation when `Citation_Mode__c != Generated`.

---

## 8. Game modes

| Mode             | Surface        | Timer    | Scoring           | Notes                                |
| ---------------- | -------------- | -------- | ----------------- | ------------------------------------ |
| Solo Practice    | DM             | Off / 30s| Standard          | Immediate explanation                |
| Channel Trivia   | Public channel | 30s      | Standard          | Public reveal + leaderboard          |
| Team Battle      | Channel        | 30s      | Team aggregate    | Teams assigned at setup              |
| Lightning Round  | Channel / DM   | 10s      | Speed-weighted    | Minimal explanation until end        |
| Study Mode       | DM             | Off      | No points         | Citations always on, weak-domain log |
| Exam Simulation  | DM             | Exam     | Pass/fail report  | 65 Qs weighted by domain             |
| Tournament       | Multi-channel  | Varies   | Bracket / ladder  | Scheduled, optional prizes           |

---

## 9. Scoring

```text
base correct       : 100
speed bonus        : 0–50 (linear with time remaining)
streak bonus       : +25 after 3 correct (compounding cap at +100)
multi-select       : no partial credit (configurable)
hint used          : −30
late answer        : 0 but recorded
exam-sim weight    : domain weight × correctness
```

Formula:

```text
points = max(0, baseCorrect + speedBonus + streakBonus − hintPenalty)
```

---

## 10. Citation and explanation behavior

**During game:** progressive disclosure — domain + difficulty visible, citations behind a button.

**In Salesforce:** every published question has short explanation, long explanation, per-choice explanation, ≥1 citation, last-verified date, source confidence. Nightly batch reverifies URLs and flags broken links on `Question_Citation__c.Broken_Link__c`.

**In Slack:** never overload the initial card. Citations on demand.

---

## 11. Dynamic generation workflow

```text
Admin → LWC `generationJobConsole`
  → select exam / domain / count / difficulty / provider
  → see cost estimate (tokens × model rate)
  → submit
Apex creates Question_Generation_Job__c (Status=Queued)
Queueable calls provider via Named Credential
Provider returns JSON
QuestionJsonValidator enforces schema
QuestionDuplicateDetector hashes + embeds → flags near-dupes
Questions inserted Status=Draft
Reviewer approves in `questionReviewConsole`
Questions become Published
Slack game can use them
UsageMeteringService records token cost on Tenant
```

Drafts only. Human review is non-bypassable in code, not just UI.

---

## 12. Security model

### Slack request security

- Verify `X-Slack-Signature` HMAC-SHA256 against signing secret stored in Named Credential.
- Reject requests with timestamp drift > 5 minutes.
- Idempotency: every Slack event/interaction logged to `Slack_Event_Log__c` keyed by event id; duplicates short-circuit.
- OAuth tokens stored only in protected Custom Metadata or Named Credentials — never in code or regular fields.

### Salesforce permissions

Permission Sets:

```text
Cert_Game_Admin
Cert_Game_Question_Reviewer
Cert_Game_Player_Manager
Cert_Game_Tenant_Admin       // billing & seats
Cert_Game_Read_Only
Cert_Game_Integration_User   // for Slack/Stripe callout user
```

### Identity mapping

```text
Slack_User_Id__c → Player__c → Salesforce_User__c (optional)
```

Apex SDK for Slack provides Slack ↔ Salesforce user mapping services. ([Developer][7])

### Anti-cheat

- Per-player choice order via `Anti_Cheat_Seed__c`.
- Server-authoritative timing (reject answers later than `Game_Round__c.Ended_At__c`).
- One answer per player per round enforced by unique key (`Game_Round__c` + `Player__c`).
- DM-only Exam Sim to prevent channel collaboration.

### Privacy & compliance

- `Tenant__c.Data_Region__c` controls org assignment for residency.
- Right-to-erasure: `LicenseService.purgeTenant(tenantId)` cascades Player / Player_Answer / Audit.
- PII minimal: Slack user id + display name only unless mapped to a Contact.

---

## 13. Monetization

### Plans

| Plan       | Price (example)    | Includes                                                            |
| ---------- | ------------------ | ------------------------------------------------------------------- |
| Free       | $0                 | 3 free exams, solo + channel modes, 5 games/day, no generation      |
| Pro        | $99 / workspace/mo | All exams, all modes, 100 generations/mo, tournaments, study plans  |
| Enterprise | Custom             | SSO, white-label, custom packs, dedicated region, SLA, audit export |

`EntitlementGuard` checks `Tenant__c.Plan__c` + `App_Setting__mdt` quotas on every gated action and returns Block Kit upsell when blocked.

### Billing

- Stripe via Named Credential; webhook hits a Salesforce Site / Experience public endpoint → `StripeWebhookHandler` (signature verified, idempotent via `Stripe_Event_Id__c`).
- `/certgame billing` opens a modal with current plan, seats, invoices, and a "Manage Billing" link (Stripe Customer Portal).
- Usage overage: extra generations billed monthly from `Usage_Metric__c`.

### AppExchange path

- 2GP managed package once data model is stable.
- Security Review checklist: CRUD/FLS enforced, no SOQL injection, no hardcoded secrets, all callouts via Named Credentials, `with sharing` on user-facing classes.
- License Management App (LMA) for org-level licensing as a parallel/alternative to Stripe.

### Marketplace add-ons

- Premium certification packs (per-vendor) sold à la carte.
- Sponsored tournaments (logo on cards via `Tournament__c.Sponsor_Logo_URL__c`).
- Custom-branded white-label tenants.

---

## 14. Observability & ops

- `AppLogger` writes structured rows to `App_Log__c` (level, class, method, correlation id, tenant).
- Platform Events bridge to external monitors if desired.
- Scheduled health job: stale sessions, broken citations, failed jobs, near-quota tenants → Slack `#certgame-ops` channel.
- Token cost dashboard per tenant per month.

---

## 15. Repository structure

```text
cert-trivia-slack-manager/
├── README.md
├── AGENTS.md
├── sfdx-project.json
├── config/
│   └── project-scratch-def.json
├── force-app/
│   └── main/default/
│       ├── applications/
│       ├── classes/
│       ├── customMetadata/
│       ├── lwc/
│       ├── objects/
│       ├── permissionsets/
│       ├── permissionsetgroups/
│       ├── namedCredentials/
│       ├── remoteSiteSettings/
│       ├── platformEventChannels/
│       ├── sites/
│       ├── tabs/
│       └── triggers/
├── scripts/
│   ├── import-question-bank.py
│   ├── validate-question-json.py
│   ├── seed-demo-data.py
│   └── verify-citations.py
├── sample_data/
│   ├── adm201-question-pack.sample.json
│   ├── pd1-question-pack.sample.json
│   └── ai-associate-question-pack.sample.json
└── docs/
    ├── architecture.md
    ├── slack-app-setup.md
    ├── data-model.md
    ├── game-modes.md
    ├── billing.md
    └── security-review.md
```

---

## 16. Build order (do this in order)

1. Salesforce object model + permission sets.
2. One sample ADM-201 JSON question pack.
3. Python validator + Apex `CertGameImportService` (round-trip).
4. `questionReviewConsole` LWC.
5. Slack app shell: signing-secret verification + `Slack_Event_Log__c` idempotency.
6. `/certgame` slash command → setup modal → first question card.
7. Answer button → `Player_Answer__c` → explanation → next round.
8. Leaderboard card + snapshot.
9. App Home + study plan + daily nudge.
10. Tournaments + achievements.
11. Dynamic generation (Queueable + provider interface + cost metering).
12. Billing: `Tenant__c`, `EntitlementGuard`, Stripe webhook.
13. Citation auditor + duplicate detector.
14. Managed package + Security Review.

**Core principle:** Salesforce is source of truth; Slack is the controller. Content, citations, review, scores, billing, and audit live where they can be packaged and monetized.

---

[1]: https://docs.slack.dev/block-kit/ "Block Kit | Slack Developer Docs"
[2]: https://docs.slack.dev/messaging/sending-messages-using-incoming-webhooks "Sending messages using incoming webhooks"
[3]: https://developer.salesforce.com/docs/platform/salesforce-slack-sdk/guide/overview.html "Apex SDK for Slack | Salesforce Developers"
[4]: https://developer.salesforce.com/docs/atlas.en-us.platform_events.meta/platform_events/platform_events_intro.htm "Platform Events Developer Guide"
[5]: https://docs.slack.dev/interactivity/implementing-shortcuts "Implementing shortcuts | Slack Developer Docs"
[6]: https://docs.slack.dev/surfaces/modals "Modals | Slack Developer Docs"
[7]: https://developer.salesforce.com/docs/platform/salesforce-slack-sdk/guide/apex_ref_client_access.html "Apex SDK for Slack — App Class"
