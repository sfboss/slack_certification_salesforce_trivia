---
title: Recommended Prompt Templates
icon: material/file-tree-outline
---

# :material-file-tree-outline: Recommended Prompt Templates

The production prompt (see [Prompts](prompts.md)) asks for the minimum schema. These templates ask for **every metadata field the data model supports** so downstream analytics light up. Copy-paste, swap the placeholders, and you'll get question packs that produce real coaching signal.

!!! abstract "Three templates, one philosophy"
    Each template targets a different use case but shares the same metadata floor: keywords, tags, named entities, glossary terms, per-choice `whyIncorrect`, `directStatement`, and `misconceptionTag`. These are the fields that make `Player_Topic_Stat__c` useful.

---

## Template 1 — Full-metadata pack (the gold standard)

Use when you're generating a new pack for an exam you care about. Produces complete data-model coverage.

??? example "Click to expand the full prompt"

    ```text
    You generate Cert Game question packs as a single JSON document.
    Output ONLY the JSON — no Markdown fence, no commentary.

    CONTRACT
    Top-level shape:
    {
      "exam":         { "code", "name", "vendor" },
      "questionBank": { "externalId", "name", "version", "sourceType", "status" },
      "questions":    [ ... ]
    }

    Every question MUST carry:
      - externalId       : kebab-case <examCodeLower>-<topicSlug>-<NN>
      - domain           : EXACTLY one of the listed domain names (case-sensitive)
      - question         : 1-2 sentence stem
      - scenario         : 1-3 sentence setup paragraph (optional but encouraged
                           for Intermediate/Advanced)
      - questionType     : "Single Select" | "Multi Select" | "True False"
      - difficulty       : "Beginner" | "Intermediate" | "Advanced" | "Expert"
      - explanation      : 2-4 sentence rationale a candidate would learn from
      - keywords         : array of 3-7 short concept strings
                           (e.g. ["sharing rules","profile permissions","object CRUD"])
      - tags             : array of 1-3 broader badges
                           (e.g. ["security","sharing"])
      - namedEntities    : array of Salesforce features/objects/permissions
                           referenced (e.g. ["Opportunity","Public Group","Sharing Rule"])
      - glossaryTerms    : array of { "term", "definition" } for vocabulary the
                           reader might not know. 1-3 entries.
      - primaryReferenceUrl : single canonical docs URL
      - choices          : 3-5 entries (4 typical)
      - citations        : at least 1, prefer 2+. First citation MUST match
                           primaryReferenceUrl.

    Each choice MUST carry:
      - label             : "A" | "B" | "C" | "D" | "E"
      - text              : the choice body
      - isCorrect         : true | false
      - explanation       : ALWAYS present.
                            For correct choices: WHY this is the right answer,
                            citing the underlying rule.
      - whyIncorrect      : REQUIRED on wrong choices. Specific misread or
                            misapplication the player likely made.
      - directStatement   : 1-sentence factual assertion derived from the
                            choice. True for correct; false-but-instructive for
                            wrong. Used in spaced-repetition flashcards.
      - misconceptionTag  : REQUIRED on wrong choices. Short kebab-case tag
                            naming the misconception pattern
                            (e.g. "sharing-rule-downgrade","owd-blocks-owner").
                            Optional on correct choices.

    Each citation MUST carry:
      - title             : doc title
      - url               : full URL
      - sourceType        : "Salesforce Help" | "Trailhead" | "Release Notes" |
                            "Architect Guide" | "Blog" | "Other"
      - quoteOrReference  : verbatim quote or section reference proving the
                            answer

    QUALITY BAR
    - Test reasoning, not recall. Prefer scenario-based prompts.
    - Every wrong answer captures a REAL misconception (note it in
      misconceptionTag). "obviously-wrong" distractors are forbidden.
    - Explanations cite the spec/docs, not vibes.
    - Stay within the official exam blueprint domains supplied below.
    - keywords/tags/namedEntities populated on EVERY question — these drive the
      player's weakness analytics. Empty arrays defeat the system.

    INPUTS
      examCode:       {{examCode}}
      examName:       {{examName}}
      validDomains:   {{domains|json}}
      questionCount:  {{count}}
      difficultyMix:  {{mix}}   // e.g. "30% Beginner / 50% Intermediate / 20% Advanced"
      topicsToBoost:  {{boost}} // optional
      topicsToAvoid:  {{avoid}} // optional
      tone:           {{tone}}  // "exam-realistic" | "casual" | "scenario-heavy"

    OUTPUT
    A single JSON object. Validate against the contract before responding.
    Do not include any field not listed above. Forbidden legacy fields:
    status, citationMode, referenceSummary, qualityScore, timesAsked,
    timesCorrect, antiCheatSeed, hintUsed.
    ```

### When to use this template

- Any new exam pack going into production
- Replacing legacy thin-metadata packs (run the generator, review, publish)
- Generating a "training pack" to seed `Player_Topic_Stat__c` for a new player cohort

---

## Template 2 — Misconception drill

Use when you want a short pack laser-focused on **wrong-answer patterns** for an exam. Shorter, higher difficulty, every wrong choice required to carry a misconception tag.

??? example "Click to expand"

    ```text
    Generate a misconception-drill pack for {{examCode}}.

    Goals
    - 10 questions, all "Intermediate" or "Advanced".
    - Each question targets a SPECIFIC named misconception (provided below).
    - Every wrong choice MUST carry the misconception tag it embodies.
    - The correct choice's explanation must explicitly contrast against the
      misconception ("Unlike X, the correct behaviour is Y because…").

    Misconceptions to drill (one per question):
      {{misconceptions|bulletList}}

    Output: single JSON document matching the Cert Game pack contract,
    including keywords, tags, namedEntities, glossaryTerms, per-choice
    whyIncorrect / directStatement / misconceptionTag, and ≥1 citation
    per question (Salesforce Help or Trailhead preferred).

    Forbidden: any field outside the contract; any "all of the above" choice;
    any distractor that doesn't map to a real misconception.
    ```

### Why this template earns its keep

A 10-question drill written this way produces, per player, **up to 30 `Player_Topic_Stat__c (Misconception)` rows** within a single session — enough signal to drive the "Recurring misconceptions" panel in the readiness report immediately.

---

## Template 3 — Scenario-heavy reasoning pack

Use for senior-level exams (Architect, PD-II) where the test bias is heavy on multi-step scenarios.

??? example "Click to expand"

    ```text
    Generate {{count}} scenario-heavy questions for {{examCode}}.

    Constraints
    - Every question has a "scenario" field (3-6 sentences) describing a
      realistic business / technical situation.
    - The "question" field is a short one-sentence prompt that depends on
      the scenario.
    - Two wrong choices must be "plausible-but-wrong because of a subtle
      detail in the scenario" — note the subtlety in whyIncorrect.
    - Use real Salesforce object/feature names; populate namedEntities
      with every feature mentioned in the scenario or choices.
    - Glossary: include any term a junior practitioner would not know
      (e.g. "External Object", "Async SOQL", "Apex Crypto").

    Difficulty: {{difficulty}}.  Domains: {{domains|json}}.

    Output: single JSON document matching the Cert Game pack contract.
    Every metadata field populated. ≥2 citations per question, first one
    matching primaryReferenceUrl.
    ```

---

## How to feed these into the runtime

Today the Apex provider hardcodes the production prompt. To use these templates without changing code:

1. Generate the JSON pack **outside Salesforce** using any LLM client and one of these templates.
2. Save to `sample_data/<your-pack>.json`.
3. Validate locally:
   ```bash
   python scripts/validate-question-json.py sample_data/<your-pack>.json
   ```
4. Import via the `questionPackImporter` LWC or:
   ```bash
   sf apex run -o certgame -f scripts/apex/import-question-pack.apex
   ```

### Once the prompt-pluggability work lands

`Question_Generation_Job__c.Prompt_Text__c` is reserved for caller adjustments. When the provider starts forwarding it (see [Prompts → Future](prompts.md#future-prompt-text)), you'll be able to paste **just the `Goals` / `Constraints` block** of one of these templates into the LWC and have the provider stitch it onto the contract.

## What "good" metadata yield looks like

A pack of 25 questions generated with **Template 1** should populate, per question:

| Field | Target |
|-------|--------|
| `keywords` | 3–7 entries |
| `tags` | 1–3 entries |
| `namedEntities` | 2–6 entries |
| `glossaryTerms` | 1–3 entries |
| `citations` | 2+ |
| Wrong choices with `misconceptionTag` | 100% |
| Wrong choices with `whyIncorrect` | 100% |
| All choices with `directStatement` | 100% |

A 25-question pack hitting those targets produces roughly **400–600 `Player_Topic_Stat__c` upserts** per player who plays it. That's the signal density the weakness reports were built for.
