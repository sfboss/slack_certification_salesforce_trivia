# Workflows

Common recipes. Each shows the minimal steps to get the outcome.

---

## First-time setup (admin)

1. Deploy the package: see [Installation](../getting-started/installation.md).
2. Assign `Cert_Game_All_Admin` permission set group.
3. Install the Slack app: see [Slack setup](../slack/setup.md).
4. Bind secrets in Named Credentials: [Authentication](../salesforce/authentication.md).
5. Import a question pack and publish drafts (next workflow).

---

## Import a question pack

### From the LWC

1. App Launcher → **Cert Game Manager** → **Question Bank** tab.
2. **Import** → paste JSON → submit.

### From the CLI

```bash
python scripts/import_all_packs.py --org certgame
```

Or one file at a time:

```bash
python scripts/import-question-bank.py \
  --org certgame \
  --file sample_data/adm201-question-pack.sample.json
```

### Validate JSON locally first

```bash
python scripts/validate-question-json.py \
  sample_data/adm201-question-pack.sample.json
```

### Pack JSON schema

| Field                                                        | Required    | Notes                                           |
| ------------------------------------------------------------ | ----------- | ----------------------------------------------- |
| `exam.name` / `exam.code`                                    | yes         | Code is the upsert key.                         |
| `questionBank.name` / `.version` / `.sourceType` / `.status` | yes         | Start status as `Draft`.                        |
| `questionBank.externalId`                                    | recommended | For idempotent re-import.                       |
| `questions[].externalId`                                     | yes         | Per-question idempotency.                       |
| `questions[].domain`                                         | yes         | Free-text domain grouping.                      |
| `questions[].difficulty`                                     | yes         | `Beginner`/`Intermediate`/`Advanced`/`Expert`.  |
| `questions[].questionType`                                   | yes         | `Single Select`/`Multi Select`/`True/False`.    |
| `questions[].choices[]`                                      | ≥2          | Exactly one `isCorrect:true` for Single Select. |
| `questions[].citations[]`                                    | ≥1          | `title`, `url`, `sourceType`, `relevanceNote`.  |

Working example: [sample_data/adm201-question-pack.sample.json](https://github.com/sfboss/slack_certification_salesforce_trivia/blob/main/sample_data/adm201-question-pack.sample.json).

---

## Review and publish drafts

1. **Cert Game Manager → Review Drafts**.
2. Filter by exam / domain / difficulty if you want.
3. Edit choices, explanation, citations inline if needed.
4. Click **Publish** (or **Reject** with a reason).

!!! warning
`Status__c = Published` is the only state that becomes playable. Generated questions
arrive as `Draft` (or `Generated` in some pipelines) — they never auto-publish.

---

## Generate questions

Requires `Feature_Flag_Generation__c = true` and a configured `OpenAI` (or Gemini / Claude)
named credential.

### From a player (Pro tenant)

```text
/certgame plan
```

If the tenant qualifies, the plan flow can trigger a generation job in the background.

### From Apex (Developer Console)

```apex
Id tenantId = [SELECT Id FROM Tenant__c LIMIT 1].Id;
Id examId = [SELECT Id FROM Certification_Exam__c LIMIT 1].Id;
Question_Generation_Job__c job = new Question_Generation_Job__c(
    Tenant__c = tenantId,
    Certification_Exam__c = examId,
    Provider__c = 'OpenAI',
    Requested_Count__c = 5,
    Status__c = 'Queued'
);
insert job;
System.enqueueJob(new CertGameGenerationJobQueueable(job.Id));
```

Watch progress live in **Cert Game Manager → Generation Jobs** (subscribes to
`QuestionGenerationJob__e`).

Output lands as `Status__c = Draft` on `Trivia_Question__c`. Review and publish before any
of it plays.

---

## Create a tournament

1. **Cert Game Manager → Tournaments**.
2. Enter:
    - Name (required).
    - Certification exam (required).
    - Bracket type: `Round Robin` / `Single Elimination` / `Open Ladder`.
3. **Create tournament**.
4. Paste a CSV of `Player__c` Ids → **Build bracket**. Bracket JSON is stored on
   `Tournament__c.Bracket_Json__c`.
5. Players join from Slack with `/certgame play <tournamentId>` once the tournament starts.

---

## Challenge a player to a duel

In any channel where the bot is present:

```text
/certgame challenge @brendan ADM-201
```

- A challenge card posts with **Accept** / **Decline**.
- Only the mentioned opponent can act.
- On accept, both players play 5 questions in DMs at their own pace.
- The finale lands back in the original channel with side-by-side scores and a
  **Rematch** button.

Implementation: [`CertGameDuelService`](../api-reference/apex.md#certgameduelservice).

---

## Configure a study plan

From Slack:

```text
/certgame plan
```

The modal lets the player pick:

- Target exam (`Certification_Exam__c`).
- Target date.
- Nudge cadence (Daily / Weekly / Off).

On submit, `CertGameStudyPlanService.savePlanFromSlack` writes `Study_Plan__c` and queues
the player for nudges via `CertGameNudgeScheduler`.

---

## Upgrade a tenant (billing)

Requires `Feature_Flag_Billing__c = true` and the calling user is in
`Tenant__c.Admin_Slack_User_Ids__c`.

```text
/certgame billing
```

Opens a modal with an **Upgrade** button. Apex calls `Stripe` Named Credential to generate
a Customer Portal session and returns the link.

Stripe → Salesforce side: webhook events post to
`/services/apexrest/stripe/webhook` → `StripeWebhookHandler` → updates `Tenant__c.Plan__c`
and `Tenant__c.Status__c` keyed by `License_Event__c.Stripe_Event_Id__c`.

---

## Diagnose problems

```text
/certgame doctor
```

Runs [`CertGameDoctorService`](../api-reference/apex.md#certgamedoctorservice) — checks
named credentials, custom metadata, slack signing secret, queryable counts, and reports
results inline.

```text
/certgame debug
```

Renders the last hour of `App_Log__c` warnings/errors.

```text
/certgame notify-test
```

Posts a sample notification card to confirm the outbound Slack pipeline.

---

## Schedule background jobs

```apex
System.schedule(
    'CertGameCitations',
    '0 0 6 * * ?',
    new CertGameCitationVerifier()
);

System.schedule(
    'CertGameNudges',
    '0 0 14 * * ?',
    new CertGameNudgeScheduler()
);
```
