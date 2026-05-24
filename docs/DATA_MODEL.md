# Cert Game Data Model — post-cleanup baseline

**Last updated:** 2026-05-24 (after the field-pruning pass).
**Purpose:** the canonical spec for the cleaned-up data model. Use the JSON contract and the **Generator prompt** section at the bottom when asking an LLM to produce new question packs.

API version: **60.0**. All custom objects are `with sharing` everywhere except the three documented `without sharing` entrypoints (`SlackEventsRestResource`, `WebApiRestResource`, `StripeWebhookHandler`).

---

## Object map (at a glance)

| Object | Role |
|---|---|
| `Tenant__c` | One per Slack workspace. Holds plan, Stripe IDs, status. Keyed by `Slack_Team_Id__c`. |
| `Player__c` | One per human. Holds Slack identity, Google OAuth identity, web session anchor, activity rollups. |
| `Certification_Exam__c` / `Exam_Domain__c` | Exam catalog + skill-domain breakdown. |
| `Question_Bank__c` | Versioned grouping of questions per exam. |
| `Trivia_Question__c` + `Trivia_Answer_Choice__c` + `Question_Citation__c` | The question content tree. **Primary generator output.** |
| `Game_Session__c` + `Game_Round__c` + `Player_Answer__c` | A run-through of N questions by a Player (Solo/Duel/Tournament). |
| `Tournament__c` + `Tournament_Participant__c` | Multi-session events. |
| `Player_Topic_Stat__c` | Per-player mastery rollup (keyword / tag / domain / difficulty). |
| `Study_Plan__c` + `Study_Guide_Theme__c` | Per-player nudging + the report theme. |
| `App_Setting__mdt` | All feature flags, quotas, model defaults, Slack/Stripe/OAuth client IDs. |
| `Slack_Event_Log__c` / `License_Event__c` | Idempotency logs for Slack + Stripe webhooks. |
| `App_Log__c` / `Audit_Log__c` | Debug logs + immutable admin-action audit. |
| `Usage_Metric__c` | Per-tenant per-month metering used by `EntitlementGuard`. |
| `Question_Generation_Job__c` | Async LLM job tracking (queueable runs). |
| `Achievement__c` / `Player_Achievement__c` | Award definitions + per-player awards. |

---

## Trivia_Question__c — every field

The question record. After cleanup, `Citation_Mode__c`, `Reference_Summary__c`, `Times_Asked__c`, `Times_Correct__c`, `Quality_Score__c` are **deleted** — do not emit them. Citation metadata lives on `Question_Citation__c` rows.

| Field | Type | Required | Set by | Purpose |
|---|---|---|---|---|
| `External_Id__c` | Text 80 (ext id) | yes | Import (upsert key) | Stable cross-pack identifier. Format: `<examCode>-<slug>-<n>`. |
| `Certification_Exam__c` | Lookup | yes | Import | Which exam this question belongs to. |
| `Question_Bank__c` | Lookup | yes | Import | Which versioned pack inserted it. |
| `Exam_Domain__c` | Lookup | recommended | Import | Resolved from JSON `domain` string against the exam's domains. |
| `Question_Text__c` | LongText | yes | Import | The prompt body. |
| `Scenario_Text__c` | LongText | no | Import | Optional set-up paragraph rendered above the question. |
| `Question_Type__c` | Picklist | yes | Import | `Multiple Choice` or `Multi Select`. |
| `Correct_Answer_Mode__c` | Picklist | derived | Import | `Exact` for MCQ, `MultiRequired` for Multi Select. Don't emit in JSON; derived from `questionType`. |
| `Difficulty__c` | Picklist | yes | Import | `Easy` / `Medium` / `Hard`. |
| `Status__c` | Picklist | system | Import (always `Draft`); `QuestionReviewController` only thing that sets `Published` | Workflow gate. **Code never publishes — humans do via the review LWC.** |
| `Explanation__c` | LongText | yes | Import | One-paragraph rationale shown after answer. |
| `Keywords__c` | LongText (CSV) | yes | Import | Comma-joined. Used for topic-stat rollups and word clouds. |
| `Tags__c` | Text 255 (CSV) | yes | Import | Same shape as keywords; broader badges. |
| `Named_Entities__c` | LongText (JSON array) | no | Import | JSON-serialized list of entity strings — knowledge-graph edges. |
| `Glossary_Terms__c` | LongText (JSON array) | no | Import | JSON-serialized list of `{term, definition}` for inline glossary. |
| `Primary_Reference_URL__c` | URL | yes | Import | The single canonical reference link shown on every card. |
| `Hash__c` | Text (indexed) | system | Import (`QuestionDuplicateDetector.hash`) | Dedup key = hash of question text + sorted correct answer texts. |
| `Fact_Check_Passed__c` | Checkbox | system | `QuestionReviewController` | Publish gate. |
| `Fact_Checked_By__c` | Lookup → User | system | `QuestionReviewController` | Who fact-checked. |
| `Fact_Checked_Date__c` | DateTime | system | `QuestionReviewController` | When. |
| `Published_By__c` | Lookup → User | system | `QuestionReviewController` | Who clicked Publish. |
| `Published_Date__c` | DateTime | system | `QuestionReviewController` | When. |
| `Last_Verified_Date__c` | Date | system | `QuestionReviewController` | Latest citation re-verification. |
| `Reviewer_Notes__c` | LongText | system | `QuestionReviewController` | Free-text review feedback. |

## Trivia_Answer_Choice__c — every field

| Field | Type | Required | Purpose |
|---|---|---|---|
| `Trivia_Question__c` | Master-Detail | yes | Parent question. |
| `Choice_Label__c` | Text (1) | yes | `A` / `B` / `C` / `D` (or `E`). |
| `Choice_Text__c` | LongText | yes | The answer text. |
| `Is_Correct__c` | Checkbox | yes | Marks this choice as correct. Multi Select allows multiple `true`. |
| `Explanation__c` | LongText | recommended | "Why correct" / "Why incorrect" detail surfaced on the result card. |
| `Why_Incorrect__c` | LongText | recommended | Specific to wrong answers. |
| `Direct_Statement__c` | LongText | recommended | Flashcard-style restatement. Used in analytics. |
| `Misconception_Tag__c` | Text 120 | recommended | Short category name for what wrong-answer pattern this choice represents (rolled up in `Player_Topic_Stat__c`). |
| `Sort_Order__c` | Number | system | Assigned at import (1..N). Sessions re-shuffle at runtime. |

## Question_Citation__c — every field

| Field | Type | Required | Purpose |
|---|---|---|---|
| `Trivia_Question__c` | Master-Detail | yes | Parent question. |
| `Title__c` | Text | yes | Citation display title. |
| `URL__c` | URL | yes | Source URL. |
| `Source_Type__c` | Picklist | no | `Official Docs` / `Trailhead` / `Blog` / `Other`. |
| `Quote_Or_Reference__c` | LongText | recommended | Direct quotation or section reference proving the answer. |
| `Relevance_Note__c` | LongText | no | Reviewer-only note about why this citation supports the question. |
| `Broken_Link__c` | Checkbox | system | Flipped by citation-verification jobs. |
| `Last_Verified_Date__c` | Date | system | When a human or job last checked. |
| `Verified_By__c` | Lookup → User | system | Who. |

---

## The question-pack JSON contract

A pack is a single JSON document. `CertGameImportService` consumes this exact shape — `sample_data/adm201-question-pack.sample.json` is the gold reference.

```json
{
  "pack": {
    "externalId": "adm201-fy26-q3",
    "examCode": "ADM-201",
    "name": "ADM-201 — FY26 Q3 Pack",
    "version": 3,
    "premium": false,
    "promptVersion": "v4",
    "generatedByModel": "claude-opus-4-7",
    "sourceType": "Generation"
  },
  "questions": [
    {
      "externalId": "adm201-security-roles-01",
      "domain": "Security & Access",
      "question": "A user reports they cannot edit Opportunity records they own. Their profile grants Read on Opportunity. What is the most likely cause?",
      "scenario": "The user is in a public group used in a sharing rule that grants Read Only access.",
      "questionType": "Multiple Choice",
      "difficulty": "Medium",
      "explanation": "Sharing rules can only widen access; they cannot reduce it. The Read-Only sharing rule from the public group adds Read but does not override the profile's Edit gap.",
      "keywords": ["sharing rules", "profile permissions", "object CRUD"],
      "tags": ["security", "sharing"],
      "namedEntities": ["Opportunity", "Public Group", "Sharing Rule"],
      "glossaryTerms": [
        { "term": "Sharing Rule", "definition": "Automatic record-level access extension to a group of users." }
      ],
      "primaryReferenceUrl": "https://help.salesforce.com/s/articleView?id=sf.security_sharing_rules.htm",
      "choices": [
        {
          "label": "A",
          "text": "The profile is missing Edit on Opportunity.",
          "isCorrect": true,
          "explanation": "Profile CRUD is the floor; sharing rules cannot grant Edit if the profile lacks it.",
          "directStatement": "Profile object permissions are required before sharing rules can grant access.",
          "misconceptionTag": null
        },
        {
          "label": "B",
          "text": "The sharing rule is set to Read Only.",
          "isCorrect": false,
          "whyIncorrect": "The sharing rule is correctly granting Read; the missing Edit comes from the profile.",
          "directStatement": "Sharing rules widen access; they don't downgrade it.",
          "misconceptionTag": "sharing-rule-downgrade"
        },
        {
          "label": "C",
          "text": "The org-wide default for Opportunity is Private.",
          "isCorrect": false,
          "whyIncorrect": "OWD Private with ownership would grant the owner full access; OWD doesn't block the owner.",
          "directStatement": "OWD does not restrict access to records the user owns.",
          "misconceptionTag": "owd-blocks-owner"
        },
        {
          "label": "D",
          "text": "The user's role is below the record owner's role.",
          "isCorrect": false,
          "whyIncorrect": "The user IS the record owner per the scenario, so role hierarchy is irrelevant.",
          "directStatement": "Role hierarchy affects records the user does not own.",
          "misconceptionTag": "role-vs-ownership"
        }
      ],
      "citations": [
        {
          "title": "Sharing rules — Help & Training",
          "url": "https://help.salesforce.com/s/articleView?id=sf.security_sharing_rules.htm",
          "sourceType": "Official Docs",
          "quoteOrReference": "Sharing rules give particular users greater access by making automatic exceptions to your org-wide sharing settings."
        }
      ]
    }
  ]
}
```

### Field-by-field rules

- `externalId` (question + pack) — unique within the pack. Used as upsert key. Format `<examCode>-<topic-slug>-<NN>`, lowercase, hyphenated.
- `domain` — must match an `Exam_Domain__c.Name` for the exam, or the import logs a warning and leaves the lookup null.
- `questionType` — exactly `"Multiple Choice"` or `"Multi Select"`. Multi Select REQUIRES ≥ 2 `isCorrect: true` choices.
- `difficulty` — exactly `"Easy"`, `"Medium"`, or `"Hard"`.
- `keywords`, `tags` — JSON arrays of strings. Persisted as comma-joined text (max 255 for `tags`).
- `namedEntities` — JSON array of strings; persisted as JSON-serialized text.
- `glossaryTerms` — JSON array of `{ term, definition }`; persisted as JSON-serialized text.
- `primaryReferenceUrl` — single canonical URL. Citations table holds the rest.
- `choices` — 3 to 5 entries. Exactly one `isCorrect: true` for MCQ; two or more for Multi Select. Always include `explanation` on the correct choice and `whyIncorrect` on every wrong choice.
- `misconceptionTag` — short kebab-case tag (≤ 120 chars). Identifies the wrong-answer pattern for analytics rollup. Optional on correct choices.
- `citations` — at least 1, ideally 2+. The first should match `primaryReferenceUrl`.
- **Status:** every imported question starts as `Draft`. Code never publishes; humans publish via the LWC review console.

### Hashing / dedup

`QuestionDuplicateDetector.hash(questionText, sortedCorrectChoiceTexts)` produces the `Hash__c` value. Two questions with the same prompt + same correct answers collapse to the same hash — pre-existing matches are kept and the new draft is rejected as a duplicate.

---

## Player__c — every field (post-cleanup)

`Notifications_Opt_In__c` removed. All others kept.

| Field | Type | Purpose |
|---|---|---|
| `Display_Name__c` | Text | Shown in leaderboards. Defaults to Google name on first sign-in. |
| `Google_Sub__c` | Text (ext id, 64) | Stable Google identifier. Upsert key for OAuth. |
| `Google_Email__c` | Email | Google email. |
| `Google_Name__c` | Text | Google display name. |
| `Google_Picture_URL__c` | URL | Avatar. |
| `Web_Last_Login_At__c` | DateTime | Most recent successful Google sign-in. |
| `Slack_User_Id__c` | Text (ext id) | Slack `U…` id. Upsert key for Slack-side play. |
| `Slack_Team_Id__c` | Text | Denormalized team id for tenant scoping. |
| `Tenant__c` | Lookup | Owning workspace. |
| `Salesforce_User__c` | Lookup → User | When a Salesforce user is the same person (admin mapping). |
| `Mapped_Contact__c` | Lookup → Contact | Fallback mapping for portal users. |
| `Timezone__c` | Text | Player's local TZ (used by nudge scheduler). |
| `Total_Points__c`, `Total_Games__c`, `Accuracy__c` | Number/Percent | Activity rollups. |
| `Current_Streak_Days__c`, `Longest_Streak_Days__c` | Number | Streak tracking. |
| `Last_Played_At__c` | DateTime | Most recent answer submission. |

## Tenant__c — every field (post-cleanup)

`Branding_Logo_URL__c`, `Branding_Primary_Color__c`, `Data_Region__c`, `Installed_By_User_Id__c` removed. Kept fields: `Slack_Team_Id__c` (ext id), `Workspace_Name__c`, `Admin_Slack_User_Ids__c`, `Plan__c`, `Status__c`, `Seats_Purchased__c`, `Trial_Ends_At__c`, `Installed_At__c`, `Stripe_Customer_Id__c`, `Stripe_Subscription_Id__c`.

## Game_Session__c — every field (post-cleanup)

`Anti_Cheat_Seed__c` removed (was never implemented — answer shuffle is now plain per-session randomization). All other fields retained: `Tenant__c`, `Certification_Exam__c`, `Tournament__c`, `Status__c`, `Mode__c`, `Started_At__c`, `Completed_At__c`, `Total_Questions__c`, `Current_Question_Index__c`, `Timer_Seconds__c`, `Slack_Channel_Id__c`, `Slack_Team_Id__c`, `Started_By_Slack_User_Id__c`, `Duel_Group_Id__c`, `Duel_Origin_Channel_Id__c`, `Duel_Opponent_Slack_User_Id__c`, `Duel_Role__c`.

## Game_Round__c — every field (post-cleanup)

`Ended_At__c`, `Correct_Answer_Revealed__c`, `Slack_Message_Ts__c` removed. Retained: `Game_Session__c`, `Trivia_Question__c`, `Round_Number__c`, `Status__c`, `Started_At__c`.

## Player_Answer__c — every field (post-cleanup)

`Hint_Used__c` removed. Retained: `Game_Session__c`, `Game_Round__c`, `Player__c`, `Trivia_Question__c`, `Selected_Choice__c`, `Selected_Choice_Labels__c`, `Selected_Choice_Text__c`, `Is_Correct__c`, `Points_Awarded__c`, `Response_Time_Ms__c`, `Answered_At__c`, `Misconception_Tag__c`, `Unique_Key__c` (ext id for upsert). Denormalized snapshots `Question_Domain__c`, `Question_Keywords__c`, `Question_Difficulty__c`, `Question_Tags__c` are retained for reporting.

---

## Generator prompt — copy-paste this into a question-pack generator

```
You generate Cert Game question packs as a single JSON document. Output ONLY the JSON, no prose.

CONTRACT
- Top-level shape: { "pack": {...}, "questions": [ ... ] }
- pack: externalId (kebab-case), examCode (e.g. "ADM-201"), name, version (integer), premium (bool), promptVersion, generatedByModel, sourceType ("Generation").
- Every question MUST have: externalId, domain, question, questionType, difficulty, explanation, keywords (array), tags (array), primaryReferenceUrl, choices, citations.
- Optional per question: scenario, namedEntities (array), glossaryTerms (array of {term, definition}).
- questionType: exactly "Multiple Choice" or "Multi Select". For Multi Select, two or more choices have isCorrect:true.
- difficulty: exactly "Easy" | "Medium" | "Hard".
- choices: 3–5 entries. Each: label ("A".."E"), text, isCorrect (bool). Always set explanation on the correct choice and whyIncorrect on each wrong choice. Add directStatement (a one-sentence factual restatement) on every choice. Add misconceptionTag (short kebab-case) on every wrong choice.
- citations: ≥1, ideally 2+. First citation MUST match primaryReferenceUrl. Each citation: title, url, sourceType ("Official Docs" | "Trailhead" | "Blog" | "Other"), quoteOrReference (verbatim quote or section ref).
- domain must be one of the exam's known domain names (caller will pass the list).
- externalId format: <examCode-lower>-<topic-slug>-<NN>.
- DO NOT emit: status, citationMode, referenceSummary, qualityScore, timesAsked, timesCorrect, antiCheatSeed, hintUsed — these fields do not exist.

QUALITY BAR
- Questions test reasoning, not recall. Prefer scenario-based prompts.
- Each wrong answer captures a real misconception (note it in misconceptionTag).
- Explanations cite the spec/docs, not vibes.
- Stay within the official exam blueprint domains.

INPUTS THE CALLER PROVIDES
- examCode + name
- list of valid domain names for that exam
- target question count
- difficulty mix (e.g. 30% Easy / 50% Medium / 20% Hard)
- any topics to emphasize or avoid

OUTPUT: a single JSON object. Validate against the contract before responding.
```

---

## Verifying a generated pack locally

```bash
python scripts/validate-question-json.py sample_data/<your-pack>.sample.json
sf apex run -o certgame -f scripts/apex/import-question-pack.apex   # or via the LWC importer
```

If validation fails, the script prints the JSON-path of the offending field. Common failures: missing `whyIncorrect` on wrong choices, `domain` not matching any `Exam_Domain__c.Name`, fewer than 2 correct choices on a Multi Select.
