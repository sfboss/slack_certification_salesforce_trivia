---
title: Production Prompts
icon: material/message-text-outline
---

# :material-message-text-outline: Production Prompts

The actual strings sent to the LLM today. These are extracted verbatim from `OpenAIQuestionProvider.cls` so you can see exactly what behaviour you're getting.

!!! tip "Want richer metadata?"
    The production prompt below is the *minimum* schema. The [Recommended Prompt Templates](prompt-templates.md) page shows what to send when you want every analytics field populated.

## OpenAI provider (active)

**File.** `force-app/main/default/classes/OpenAIQuestionProvider.cls`

**Endpoint.** `callout:OpenAI/v1/responses` (Named Credential `OpenAI`)

**Model.** `App_Setting__mdt.Default_Model__c` — default `gpt-4.1-mini`.

**Temperature.** `0.4` · **Max output tokens.** `4000` · **Timeout.** `120000ms`.

### System / user prompt (verbatim)

```text
You are generating Salesforce certification trivia questions. Respond ONLY
with raw JSON (no Markdown fence, no commentary) matching this schema:

{ "exam": { "code": "<exam code>", "name": "<exam name>", "vendor": "Salesforce" },
  "questionBank": { "externalId": "BANK-<exam>-<yyyymmddhhmm>", "name": "<short pack name>",
    "version": "1.0.0", "sourceType": "Generated", "status": "Draft" },
  "questions": [ {
    "externalId": "<exam>-Q<n>",
    "domain": "<one of the listed domains>",
    "difficulty": "<Beginner|Intermediate|Advanced>",
    "questionType": "Single Select",
    "question": "<one-sentence stem>",
    "scenarioText": "<optional 1-3 sentence scenario, may be empty>",
    "choices": [
      { "label": "A", "text": "...", "isCorrect": false, "explanation": "<why this is wrong>" },
      { "label": "B", "text": "...", "isCorrect": true,  "explanation": "<why this is right>" },
      { "label": "C", "text": "...", "isCorrect": false, "explanation": "<why this is wrong>" },
      { "label": "D", "text": "...", "isCorrect": false, "explanation": "<why this is wrong>" }
    ],
    "explanation": "<2-4 sentence overall explanation a candidate would learn from>",
    "primaryReferenceUrl": "<single canonical Salesforce docs URL>",
    "referenceSummary": "<one-sentence summary of what the reference covers>",
    "keywords": "<comma-separated keywords>",
    "citations": [
      { "title": "<doc title>", "url": "<full URL>", "sourceType": "Salesforce Help",
        "relevanceNote": "<why this source backs the answer>" }
    ]
  } ] }

Rules:
- Exactly one correct choice per Single Select question.
- Provide 4 choices per question (A-D).
- Every choice must have a non-empty explanation.
- Every question must include at least one citation to official Salesforce documentation.
- Use the actual exam code and a plausible exam name; the importer will upsert by code.
- Question externalIds must be unique within the pack.

Exam code: {{examCode}}.
{{? if domains supplied}}Bias toward these domains (spread questions across them): {{domains|join(", ")}}.{{?}}
{{? if difficulty supplied}}Difficulty: {{difficulty}} for every question.
{{? else }}Difficulty: mix of Beginner / Intermediate / Advanced.
{{?}}
Number of questions: {{count}}.
```

### Variable injection

| Token | Source | Format |
|-------|--------|--------|
| `{{examCode}}` | `Question_Generation_Job__c.Certification_Exam__r.Certification_Code__c` | Plain string |
| `{{domains}}` | `Domain_Focus__c` parsed CSV | Joined with `", "`, conditional clause skipped if empty |
| `{{difficulty}}` | `Difficulty_Focus__c` | `null` for `Mixed` → falls to the mix sentence |
| `{{count}}` | `Requested_Question_Count__c` | Integer, capped 1–25 |

### What this prompt **does not** request

The production prompt asks for a thin metadata set. These fields are **part of the import contract** but absent from what the LLM is told to emit:

- :material-alert-octagon-outline: `tags` (broader taxonomy)
- :material-alert-octagon-outline: `namedEntities` (knowledge-graph nodes)
- :material-alert-octagon-outline: `glossaryTerms` (inline definitions)
- :material-alert-octagon-outline: `scenario` on most questions (only loosely encouraged)
- :material-alert-octagon-outline: Per-choice `whyIncorrect` (the schema asks `explanation` but doesn't enforce wrong-vs-right distinction)
- :material-alert-octagon-outline: Per-choice `directStatement` (flashcard-style)
- :material-alert-octagon-outline: Per-choice `misconceptionTag` (the **single most useful** field for weakness analytics)

!!! warning "Direct consequence"
    Questions generated through the production prompt populate `Player_Topic_Stat__c` only by `Keyword`, `Domain`, and `Difficulty`. They produce **zero `Misconception` rows** and **zero `Tag` or `Entity` rows.** The recurring-misconception coaching line on the readiness report stays blank.

    Use the [Recommended Prompt Templates](prompt-templates.md) when generating any new pack you care about.

---

## Gemini & Claude providers (stubs)

**Files.** `GeminiQuestionProvider.cls`, `ClaudeQuestionProvider.cls`

Both implement the `QuestionGenerationProvider` interface but throw `CalloutException('… not yet implemented.')`. To enable: implement `generate()` mirroring the OpenAI shape, wire the matching Named Credential (`Gemini` / `Claude`), and flip `App_Setting__mdt.Default_Provider__c`.

When implementing, **use the recommended template prompt** instead of the legacy minimum schema.

---

## Future: prompt text

`Question_Generation_Job__c.Prompt_Text__c` (LongText 32k) is captured from the LWC but **not currently forwarded** to the provider. The intended use is a "notes to the generator" field — e.g. `"Emphasize Flow Builder over Process Builder"`, `"Avoid Lightning Sync questions"`.

Implementation when ready: append the field to the OpenAI prompt under a `Caller adjustments:` heading. The validator and importer already round-trip the value; only the provider call needs the change.
