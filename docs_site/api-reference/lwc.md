# Lightning Web Components

All LWCs live under
[force-app/main/default/lwc/](https://github.com/sfboss/slack_certification_salesforce_trivia/tree/main/force-app/main/default/lwc).

## Inventory

| LWC | Backing Apex | Purpose |
| --- | --- | --- |
| `certGameAdminHome` | composed | Hosts the 4-tab admin landing page (Review Drafts, Question Bank, Generation Jobs, Tournaments). |
| `certGameAdminDashboard` | `CertGameAdminDashboardController` | Org-wide gameplay metrics. |
| `certGamePlayerDashboard` | `CertGamePlayerDashboardController` | Per-player drill-down. |
| `certGameLeaderboard` | `CertGameLeaderboardController` | In-org leaderboard view. |
| `certGameBilling` | `CertGameBillingController` | Tenant plan management UI. |
| `questionBankManager` | `CertGameImportService` | Upload pack JSON; list `Question_Bank__c` records. |
| `questionReviewConsole` | `QuestionReviewController` | Inline-edit drafts; publish / reject; show citations. |
| `generationJobConsole` | (CometD over `QuestionGenerationJob__e`) | Live status stream of generation jobs. |
| `tournamentBuilder` | `CertGameTournamentService` | Tournament creation + bracket build. |

## Conventions

- One folder per component (`force-app/main/default/lwc/<name>/`).
- Reads via `@wire` of `@AuraEnabled(cacheable=true)` Apex methods.
- Errors surfaced through `ShowToastEvent`.
- All styling through Lightning Design System tokens — no hardcoded colors except
  tenant-specific branding fields.

## Embedding

The admin app `Cert_Game_Manager` (definition:
[Cert_Game_Manager.app-meta.xml](https://github.com/sfboss/slack_certification_salesforce_trivia/blob/main/force-app/main/default/applications/Cert_Game_Manager.app-meta.xml))
includes the LWC-backed tabs. Open via:

```bash
sf org open -o certgame -p /lightning/app/Cert_Game_Manager
```

## Platform event consumers

The `generationJobConsole` LWC subscribes to `QuestionGenerationJob__e` via the empApi
CometD bridge. Each event row contains:

| Field | Value |
| --- | --- |
| `Job_Id__c` | Owning `Question_Generation_Job__c` Id. |
| `Tenant_Id__c` | `Tenant__c` Id. |
| `Status__c` | `Queued` / `Running` / `Succeeded` / `Failed`. |
| `Generated_Count__c` | Questions inserted so far. |
| `Message__c` | Provider message (e.g. token usage, error). |

Manually fire one for UI testing:

```apex
EventBus.publish(new QuestionGenerationJob__e(
    Job_Id__c = 'smoke',
    Tenant_Id__c = 'tnt',
    Status__c = 'Succeeded',
    Generated_Count__c = 5,
    Message__c = 'manual test'
));
```
