# Contributing

## Branches

| Prefix | When |
| --- | --- |
| `feat/...` | New behavior. |
| `fix/...` | Bug fix. |
| `chore/...` | Tooling, refactors, deps. |
| `phase-<N>-...` | Multi-PR work tied to an AGENTS.md phase. |

## Commits

Conventional Commits:

- `feat: add duel rematch button`
- `fix: idempotent stripe upsert by event id`
- `refactor: split scoring inputs into DTO`
- `test: cover entitlement guard period rollover`
- `docs: expand slack setup`

## Code style

### Apex

- One class = one responsibility.
- Services: stateless `static` methods accepting and returning DTO inner classes.
- `with sharing` everywhere unless explicit reason (then comment).
- Bulkified APIs: `List<>` first; single-record convenience wraps them.
- `WITH USER_MODE` SOQL for user-driven reads; `WITH SYSTEM_MODE` only inside intentional
  `without sharing` shims.
- No SOQL/DML in loops.
- No `SeeAllData=true` in tests.
- Naming: `*Service`, `*Handler`, `*Provider`, `*Validator`, `*Scheduler`, `*Queueable`.
- Tests live in the same folder, suffixed `_Test`. Use `@TestSetup` and
  `Test.startTest()/stopTest()`.

### Custom metadata, not constants

Quotas, model names, feature flags belong in `App_Setting__mdt`. Read via
[`AppSettings`](../api-reference/apex.md#appsettings).

### Block Kit + strings

- All Block Kit JSON in `CertGameSlackRenderService`.
- All user-facing strings in `CertGameStrings`.
- No emoji in code. Emoji is fine in Block Kit user-facing strings.

### LWC

- One folder per component.
- `@wire` for reads; `@AuraEnabled(cacheable=true)` on the Apex side.
- Errors → `ShowToastEvent`.
- Only LDS tokens for styling.

## Linters

| Tool | Config |
| --- | --- |
| ESLint | [eslint.config.js](https://github.com/sfboss/slack_certification_salesforce_trivia/blob/main/eslint.config.js) |
| Prettier | `prettier-plugin-apex` |
| Apex PMD | [pmd-ruleset.xml](https://github.com/sfboss/slack_certification_salesforce_trivia/blob/main/pmd-ruleset.xml) |
| Salesforce Scanner | `sf scanner run --target force-app --severity-threshold 2` |

## Pull request gates

From [AGENTS.md §6](https://github.com/sfboss/slack_certification_salesforce_trivia/blob/main/AGENTS.md):

- All deploys clean to a fresh scratch org.
- Apex tests pass with required coverage.
- No new High-severity Scanner findings.
- No hardcoded secrets or URLs.
- README and AGENTS updated when behavior changes.
- Phase tagged in git when applicable.

## Operational safety

The following require explicit human approval and a callout in the PR description:

- Security model changes.
- Data model changes (new fields/objects, sharing changes).
- Billing logic changes.
- New Slack scopes or webhook URLs.

## Open questions

If unsure about a design decision, write a note in
[docs/open-questions.md](https://github.com/sfboss/slack_certification_salesforce_trivia/blob/main/docs)
(create the file if it doesn't exist yet) rather than guessing.

## Memory & non-goals

Out-of-scope items (do not build without explicit ask) per
[AGENTS.md §7](https://github.com/sfboss/slack_certification_salesforce_trivia/blob/main/AGENTS.md):

- Standalone web UI for players.
- Mobile native app.
- Free-text answer grading.
- Replacement of Salesforce auth.
- Real-money prizes.
