# Data Flow

## Question lifecycle

```mermaid
stateDiagram-v2
    [*] --> Draft: Import or Generation
    Draft --> Reviewed: Reviewer edits
    Draft --> Rejected: Reviewer rejects
    Reviewed --> Published: Reviewer publishes
    Generated --> Reviewed
    Generated --> Rejected
    Published --> Retired: Admin retires
    Retired --> [*]
    Rejected --> [*]
```

Only `Published` questions are selected by
[`CertGameSessionService.openNextRound`](../api-reference/apex.md#certgamesessionservice).

## Solo game

```mermaid
sequenceDiagram
    participant U as User
    participant H as CommandHandler
    participant G as EntitlementGuard
    participant T as TenantService
    participant S as SessionService
    participant SC as ScoringService
    participant D as Data

    U->>H: /certgame play ADM-201
    H->>T: getOrCreateTenant(team_id)
    T->>D: upsert Tenant__c
    H->>G: canStartGame(tenantId)
    G->>D: read Usage_Metric__c
    G-->>H: true
    H->>T: getOrCreatePlayer(tenantId, user_id)
    T->>D: upsert Player__c
    H->>S: startQuickGameFromSlack(...)
    S->>D: insert Game_Session__c, Game_Round__c
    S-->>H: round card JSON

    loop until last round
        U->>H: tap answer button
        H->>S: recordAnswerFromSlack(round, choice)
        S->>SC: score(input)
        SC-->>S: points
        S->>D: insert Player_Answer__c (unique key)
        S->>D: update Player__c rollups
        S-->>H: explanation + next round card
    end

    S-->>H: finale card
```

## Duel

```mermaid
sequenceDiagram
    participant A as Challenger
    participant B as Opponent
    participant CH as DuelService
    participant D as Data

    A->>CH: /certgame challenge @B ADM-201
    CH->>D: insert two Game_Session__c (Mode=Duel, linked by Duel_Group_Id__c)
    CH-->>A: channel card (Accept/Decline)
    B->>CH: click Accept
    CH-->>A: DM round 1 of A's session
    CH-->>B: DM round 1 of B's session
    par independent play
        A->>CH: answers
    and
        B->>CH: answers
    end
    Note over CH: When both sessions Completed,<br/>finalize via @future callout
    CH-->>A: finale card in origin channel
    CH-->>B: finale card in origin channel
```

## Stripe webhook

```mermaid
sequenceDiagram
    participant S as Stripe
    participant EP as StripeWebhookHandler
    participant V as StripeSignatureVerifier
    participant D as Data

    S->>EP: POST + Stripe-Signature
    EP->>V: verify(headers, rawBody)
    V-->>EP: ok
    EP->>D: upsert License_Event__c by Stripe_Event_Id__c
    alt new event
        EP->>D: update Tenant__c.Plan__c / Status__c
    else duplicate
        EP-->>S: 200 (no-op)
    end
```

## Question generation

```mermaid
sequenceDiagram
    participant A as Admin / Player
    participant Q as Queueable
    participant P as Provider (OpenAI/Gemini/Claude)
    participant V as QuestionJsonValidator
    participant D as Data
    participant E as QuestionGenerationJob__e

    A->>Q: enqueueJob
    Q->>E: Status=Running
    Q->>P: callout via Named Credential
    P-->>Q: JSON
    Q->>V: validate(json)
    alt valid
        Q->>D: insert Trivia_Question__c (Status=Draft)
        Q->>E: Status=Succeeded
    else invalid
        Q->>E: Status=Failed (message)
    end
```

The `QuestionGenerationJob__e` Platform Event drives the `generationJobConsole` LWC over
CometD.

## Nudge dispatcher

```mermaid
sequenceDiagram
    participant T as Cron
    participant N as CertGameNudgeScheduler
    participant D as Data
    participant SC as SlackApiClient

    T->>N: execute()
    N->>D: SELECT Study_Plan__c WHERE Next_Nudge_At__c <= NOW()
    loop each plan in tz window
        N->>SC: chat.postMessage (DM player)
        N->>D: update Next_Nudge_At__c
    end
```
