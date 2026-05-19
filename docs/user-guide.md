# Cert Game User Guide

Practical, "what do I click first" walkthrough for the **Cert Game Slack Manager** package. Covers the in-org admin console, the Slack player experience, and the moving parts behind both.

> If you are looking for installation/setup of the LMA, Slack app shell, or scratch org, see [docs/lma-setup.md](docs/lma-setup.md) and [docs/slack-app-setup.md](docs/slack-app-setup.md). This guide focuses on **operating the app** once it is deployed.

---

## 1. Mental model

The app has three surfaces:

| Surface | Who uses it | What it does |
| --- | --- | --- |
| **Cert Game Manager** Lightning app (in Salesforce) | You, the admin | Import / review questions, build tournaments, watch generation jobs. |
| **Slack workspace** (`/certgame ...`) | Players | Play games, see leaderboards, manage study plan + billing. |
| **Background jobs** (Apex schedulers, platform events) | Nobody clicks them | Nudges, citation auditor, async question generation. |

Data flows in one direction at the start:

```
Question Bank JSON ──► Draft questions ──► Reviewed/Published questions
                                                  │
                                                  ▼
                                     Slack /certgame play  ──►  Game_Round + Player_Answer
                                                  │
                                                  ▼
                                    Leaderboards · Stats · Achievements · Nudges
```

You cannot play a game until **at least one question is `Published`**. That is the most common "nothing works" cause.

---

## 2. Out-of-the-box flow (do this first)

1. **Open the app.** From the App Launcher, pick **Cert Game Manager** (or visit `/lightning/app/Cert_Game_Manager`).
2. **Question Bank tab → Import.** Paste a question pack JSON (sample pack in `sample_data/adm201-question-pack.sample.json`, or grab the CRT-403 example below). Click **Import**. This creates:
   - `Certification_Exam__c` (one)
   - `Question_Bank__c` (one)
   - `Question__c` records with `Status__c = 'Draft'`
   - `Question_Choice__c` and `Question_Citation__c` children
3. **Review Drafts tab.** Each card shows the stem, choices, citations. For each question:
   - Edit if needed (the explanation, choice text, etc.).
   - Click **Publish**. Status flips to `Published` and the question becomes playable.
   - You can also **Reject** which moves it to `Rejected` and removes it from play.
4. **Sanity check.** Open the **Certification Exam** record from the navigation bar or **Object Manager → Certification_Exam__c → records**. Confirm `Published Question Count` is > 0.
5. **Play in Slack.** In any channel where the bot is present, run `/certgame play CODE` (e.g. `/certgame play ADM-201`). The bot DMs you a round.

After step 5, **Stats**, **Leaderboards**, **Achievements**, and **Study Plans** start populating.

---

## 3. The admin tabs in detail

The **Cert Game Admin Home** LWC is a single Lightning page with four sub-tabs.

### 3.1 Review Drafts
- Shows every `Question__c` where `Status__c IN ('Draft','Generated')`.
- Filter by exam, domain, or difficulty at the top.
- Inline edit choices/explanation, then **Publish** or **Reject**.
- **Citations panel** lists each `Question_Citation__c`. The scheduled **Citation Auditor** (see §6) marks broken URLs; broken citations show with a red badge — re-edit and re-publish before they go live.

### 3.2 Question Bank
- **Import** (textarea): paste a JSON pack matching the schema in §4. The pack is validated by `QuestionJsonValidator` before any DML; you get line-level errors if it is malformed.
- **Banks table**: lists every `Question_Bank__c` with version, status, and counts.
- Clicking a bank navigates to the standard record page to delete/clone/etc.

### 3.3 Generation Jobs *(was: "waiting for event")*
- This tab is a **live event stream** over the `QuestionGenerationJob__e` platform event. It is intentionally empty until a job runs — that is not an error. You should see "No events yet…".
- To produce events, either:
  - From Slack run `/certgame plan` and let the plan trigger generation (only on Pro/Enterprise tenants with `Feature_Flag_Generation__c = true` and a configured `OpenAI_API` Named Credential), **or**
  - From Developer Console, run:
    ```apex
    Id jobId = CertGameGenerationDispatcher.enqueue(
        [SELECT Id FROM Tenant__c LIMIT 1].Id,
        [SELECT Id FROM Certification_Exam__c LIMIT 1].Id,
        5  // count
    );
    System.debug(jobId);
    ```
  - Events from that job appear in the console within a couple of seconds.
- Each row shows: timestamp, job id, tenant, status (`Queued` → `Running` → `Succeeded`/`Failed`), generated count, and the latest message.

### 3.4 Tournaments
- Fields:
  - **Name** (required)
  - **Certification exam** (required — was missing in earlier builds and caused the generic error you saw)
  - **Bracket type**: Round Robin, Single Elimination, or Open Ladder
- Click **Create tournament**. A `Tournament__c` is inserted in `Scheduled` status.
- Once created, paste a CSV of `Player__c` Ids and click **Build bracket**. The bracket JSON is stored on `Tournament__c.Bracket_Json__c` and shown below the form.
- Players join from Slack with `/certgame play <tournamentId>` once the tournament starts.
- Round-robin and single-elimination both handle 1-N players, but a single-player bracket is mostly a no-op (defensive case so the LWC does not crash on an empty roster).

---

## 4. Question pack JSON schema

The same JSON shape is used by the **Question Bank → Import** field and by the `CertGameImportService` Apex entry point.

| Field | Required | Notes |
| --- | --- | --- |
| `exam.name` / `exam.code` | yes | Code is the natural key (upsert). |
| `questionBank.name` | yes | Free text. |
| `questionBank.version` | yes | e.g. `1.0.0`. |
| `questionBank.sourceType` | yes | `Imported` / `Generated` / `Vendor`. |
| `questionBank.status` | yes | Start with `Draft`. |
| `questionBank.externalId` | recommended | Used for idempotent re-imports. |
| `questions[].externalId` | yes | Per-question idempotency key. |
| `questions[].domain` | yes | Free text grouping for analytics. |
| `questions[].difficulty` | yes | `Beginner` / `Intermediate` / `Advanced` / `Expert`. |
| `questions[].questionType` | yes | `Single Select` / `Multi Select` / `True/False`. |
| `questions[].scenario` | optional | Long-form preamble. |
| `questions[].question` | yes | Stem. |
| `questions[].choices[]` | yes (≥2) | `label`, `text`, `isCorrect`, `explanation`. Exactly one `isCorrect: true` for Single Select. |
| `questions[].explanation` | yes | Aggregate explanation surfaced after answer. |
| `questions[].citations[]` | yes (≥1) | `title`, `url`, `sourceType`, `relevanceNote`. `sourceType` must be one of: `Salesforce Help`, `Trailhead`, `Release Notes`, `Internal Guide`, `Vendor Docs`, `Other`. |

A working example is in [sample_data/adm201-question-pack.sample.json](sample_data/adm201-question-pack.sample.json).

---

## 5. Slack player experience

Once a user runs `/certgame help`, the bot prints:

| Command | Effect |
| --- | --- |
| `/certgame help` | Lists commands. |
| `/certgame play <CODE>` | Starts a quick game for the given certification code. |
| `/certgame play <tournamentId>` | Joins/plays a round in a tournament. |
| `/certgame leaderboard [CODE]` | Top players for the workspace, optionally scoped to a cert. |
| `/certgame stats` | Personal stats (accuracy, streak, plan progress). |
| `/certgame plan` | Opens the Study Plan modal. |
| `/certgame billing` | Opens the Billing modal (visible only if `Feature_Flag_Billing__c = true`). |

Game loop:
1. Bot DMs the player a question with answer buttons.
2. Player clicks a button → `SlackCertGameInteractionHandler` records a `Player_Answer__c`, scores via `CertGameScoringService`, replies with explanation + citation.
3. After `Max_Questions_Per_Game__c` (default **65**) or when the player taps **Stop**, a summary `Game_Round__c` is posted.
4. Achievements (`CertGameAchievementService`) and Study Plan progress are recalculated.

---

## 6. Background jobs

| Job | Class | What it does | How to run manually |
| --- | --- | --- | --- |
| Citation Auditor | `CertGameCitationVerifier` (Schedulable) | Pings each `Question_Citation__c.URL__c`, marks broken ones. | `System.schedule('CitAud', '0 0 6 * * ?', new CertGameCitationVerifier());` |
| Nudge Scheduler | `CertGameNudgeScheduler` | Sends Slack nudges to inactive players with active study plans. | `System.schedule('Nudge', '0 0 14 * * ?', new CertGameNudgeScheduler());` |
| Question Generation | `CertGameGenerationDispatcher` → `OpenAIQuestionProvider` (Queueable) | Calls OpenAI Named Credential, parses response, inserts Draft questions, fires `QuestionGenerationJob__e`. | See §3.3. |

All three are gated by `App_Setting__mdt` feature flags. **Generation and billing are off until you configure the Named Credentials** (`OpenAI_API`, `Stripe`).

---

## 7. Configuration cheatsheet

Edit `App_Setting.Default` (`Setup → Custom Metadata Types → App Setting → Manage → Default`):

| Field | Default | Why you might change it |
| --- | --- | --- |
| `Max_Questions_Per_Game__c` | 65 | Lower for faster smoke tests. |
| `Max_Games_Per_Day_Free__c` | 5 | Daily rate-limit for Free plan tenants. |
| `Max_Generation_Per_Day_Pro__c` | 100 | Per-tenant generation cap. |
| `Feature_Flag_Generation__c` | true | Turn off if you have not wired OpenAI yet. |
| `Feature_Flag_Tournaments__c` | true | Hide tournaments from `/certgame help` if false. |
| `Feature_Flag_Billing__c` | false | Enable only after Stripe is wired. |
| `Feature_Flag_Nudges__c` | true | Turn off in non-prod to avoid spamming yourself. |
| `Slack_Timestamp_Skew_Seconds__c` | 300 | Lower in production for tighter replay-window. |

Tenants are auto-created on first contact from a Slack workspace. To pre-create one (e.g. for a tournament demo before anyone has used Slack):

```apex
insert new Tenant__c(
    Name = 'Demo Tenant',
    Slack_Team_Id__c = 'T0000DEMO',
    Plan__c = 'Pro',
    Status__c = 'Active'
);
```

---

## 8. Permissions

| Permission Set | Grant to | Includes |
| --- | --- | --- |
| `Cert_Game_Admin` | Internal admins | Full CRUD on all 27 objects, tabSettings for `Cert_Game_Admin_Home`, applicationVisibility for `Cert_Game_Manager`. |
| `Cert_Game_Player` | Internal users who play in Slack only | Read on banks/exams, read+create on `Player_Answer__c` and `Game_Round__c`. |
| `Cert_Game_All_Admin` *(perm set group)* | Anyone who needs both | Combines admin + player. |

Assign in scratch via:
```bash
sf org assign permset --name Cert_Game_All_Admin -o certgame
```

---

## 9. Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| Tournament Save → "Something went wrong" toast | `Certification_Exam__c` field is required and was not selected. | Pick an exam in the new combobox (fixed in this build). |
| Generation Jobs tab stays empty | Expected — it is a live stream. | Trigger a job (see §3.3) or generate from Slack `/certgame plan`. |
| `/certgame play X` → "No published questions yet" | All questions are still `Draft`. | Publish from the **Review Drafts** tab. |
| `/certgame play X` → "Locked behind Pro" | Tenant `Plan__c` is `Free` and you exceeded `Max_Games_Per_Day_Free__c`. | Upgrade plan or raise the limit in `App_Setting.Default`. |
| Slack request → "Bad signature" | `Slack_Signing` Named Credential header is missing or your signing secret rotated. | Update the Named Credential password. |
| Stripe webhook 401 | `Stripe` Named Credential signing secret mismatch. | Re-paste the webhook signing secret. |
| Citations panel red | `CertGameCitationVerifier` flagged the URL as 4xx/5xx. | Fix or replace the citation, re-publish. |

Use `App_Log__c` (object) for structured logs — every Slack request, Stripe webhook, and Apex error funnels through `AuditLogger`.

---

## 10. End-to-end smoke test (5 minutes)

```bash
# 1. Deploy
sf project deploy start -o certgame --source-dir force-app --ignore-conflicts

# 2. Permset
sf org assign permset --name Cert_Game_All_Admin -o certgame

# 3. Open app
sf org open -o certgame -p /lightning/app/Cert_Game_Manager
```

In the org:
1. **Question Bank → Import** → paste `sample_data/adm201-question-pack.sample.json` → **Import**.
2. **Review Drafts** → publish the 3 questions.
3. **Tournaments** → name "Smoke Test", exam "Salesforce Administrator", **Create tournament**.
4. From Developer Console, fire a fake event to validate the Generation console (optional):
   ```apex
   EventBus.publish(new QuestionGenerationJob__e(
       Job_Id__c = 'smoke', Tenant_Id__c = 'tnt', Status__c = 'Succeeded',
       Generated_Count__c = 5, Message__c = 'manual test'
   ));
   ```
5. Slack: `/certgame play ADM-201` → answer one round → `/certgame stats`.

If all five succeed the app is fully operational.
