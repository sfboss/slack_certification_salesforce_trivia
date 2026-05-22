# Documentation Gaps & Follow-ups

Items observed during doc generation that need verification or future work.

## Confirmed in source, partially documented
- Slash subcommands `debug`, `doctor`, `notify-test` are wired in
  [SlackCertGameCommandHandler.cls](https://github.com/sfboss/slack_certification_salesforce_trivia/blob/main/force-app/main/default/classes/SlackCertGameCommandHandler.cls)
  but were not part of the original spec's user-facing command list. Documented as
  "diagnostic subcommands" — verify they should remain user-facing.

## Repo-only references
- `CertGameGenerationDispatcher.enqueue(...)` is referenced in
  [docs/user-guide.md](https://github.com/sfboss/slack_certification_salesforce_trivia/blob/main/docs/user-guide.md)
  but the class file present in `force-app/main/default/classes/` is
  `CertGameGenerationJobQueueable.cls`. The dispatcher entry point may have been renamed —
  confirm before publishing the user-guide snippet.
- `Question__c` and `Question_Choice__c` names appear in `docs/user-guide.md`, but the
  deployed objects are `Trivia_Question__c` and `Trivia_Answer_Choice__c`. Treat
  `Trivia_*` as canonical.

## Missing from repo, deferred to follow-up
- 2GP package version cut log (`v0.1.0-beta`) — referenced in `PROJECT_LOG.md` but no
  packaging output stored in repo.
- No formal OpenAPI / Apex REST schema export. The
  [Salesforce APIs](salesforce/apis.md) page documents endpoints from source.
- Mermaid ERD only covers the most-touched objects. A full ERD across all 27 objects is
  out of scope for the first doc cut.

## Known wording discrepancies
- README.md at the repo root is mostly a Salesforce DX boilerplate. The real overview lives
  in `AGENTS.md` and `docs/user-guide.md`. Consider replacing the root README with a
  pointer to this docs site.
