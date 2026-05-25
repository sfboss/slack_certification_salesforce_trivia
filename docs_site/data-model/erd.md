---
title: Entity Relationship Diagram
icon: material/graph-outline
---

# :material-graph-outline: Entity Relationship Diagram

The full ERD across all 27 custom objects. If you're just orienting yourself, start with the **zoomed sub-diagrams** below; the full diagram is dense on purpose.

## Full ERD

```mermaid
erDiagram
    Tenant__c ||--o{ Player__c : "scopes"
    Tenant__c ||--o{ Game_Session__c : "owns"
    Tenant__c ||--o{ Question_Bank__c : "owns"
    Tenant__c ||--o{ Question_Generation_Job__c : "requested"
    Tenant__c ||--o{ Usage_Metric__c : "metered"
    Tenant__c ||--o{ License_Event__c : "billed via"
    Tenant__c ||--o{ Tournament__c : "hosts"
    Tenant__c ||--o{ App_Log__c : "logs"

    Player__c ||--o{ Player_Answer__c : "submits"
    Player__c ||--o{ Player_Achievement__c : "earns"
    Player__c ||--o{ Player_Topic_Stat__c : "rolls up"
    Player__c ||--o{ Study_Plan__c : "follows"
    Player__c ||--o{ Tournament_Participant__c : "joins"

    Certification_Exam__c ||--o{ Exam_Domain__c : "split by"
    Certification_Exam__c ||--o{ Question_Bank__c : "versions"
    Certification_Exam__c ||--o{ Trivia_Question__c : "contains"
    Certification_Exam__c ||--o{ Tournament__c : "covers"
    Certification_Exam__c ||--o{ Study_Plan__c : "targets"
    Certification_Exam__c ||--o{ Question_Generation_Job__c : "targets"

    Question_Bank__c ||--o{ Trivia_Question__c : "groups"
    Exam_Domain__c ||--o{ Trivia_Question__c : "categorises"
    Trivia_Question__c ||--|{ Trivia_Answer_Choice__c : "choices (MD)"
    Trivia_Question__c ||--o{ Question_Citation__c : "cites"
    Trivia_Question__c ||--o{ Game_Round__c : "asked in"
    Trivia_Question__c ||--o{ Player_Answer__c : "answered"

    Game_Session__c ||--o{ Game_Round__c : "round-by-round"
    Game_Session__c ||--o{ Player_Answer__c : "answers"
    Game_Session__c ||--o{ Leaderboard_Snapshot__c : "snapshots"
    Game_Round__c ||--o{ Player_Answer__c : "collects"
    Trivia_Answer_Choice__c ||--o{ Player_Answer__c : "selected as"

    Tournament__c ||--o{ Tournament_Participant__c : "rosters"
    Tournament__c ||--o{ Game_Session__c : "schedules"
    Tournament_Participant__c }o--|| Player__c : "player"

    Achievement__c ||--o{ Player_Achievement__c : "awarded as"
```

## By business concept

### Tenancy & Identity

```mermaid
erDiagram
    Tenant__c ||--o{ Player__c : "members"
    Tenant__c ||--o{ Usage_Metric__c : "per-month"
    Tenant__c ||--o{ License_Event__c : "stripe events"
    Player__c }o--o| User : "Salesforce admin map"
    Player__c }o--o| Contact : "Portal map"
```

### Content

```mermaid
erDiagram
    Certification_Exam__c ||--o{ Exam_Domain__c : "split"
    Certification_Exam__c ||--o{ Question_Bank__c : "version"
    Question_Bank__c ||--o{ Trivia_Question__c : "contents"
    Exam_Domain__c ||--o{ Trivia_Question__c : "domain"
    Trivia_Question__c ||--|{ Trivia_Answer_Choice__c : "MD choices"
    Trivia_Question__c ||--o{ Question_Citation__c : "sources"
```

### Gameplay

```mermaid
erDiagram
    Game_Session__c ||--o{ Game_Round__c : "rounds"
    Game_Round__c ||--|| Trivia_Question__c : "asks"
    Game_Round__c ||--o{ Player_Answer__c : "answers"
    Player_Answer__c }o--|| Player__c : "by"
    Player_Answer__c }o--o| Trivia_Answer_Choice__c : "picked"
```

### Tournaments

```mermaid
erDiagram
    Tournament__c ||--o{ Tournament_Participant__c : "roster"
    Tournament__c ||--o{ Game_Session__c : "match"
    Tournament_Participant__c }o--|| Player__c : "is"
    Tournament__c }o--|| Certification_Exam__c : "covers"
    Tournament__c }o--o| Player__c : "winner"
```

### Engagement & Insights

```mermaid
erDiagram
    Achievement__c ||--o{ Player_Achievement__c : "awarded"
    Player__c ||--o{ Player_Achievement__c : "earned"
    Player__c ||--o{ Player_Topic_Stat__c : "mastery rollup"
    Player__c ||--o{ Study_Plan__c : "active plan"
    Study_Plan__c }o--|| Certification_Exam__c : "for exam"
    Study_Guide_Theme__c ||..o| Study_Plan__c : "renders into report (no FK)"
```

### Platform & Operations

```mermaid
erDiagram
    App_Setting__mdt ||..|| Tenant__c : "global knobs (read at runtime)"
    Slack_Event_Log__c }o..|| Tenant__c : "tenant-scoped (by team id)"
    Question_Generation_Job__c }o--|| Tenant__c : "requested by"
    Question_Generation_Job__c }o--|| Certification_Exam__c : "targets"
    Audit_Log__c }o..|| User : "actor (Salesforce user)"
    App_Log__c }o..|| Tenant__c : "tenant-scoped if known"
```

!!! info "Why some lines are dotted"
    Dotted lines (`..`) are **logical** relationships not enforced by a lookup field — e.g. `Slack_Event_Log__c.Slack_Team_Id__c` is a text field that matches `Tenant__c.Slack_Team_Id__c` semantically, but there is no Salesforce relationship. This is intentional: idempotency logs and audit rows must survive tenant deletion.
