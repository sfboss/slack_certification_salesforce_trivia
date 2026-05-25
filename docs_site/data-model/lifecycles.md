---
title: Lifecycles
icon: material/timeline-outline
---

# :material-timeline-outline: Lifecycles

State machines for the three records that actually move through workflow states. Most other objects are append-only or last-write-wins; these three have real transitions you can break by writing to them out of order.

## Trivia Question lifecycle

Questions are born as drafts. **Code is never allowed to set `Status__c = Published`** — only the `questionReviewConsole` LWC, driven by a human reviewer, may.

```mermaid
stateDiagram-v2
    [*] --> Draft : Import / Generator
    Draft --> NeedsReview : Reviewer opens the card
    NeedsReview --> NeedsRevision : Reviewer requests changes
    NeedsRevision --> NeedsReview : Author re-submits
    NeedsReview --> Published : Reviewer clicks Publish (sets Fact_Check_Passed__c, Published_By__c, Published_Date__c)
    Published --> Retired : Admin retires (removed from session pool)
    NeedsReview --> Rejected : Reviewer rejects
    Retired --> [*]
    Rejected --> [*]
```

!!! danger "Publish-gate invariants"
    `CertGameSessionService` selects only `Status__c = 'Published'` questions when building a session. If you bypass the review LWC and flip status programmatically, you've smuggled an un-fact-checked question into production play. The unit tests for `QuestionReviewController` exist to enforce this — don't suppress them.

## Game Session lifecycle

```mermaid
stateDiagram-v2
    [*] --> Setup : SessionService.start() (Mode set: Solo / Duel / Tournament)
    Setup --> Active : First round posted to Slack
    Active --> Active : recordAnswerFromSlack (per round)
    Active --> Paused : Player /certgame pause (Solo only)
    Paused --> Active : /certgame resume
    Active --> Completed : Final round answered → @future callout finalizes
    Active --> Abandoned : 24h inactivity sweep
    Completed --> [*]
    Abandoned --> [*]
```

### Why the finale is a `@future(callout=true)`

The last round's answer DML and the Slack `chat.postMessage` for the finale card can't share a transaction (Apex forbids callouts after DML). `CertGameSessionService.recordAnswerFromSlack` enqueues `CertGameDuelFinalizer` (`@future(callout=true)`) for the last answer. Don't try to "fix" this by reordering.

## Generation Job lifecycle

```mermaid
stateDiagram-v2
    [*] --> Queued : Controller.startJob() inserts Question_Generation_Job__c
    Queued --> Running : Queueable.execute() begins
    Running --> Running : Provider callout, validation, import, dedup
    Running --> Completed : Successful import — Generated_Question_Count__c set, event published
    Running --> Failed : Any exception — Error_Message__c set, event published with status=Failed
    Completed --> [*]
    Failed --> [*]
```

The `QuestionGenerationJob__e` platform event fires on every transition so the `generationJobConsole` LWC can stream progress without polling.
