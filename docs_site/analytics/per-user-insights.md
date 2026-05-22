# Per-User Insights & Adaptive Study

This page describes the analytics surface that ships with the question-metadata
enhancements: what we collect, how it accumulates per user, and how it powers
word clouds, knowledge graphs, and guided study sessions.

## Goal

Make the trivia engine behave like a **caddy** for the test taker — keep
context flowing, surface vocabulary the moment it appears, and route the next
question toward the player's weak spots rather than randomly.

## What we collect on every answer

When a player taps an answer in Slack, `CertGameSessionService.recordAnswerFromSlack`
now records:

- The exact choice (`Player_Answer__c.Selected_Choice__c`) and its text snapshot.
- The question's domain, difficulty, keywords, and tags (snapshotted onto the
  Player_Answer record so historic analytics survive question edits).
- The misconception tag from the chosen distractor, when the answer is wrong.

After the upsert, `CertGamePlayerInsightsService.recordAnswerInsights` rolls
each of those signals into one `Player_Topic_Stat__c` row per
`(player, topicType, topicValue)`, incrementing `Times_Seen__c`,
`Times_Correct__c`, and `Times_Incorrect__c`. The roll-up is idempotent via the
composite external id `Topic_Key__c = PlayerId|Type|lower(value)`.

## Topic types

| Topic_Type__c | Source | Use |
| ------------- | ------ | --- |
| `Keyword` | `Trivia_Question__c.Keywords__c` (semicolon list) | Word cloud, weakness ranking. |
| `Tag` | `Trivia_Question__c.Tags__c` (semicolon list) | Curated taxonomy; study-plan filters. |
| `Entity` | `Trivia_Question__c.Named_Entities__c` (`[{type,value}]`) | Knowledge-graph nodes. |
| `Domain` | `Exam_Domain__r.Name` | Exam-blueprint coverage. |
| `Difficulty` | `Trivia_Question__c.Difficulty__c` | Calibrates next-question difficulty. |
| `Misconception` | `Trivia_Answer_Choice__c.Misconception_Tag__c` (only on wrong picks) | Targeted remediation. |

## Caddy behavior on the result card

The Slack result card now appends, when present:

- **Why your pick was wrong** — the picked choice's `Why_Incorrect__c`.
- **Key idea** — the correct choice's `Direct_Statement__c`.
- **Glossary** — terms + definitions from the question, inlined so unfamiliar
  vocabulary is defined right where it appears.
- **Reference** — a single canonical link from `Primary_Reference_URL__c`.

Players don't have to leave the channel to decode jargon.

## Word cloud

```sql
SELECT Topic_Value__c, Times_Seen__c, Accuracy_Pct__c
FROM Player_Topic_Stat__c
WHERE Player__c = :playerId AND Topic_Type__c = 'Keyword'
ORDER BY Times_Seen__c DESC
LIMIT 50
```

Render each `Topic_Value__c` sized by `Times_Seen__c` and colored by
`Accuracy_Pct__c` (red < 50%, amber 50–80%, green > 80%). The same query with
`Topic_Type__c = 'Entity'` gives you a domain-vocabulary cloud.

## Knowledge graph

`Trivia_Question__c.Named_Entities__c` is a JSON list of `{type, value}` pairs.
Two questions that share an entity (e.g. `Feature: Role Hierarchy`) form an
implicit edge. To build a per-player knowledge graph:

1. Pull every `Player_Topic_Stat__c` where `Topic_Type__c = 'Entity'`.
2. Pull every `Trivia_Question__c` the player has answered that references any
   of those entities (via `Player_Answer__c → Trivia_Question__c` and the
   `Named_Entities__c` JSON).
3. Nodes = entities + questions; edges = "question mentions entity"; node
   weight = `Times_Seen__c`; node color = `Accuracy_Pct__c`.

The output drops cleanly into a force-directed graph (D3, Cytoscape, vis.js).

## Weakest-topics list (guided study)

```sql
SELECT Topic_Type__c, Topic_Value__c, Times_Seen__c, Times_Correct__c, Accuracy_Pct__c
FROM Player_Topic_Stat__c
WHERE Player__c = :playerId AND Times_Seen__c >= 3
ORDER BY Accuracy_Pct__c ASC, Times_Incorrect__c DESC NULLS LAST
LIMIT 10
```

`CertGamePlayerInsightsService.weakestTopics(playerId, minSeen, limitN)` wraps
this query. A study-session planner can then:

1. Pick the top N weakest topics.
2. Use `Trivia_Question__c WHERE Keywords__c LIKE '%topic%' OR Tags__c LIKE
   '%topic%'` to select 5–10 published questions emphasizing those topics.
3. Hand that list to `CertGameQuestionService.pickQuestions` (filter by
   `questionIds`) to start a focused session.

## Recurring misconceptions

```sql
SELECT Topic_Value__c, Times_Incorrect__c, Last_Seen_At__c
FROM Player_Topic_Stat__c
WHERE Player__c = :playerId AND Topic_Type__c = 'Misconception'
ORDER BY Times_Incorrect__c DESC, Last_Seen_At__c DESC
LIMIT 5
```

Each row is a concrete remediation prompt: "You keep picking
`confuses-owd-with-hierarchy` — let's fix that." The author of the question
controls the tag, so the messaging stays accurate.

## Sample data

[`sample_data/adm201-question-pack.enhanced.sample.json`](../../sample_data/adm201-question-pack.enhanced.sample.json)
shows one fully-tagged question:

- `keywords`, `tags`, `namedEntities`, `glossaryTerms`, `primaryReferenceUrl`
  on the question.
- `whyIncorrect`, `directStatement`, `misconceptionTag` on each choice
  (correct choices skip `whyIncorrect`).

## What's coming

- A native Block Kit word-cloud / "weak spots" card surfaced from App Home.
- An LWC graph view for admins (entity ↔ question ↔ player accuracy).
- A study-plan generator that consumes `weakestTopics()` and schedules nudges.
- Decay weighting: `Last_Seen_At__c` driving an exponential half-life so stale
  topics don't dominate the cloud.

See [QUESTION_METADATA_ENHANCEMENTS.md](../../QUESTION_METADATA_ENHANCEMENTS.md)
in the repo root for the full schema diff and migration notes.
