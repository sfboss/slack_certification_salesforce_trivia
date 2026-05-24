# Features

## Player surface (Slack)

| Feature               | How to use it                                                                                                                                        |
| --------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Quick game**        | `/certgame play [CODE]` — Solo 5-question session.                                                                                                   |
| **Head-to-head duel** | `/certgame challenge @user [CODE]` — channel-visible 1v1. Both players play 5 independent questions; finale posts back with scores + Rematch button. |
| **Tournaments**       | Created from the Cert Game Manager Lightning app; joined via `/certgame play <tournamentId>`.                                                        |
| **Leaderboards**      | `/certgame leaderboard [CODE]`.                                                                                                                      |
| **Personal stats**    | `/certgame stats`. Sourced from `Player__c` rollups.                                                                                                 |
| **Study plan**        | `/certgame plan` opens a modal: pick exam, target date, nudge cadence.                                                                               |
| **Daily nudges**      | `CertGameNudgeScheduler` DMs players with active plans. Off-tenant default.                                                                          |
| **Achievements**      | Awarded automatically by `CertGameAchievementService` on every answer; surfaced via DM and on the App Home tab.                                      |
| **Billing portal**    | `/certgame billing` (Pro/Enterprise admins) opens the Stripe Customer Portal modal.                                                                  |
| **App Home**          | Opening the bot DM shows a curated home view with stats and quick buttons.                                                                           |

## Admin surface (Salesforce)

In the **Cert Game Manager** Lightning app, the **Cert Game Admin Home** page exposes:

| Tab                  | Purpose                                                                                         |
| -------------------- | ----------------------------------------------------------------------------------------------- |
| **Review Drafts**    | Inline edit and publish `Trivia_Question__c` records (`questionReviewConsole` LWC).             |
| **Question Bank**    | Upload JSON packs and view existing banks (`questionBankManager` LWC).                          |
| **Generation Jobs**  | Live status stream over `QuestionGenerationJob__e` platform event (`generationJobConsole` LWC). |
| **Tournaments**      | Create and bracket tournaments (`tournamentBuilder` LWC).                                       |
| **Admin Dashboard**  | Org-wide gameplay metrics (`certGameAdminDashboard`).                                           |
| **Player Dashboard** | Per-player drilldown (`certGamePlayerDashboard`).                                               |
| **Leaderboard**      | Internal leaderboard view (`certGameLeaderboard`).                                              |
| **Billing**          | Tenant plan + Stripe portal links (`certGameBilling`).                                          |

LWC reference: [Lightning Web Components](../api-reference/lwc.md).

## Background features

- **Citation auditor** — pings every `Question_Citation__c.URL__c` and flags broken links.
- **Nudge scheduler** — DMs players who have active study plans and haven't played today.
- **Question generation pipeline** — Queueable Apex calls OpenAI/Gemini/Claude, validates
  output, inserts drafts. Never auto-publishes.
- **Audit log** — every publish/edit/retire/generation-approval lands in `Audit_Log__c`.

## Scoring formula

From [`CertGameScoringService`](../api-reference/apex.md#certgamescoringservice):

```text
base        = Easy 10 | Medium 20 | Hard 30
timeBonus   = floor(base * (timeRemaining / timeLimit) * 0.5)
streakBonus = min(streakLength * 2, 20)
penalty     = -base/2 (only when penaltyEnabled = true)
points      = correct ? (base + timeBonus + streakBonus) : penalty
```

Streak is reset to 0 on any wrong answer.

## Plans and entitlements

From [`EntitlementGuard`](../api-reference/apex.md#entitlementguard):

| Plan       | Games / month | Generation / month | Tournaments |
| ---------- | ------------- | ------------------ | ----------- |
| Free       | 100           | 0                  | No          |
| Pro        | 5,000         | 200                | Yes         |
| Enterprise | Unlimited     | Unlimited          | Yes         |

Counters live on `Usage_Metric__c` keyed by `tenantId:YYYY-MM`.
