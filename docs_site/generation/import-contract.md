---
title: Import Contract (JSON)
icon: material/code-json
---

# :material-code-json: Import Contract (JSON)

The exact JSON shape `CertGameImportService.importPack(json)` consumes. This is the contract between *anything that produces questions* (LLM, hand-authored pack, CSV converter) and the Salesforce data model.

If you're writing a generator prompt, this is the schema you're aiming at — see [Recommended Prompt Templates](prompt-templates.md) for prose that pushes the LLM to fill it completely.

## Top-level shape

```json
{
  "exam":         { /* required, drives Certification_Exam__c upsert */ },
  "questionBank": { /* required, drives Question_Bank__c upsert */ },
  "questions":    [ /* 1..N question objects */ ]
}
```

## `exam` object

| Key | Type | Required | Maps to | Notes |
|-----|------|----------|---------|-------|
| `code` | string | :material-check: | `Certification_Exam__c.Certification_Code__c` | Upsert key. Created if missing. |
| `name` | string | :material-check: | `Certification_Exam__c.Name` | |
| `vendor` | string | optional | `Certification_Exam__c.Vendor__c` | Defaults to `"Salesforce"`. |

## `questionBank` object

| Key | Type | Required | Maps to | Notes |
|-----|------|----------|---------|-------|
| `externalId` | string | :material-check: | `Question_Bank__c.External_Id__c` | Upsert key. |
| `name` | string | :material-check: | `Question_Bank__c.Name` | |
| `version` | string | :material-check: | `Question_Bank__c.Version__c` | Semver-ish. |
| `sourceType` | string | :material-check: | `Question_Bank__c.Source_Type__c` | `Manual` / `Generated` / `Imported` / `Curated`. |
| `status` | string | :material-check: | `Question_Bank__c.Status__c` | Usually `Draft`. |
| `premium` | boolean | optional | `Question_Bank__c.Premium__c` | |
| `promptVersion` | string | optional | `Question_Bank__c.Prompt_Version__c` | A/B label for the generator prompt. |
| `generatedByModel` | string | optional | `Question_Bank__c.Generated_By_Model__c` | Model id. |

## `questions[]` object

Every question maps to one `Trivia_Question__c` row (always inserted as `Status__c = 'Draft'`).

| Key | Type | Required | Maps to | Rules |
|-----|------|----------|---------|-------|
| `externalId` | string | :material-check: | `External_Id__c` | Unique within the pack. Format `<examCodeLower>-<topicSlug>-<NN>`. |
| `domain` | string | recommended | `Exam_Domain__c.Name` (resolved) | Case-sensitive match against existing `Exam_Domain__c` rows. Missing → null lookup + warning. |
| `question` | string | :material-check: | `Question_Text__c` | The prompt body. |
| `scenario` | string | optional | `Scenario_Text__c` | Recommended on Intermediate+. |
| `questionType` | string | :material-check: | `Question_Type__c` | `"Single Select"` / `"Multi Select"` / `"True False"`. |
| `difficulty` | string | :material-check: | `Difficulty__c` | `"Beginner"` / `"Intermediate"` / `"Advanced"` / `"Expert"`. |
| `explanation` | string | :material-check: | `Explanation__c` | Overall rationale. |
| `keywords` | string[] | recommended | `Keywords__c` (comma-joined) | 3–7 entries ideal. **Powers `Player_Topic_Stat__c (Keyword)`.** |
| `tags` | string[] | recommended | `Tags__c` (comma-joined, ≤255 chars) | 1–3 entries. |
| `namedEntities` | string[] | recommended | `Named_Entities__c` (JSON-serialized) | Feature/object names. |
| `glossaryTerms` | array of `{term,definition}` | recommended | `Glossary_Terms__c` (JSON-serialized) | Inline vocabulary support. |
| `primaryReferenceUrl` | string (URL) | recommended | `Primary_Reference_URL__c` | Single canonical link. |
| `choices[]` | array | :material-check: | `Trivia_Answer_Choice__c` rows | See [`choices`](#choices) below. |
| `citations[]` | array | :material-check: (≥1) | `Question_Citation__c` rows | See [`citations`](#citations) below. |

### `choices`

3–5 per question. Single Select requires exactly 1 `isCorrect: true`; Multi Select requires ≥2.

| Key | Type | Required | Maps to | Notes |
|-----|------|----------|---------|-------|
| `label` | string | :material-check: | `Choice_Label__c` | `"A"` … `"E"`. |
| `text` | string | :material-check: | `Choice_Text__c` | |
| `isCorrect` | boolean | :material-check: | `Is_Correct__c` | |
| `explanation` | string | :material-check: | `Explanation__c` | "Why correct"/"why incorrect". |
| `whyIncorrect` | string | required on wrong | `Why_Incorrect__c` | Specific misread. |
| `directStatement` | string | recommended | `Direct_Statement__c` | Flashcard-style. |
| `misconceptionTag` | string | required on wrong | `Misconception_Tag__c` | Short kebab-case slug. **Powers `Player_Topic_Stat__c (Misconception)`.** |

### `citations`

1+ per question. First should match `primaryReferenceUrl`.

| Key | Type | Required | Maps to | Notes |
|-----|------|----------|---------|-------|
| `title` | string | :material-check: | `Title__c` | Display title. |
| `url` | string (URL) | :material-check: | `URL__c` | |
| `sourceType` | string | recommended | `Source_Type__c` | `"Salesforce Help"` / `"Trailhead"` / `"Release Notes"` / etc. |
| `quoteOrReference` | string | recommended | `Quote_Or_Reference__c` | Verbatim quote proving the answer. |
| `relevanceNote` | string | optional | `Relevance_Note__c` | Reviewer-only context. |

## Reference pack — minimal

```json
{
  "exam": { "code": "ADM-201", "name": "Salesforce Administrator", "vendor": "Salesforce" },
  "questionBank": {
    "externalId": "BANK-ADM201-202605240730",
    "name": "ADM-201 Generated 2026-05-24",
    "version": "1.0.0",
    "sourceType": "Generated",
    "status": "Draft"
  },
  "questions": [
    {
      "externalId": "adm201-sharing-rules-01",
      "domain": "Security & Access",
      "question": "A user reports they cannot edit Opportunity records they own. Their profile grants Read on Opportunity. What is the most likely cause?",
      "questionType": "Single Select",
      "difficulty": "Intermediate",
      "explanation": "Profile object permissions are the floor; sharing rules can widen access but cannot grant Edit if the profile lacks it.",
      "primaryReferenceUrl": "https://help.salesforce.com/s/articleView?id=sf.security_sharing_rules.htm",
      "choices": [
        { "label": "A", "text": "The profile is missing Edit on Opportunity.", "isCorrect": true, "explanation": "Profile CRUD is the floor for sharing rules." },
        { "label": "B", "text": "The sharing rule is set to Read Only.", "isCorrect": false, "explanation": "Sharing rules widen access; they don't downgrade it." },
        { "label": "C", "text": "The org-wide default for Opportunity is Private.", "isCorrect": false, "explanation": "OWD does not restrict access to records the user owns." },
        { "label": "D", "text": "The user's role is below the record owner's role.", "isCorrect": false, "explanation": "Role hierarchy doesn't affect owned records." }
      ],
      "citations": [
        { "title": "Sharing rules — Help & Training", "url": "https://help.salesforce.com/s/articleView?id=sf.security_sharing_rules.htm", "sourceType": "Salesforce Help" }
      ]
    }
  ]
}
```

## Reference pack — full metadata

This is the **gold standard**. Every question in production-grade packs should look like this.

```json
{
  "exam": { "code": "ADM-201", "name": "Salesforce Administrator", "vendor": "Salesforce" },
  "questionBank": {
    "externalId": "BANK-ADM201-FULL-METADATA-EXAMPLE",
    "name": "Full-Metadata Example",
    "version": "1.0.0",
    "sourceType": "Generated",
    "status": "Draft",
    "promptVersion": "v5-full-metadata",
    "generatedByModel": "claude-opus-4-7"
  },
  "questions": [
    {
      "externalId": "adm201-sharing-rules-02",
      "domain": "Security & Access",
      "questionType": "Single Select",
      "difficulty": "Intermediate",
      "scenario": "A user is in a public group used by a Read Only sharing rule on Opportunity. Their profile grants Read on Opportunity.",
      "question": "Why can the user not edit Opportunity records they own?",
      "explanation": "Sharing rules can only widen access. The profile's missing Edit permission is the constraint that cannot be relaxed by sharing.",
      "keywords": ["sharing rules", "profile permissions", "object CRUD", "OWD", "ownership"],
      "tags": ["security", "sharing"],
      "namedEntities": ["Opportunity", "Public Group", "Sharing Rule", "Profile", "OWD"],
      "glossaryTerms": [
        { "term": "Sharing Rule", "definition": "Automatic record-level access extension to a group of users." },
        { "term": "OWD", "definition": "Org-Wide Default — the baseline record-access setting for an object." }
      ],
      "primaryReferenceUrl": "https://help.salesforce.com/s/articleView?id=sf.security_sharing_rules.htm",
      "choices": [
        {
          "label": "A", "text": "The profile is missing Edit on Opportunity.",
          "isCorrect": true,
          "explanation": "Profile CRUD is the floor; sharing rules cannot grant Edit if the profile lacks it.",
          "directStatement": "Profile object permissions must include Edit before sharing rules can grant edit access."
        },
        {
          "label": "B", "text": "The sharing rule is set to Read Only.",
          "isCorrect": false,
          "whyIncorrect": "The Read Only sharing rule correctly grants Read; the missing Edit comes from the profile, not the rule.",
          "directStatement": "Sharing rules widen access; they never downgrade it.",
          "misconceptionTag": "sharing-rule-downgrade"
        },
        {
          "label": "C", "text": "The org-wide default for Opportunity is Private.",
          "isCorrect": false,
          "whyIncorrect": "OWD Private grants record owners full access; OWD never restricts the owner.",
          "directStatement": "OWD does not restrict access to records the user owns.",
          "misconceptionTag": "owd-blocks-owner"
        },
        {
          "label": "D", "text": "The user's role is below the record owner's role.",
          "isCorrect": false,
          "whyIncorrect": "The user IS the record owner per the scenario — role hierarchy applies only to records the user does not own.",
          "directStatement": "Role hierarchy affects records the user does not own.",
          "misconceptionTag": "role-vs-ownership"
        }
      ],
      "citations": [
        {
          "title": "Sharing rules — Help & Training",
          "url": "https://help.salesforce.com/s/articleView?id=sf.security_sharing_rules.htm",
          "sourceType": "Salesforce Help",
          "quoteOrReference": "Sharing rules give particular users greater access by making automatic exceptions to your org-wide sharing settings."
        },
        {
          "title": "Profile object permissions — Trailhead",
          "url": "https://trailhead.salesforce.com/content/learn/modules/data_security/data_security_objects",
          "sourceType": "Trailhead",
          "quoteOrReference": "Object permissions on a profile are the baseline for what a user can do with a given object."
        }
      ]
    }
  ]
}
```

## Validation failures you'll actually see

| Error JSON path | Meaning | Fix |
|----------------|---------|-----|
| `questions[i].choices` count | Single Select with <3 choices or wrong correct count | Provide exactly 1 correct; 3+ total. |
| `questions[i].choices[j].whyIncorrect` missing | Wrong choice without `whyIncorrect` | Add the field. |
| `questions[i].domain` not found | The `domain` string doesn't match any `Exam_Domain__c.Name` for the exam | Either fix the JSON or pre-create the domain row. |
| `questions[i].citations` empty | No citations | Provide ≥1, ideally with `quoteOrReference`. |
| `questions[i].difficulty` invalid | Value not in the picklist | Use exact case: `Beginner` / `Intermediate` / `Advanced` / `Expert`. |
| Duplicate `Hash__c` | Stem + sorted-correct-text already exists | Either rephrase or accept that this is a duplicate; existing record wins. |

## Sample packs in the repo

All under `sample_data/`. Useful as fixtures and as worked examples for prompt design.

| File | Exam | What it demonstrates |
|------|------|---------------------|
| `adm201-question-pack.sample.json` | ADM-201 | Baseline minimal pack |
| `adm201-question-pack.enhanced.sample.json` | ADM-201 | Full-metadata example (keywords/tags/entities/glossary/misconceptionTag) |
| `security-fundamentals.sample.json` | CRT-SEC | Beginner security focus |
| `crt101-platform-basics.sample.json` | CRT-101 | Platform fundamentals |
| `lwc-basics.sample.json` | CRT-LWC | LWC lifecycle/syntax |
| `pd1-developer-quickfire.sample.json` | PD-1 | Rapid developer topics |
| `flow-essentials.sample.json` | CRT-FLOW | Flow Builder & automation |
| `integration-essentials.sample.json` | CRT-INT | APIs, middleware, integration patterns |
| `reports-dashboards-basics.sample.json` | CRT-RPT | Reports/dashboards |
