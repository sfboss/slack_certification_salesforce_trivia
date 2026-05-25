---
title: Generation Pipeline
icon: material/pipe
---

# :material-pipe: Generation Pipeline

End-to-end flow from "user clicks Generate" to "drafts visible in the review console."

## Sequence

```mermaid
sequenceDiagram
    autonumber
    participant UI as generationJobConsole LWC
    participant Ctl as CertGameGenerationJobController
    participant Job as Question_Generation_Job__c
    participant Q as CertGameGenerationJobQueueable
    participant Guard as EntitlementGuard
    participant F as ProviderFactory
    participant P as OpenAIQuestionProvider
    participant V as QuestionJsonValidator
    participant I as CertGameImportService
    participant D as QuestionDuplicateDetector
    participant U as Usage_Metric__c
    participant E as QuestionGenerationJob__e

    UI->>Ctl: startJob({exam, count, domains, difficulty})
    Ctl->>Job: insert (status=Queued)
    Ctl->>Q: enqueueJob(jobId)
    Q->>Job: SELECT … (load)
    Q->>Job: update status=Running
    Q->>E: publish status=Running
    Q->>Guard: checkGenerationQuota(tenant, count)
    Guard-->>Q: ok / throw QuotaExceeded
    Q->>F: provider()
    F-->>Q: OpenAIQuestionProvider
    Q->>P: generate(examCode, domains, difficulty, count)
    P->>P: build prompt + JSON schema
    P->>P: HTTP POST callout:OpenAI/v1/responses
    P-->>Q: raw JSON string
    Q->>V: validate(json)
    V-->>Q: ok / ValidationException
    Q->>I: importPack(json)
    I->>D: hash(qText, sortedCorrect) per Q
    D-->>I: hash + duplicate flag
    I-->>Q: import result (insertedCount, dupCount)
    Q->>U: upsert Usage_Metric__c (+= count)
    Q->>Job: update status=Completed, counts, output
    Q->>E: publish status=Completed
    UI-->>UI: subscribed; updates progress card
```

## Stage detail

### 1. Job creation

`CertGameGenerationJobController.startJob` (called from the LWC) inserts `Question_Generation_Job__c` with `Status__c = 'Queued'`. Inputs:

- `Certification_Exam__c` (required)
- `Requested_Question_Count__c` (1–25; capped)
- `Domain_Focus__c` (optional CSV)
- `Difficulty_Focus__c` (`Mixed` if blank)
- `Provider__c` / `Model__c` (override settings defaults)
- `Prompt_Text__c` (captured but **not currently passed to the provider** — see [Prompts → Future](prompts.md#future-prompt-text))

### 2. Entitlement gate

`EntitlementGuard.checkGenerationQuota(tenantId, requestedCount)` reads the current month's `Usage_Metric__c` and compares to `Max_Generation_Per_Day_<Plan>__c` from `App_Setting__mdt`. Failures throw before any LLM cost is incurred.

### 3. Provider callout

`QuestionGenerationProviderFactory.provider()` returns the implementation selected by `Default_Provider__c`. Only OpenAI is production. See [Prompts](prompts.md) for the verbatim payload.

### 4. Validation

`QuestionJsonValidator.validate(json)` enforces:

- Top-level shape (`exam`, `questionBank`, `questions`)
- Required question fields
- `difficulty` ∈ {`Beginner`, `Intermediate`, `Advanced`, `Expert`}
- `questionType` ∈ {`Single Select`, `Multi Select`, `True False`}
- Choice counts (Single Select ≥3 with exactly 1 `isCorrect`; Multi Select ≥4 with ≥2 `isCorrect`; True False exactly 2 with 1 `isCorrect`)
- ≥1 citation per question

A `ValidationException` halts the pipeline, sets the job to `Failed`, and writes the offending JSON-path to `Error_Message__c`.

### 5. Import

`CertGameImportService.importPack(json)`:

1. Upserts `Certification_Exam__c` on `Certification_Code__c`
2. Upserts `Question_Bank__c` on `External_Id__c`
3. Creates any missing `Exam_Domain__c` rows from the `domain` strings
4. Upserts `Trivia_Question__c` on `External_Id__c` (always `Status__c = 'Draft'`)
5. Deletes-and-reinserts child `Trivia_Answer_Choice__c` and `Question_Citation__c` rows for each question

!!! danger "Status hard rule"
    Code **never** sets `Status__c = 'Published'`. The importer always emits `Draft`. Publishing happens only in `QuestionReviewController` driven by a human reviewer in `questionReviewConsole`.

### 6. Duplicate detection

For every question, `QuestionDuplicateDetector.hash(questionText, sortedCorrectChoiceTexts)` produces a SHA-256 hex string written to `Hash__c`. The detector:

- Lowercases and collapses whitespace
- Sorts correct-choice texts alphabetically
- Concatenates `normalizedQ | choice1 | choice2 | …`
- SHA-256

If an existing `Trivia_Question__c` already has that hash, the new draft is **rejected** and counted in the job's "duplicates" tally — keeping the existing record.

### 7. Metering & event

The Queueable increments `Usage_Metric__c.Questions_Served__c` and `LLM_Tokens_*` for the current period, updates the job to `Completed`, and publishes a final `QuestionGenerationJob__e` event.

## Failure handling

Every stage catches and writes a meaningful `Error_Message__c` before re-throwing. The Queueable wraps `execute` in a top-level try/catch that:

1. Sets `Status__c = 'Failed'`
2. Writes the message
3. Publishes a `QuestionGenerationJob__e` with `Status__c = 'Failed'` so the LWC's red card appears immediately

Retries are manual today — the LWC offers a "Retry" button that clones the job record.
