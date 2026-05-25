---
title: Data Model
icon: material/database-outline
---

# :material-database-outline: Data Model

The `CertGameSlackManager` package stores **every byte of state** inside Salesforce. Slack and the web companion are thin clients. This section is the canonical, field-level reference for the data model — what each object is for, what every field means, what's editable by humans, and what's calculated or written by the system.

!!! abstract "What lives here"
    - **27 custom objects** (`__c`), grouped by business concept on the pages below
    - **1 custom metadata type** (`App_Setting__mdt`) for runtime knobs
    - **2 platform events** (`QuestionAnswered__e`, `QuestionGenerationJob__e`) for streaming
    - API version **60.0**, sharing mode `with sharing` everywhere except three documented entry points

## Pages in this section

<div class="grid cards" markdown>

-   :material-map-legend:{ .lg .middle } **[Conventions & Legend](conventions.md)**

    ---

    Field-category icons (editable vs system vs formula vs rollup), sharing rules, idempotency keys, naming.

-   :material-graph-outline:{ .lg .middle } **[Entity Relationship Diagram](erd.md)**

    ---

    The full ERD — every object, every relationship, with zoomed sub-diagrams per business concept.

-   :material-timeline-outline:{ .lg .middle } **[Lifecycles](lifecycles.md)**

    ---

    State machines for Game Sessions, Trivia Questions, and Generation Jobs.

-   :material-office-building-outline:{ .lg .middle } **[Tenancy & Identity](tenancy.md)**

    ---

    `Tenant__c`, `Player__c`, `Usage_Metric__c`, `License_Event__c`.

-   :material-book-open-page-variant-outline:{ .lg .middle } **[Content & Curation](content.md)**

    ---

    `Certification_Exam__c`, `Exam_Domain__c`, `Question_Bank__c`, `Trivia_Question__c`, `Trivia_Answer_Choice__c`, `Question_Citation__c`.

-   :material-controller-classic:{ .lg .middle } **[Gameplay](gameplay.md)**

    ---

    `Game_Session__c`, `Game_Round__c`, `Player_Answer__c`. The hot path.

-   :material-trophy-outline:{ .lg .middle } **[Tournaments](tournaments.md)**

    ---

    `Tournament__c`, `Tournament_Participant__c`, leaderboards.

-   :material-account-star-outline:{ .lg .middle } **[Engagement & Insights](engagement.md)**

    ---

    `Achievement__c`, `Player_Achievement__c`, `Player_Topic_Stat__c`, `Study_Plan__c`, `Study_Guide_Theme__c`, `Leaderboard_Snapshot__c`.

-   :material-cog-outline:{ .lg .middle } **[Platform & Operations](platform.md)**

    ---

    `App_Setting__mdt`, `App_Log__c`, `Audit_Log__c`, `Slack_Event_Log__c`, `Question_Generation_Job__c`, platform events.

</div>

## How to read these pages

Every object page follows the same shape:

1. **Purpose** — one paragraph: what role this object plays in the runtime.
2. **Mini ERD** — a Mermaid diagram showing only this object's immediate neighbours.
3. **Field table** — every custom field, categorised, with the writer (who/what populates it) and the reason it exists.
4. **Used by** — the Apex classes / LWCs that read or write the object.
5. **Gotchas** — sharing, idempotency, ordering rules that bite if you ignore them.

!!! tip "Reading the field category column"
    Field-category icons appear on every row. See [Conventions & Legend](conventions.md) for definitions; the short version:

    - :material-pencil-outline: **editable** — humans set this via UI/import
    - :material-cog-sync-outline: **system** — only Apex writes this (timestamps, hashes, snapshots, ext-ids)
    - :material-calculator-variant-outline: **formula** — derived at read time, never stored
    - :material-table-sync: **rollup** — Salesforce roll-up summary
    - :fontawesome-solid-skull-crossbones: **deprecated / unused** — slated for removal, do not depend on
