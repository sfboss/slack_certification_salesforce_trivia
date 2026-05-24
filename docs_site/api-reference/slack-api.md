# Slack Integration Reference

## Inbound

All inbound calls land at `POST /services/apexrest/slack/events`. See the contract in the
[Salesforce REST](salesforce-api.md) page and the [Slack events](../slack/events.md) page
for routing semantics.

## Outbound

All outbound calls go through [`SlackApiClient`](apex.md#slackapiclient) using the
`Slack_Bot` Named Credential. The endpoint is always
`callout:Slack_Bot/<method>`.

| Slack method         | Caller                                                                                       | Purpose                                        |
| -------------------- | -------------------------------------------------------------------------------------------- | ---------------------------------------------- |
| `chat.postMessage`   | `CertGameSessionService`, `CertGameDuelService`, `CertGameNudgeScheduler`, finale callbacks. | Question / explanation / finale / nudge cards. |
| `chat.postEphemeral` | `CertGameSlackRenderService` error envelopes.                                                | Errors only visible to the invoking user.      |
| `views.open`         | `CertGameStudyPlanService.openPlanModal`, `CertGameBillingService.openBillingModal`.         | Open a modal in response to a `trigger_id`.    |
| `views.publish`      | `CertGameAppHomeService.publishHome`.                                                        | Render the App Home tab.                       |
| `users.info`         | `CertGameTenantService.getOrCreatePlayer`.                                                   | Fetch display name to populate `Player__c`.    |

### Outbound example

```apex
HttpRequest req = new HttpRequest();
req.setEndpoint('callout:Slack_Bot/chat.postMessage');
req.setMethod('POST');
req.setHeader('Content-Type', 'application/json; charset=utf-8');
req.setBody(JSON.serialize(new Map<String,Object>{
    'channel' => channelId,
    'blocks'  => blocks
}));
HttpResponse resp = new Http().send(req);
```

The bot token is bound to the Named Credential principal — Apex never sees it.

## Block Kit conventions

All Block Kit JSON is built inside `CertGameSlackRenderService`. Convention:

- One factory method per surface (e.g. `questionCard`, `duelFinaleBlocks`).
- All user-facing strings sourced from `CertGameStrings`.
- Every interactive element has an `action_id` of `domain:verb:resourceId`.

Common surfaces:

| Surface          | Method                                                         |
| ---------------- | -------------------------------------------------------------- |
| Help             | `help()`                                                       |
| Plain text reply | `text(String message, Boolean ephemeral)`                      |
| Question card    | `questionCard(session, round, question, choices)`              |
| Explanation card | `explanationCard(answer, question, choice, points)`            |
| Finale card      | `finaleCard(session, players)`                                 |
| Debug log card   | `debugLogBlocks(List<App_Log__c>)`                             |
| Error envelope   | `errorEnvelope(String sub, String correlationId, Exception e)` |
| Duel challenge   | `duelChallengeBlocks(...)`                                     |
| Duel started     | `duelStartedBlocks(...)`                                       |
| Duel declined    | `duelDeclinedBlocks(...)`                                      |
| Duel finale      | `duelFinaleBlocks(...)`                                        |

## Slash command grammar

| Subcommand           | Form                               |
| -------------------- | ---------------------------------- |
| `help`               | `/certgame help`                   |
| `play`               | `/certgame play [CODE]`            |
| `challenge` / `duel` | `/certgame challenge @user [CODE]` |
| `games`              | `/certgame games`                  |
| `leaderboard`        | `/certgame leaderboard [CODE]`     |
| `stats`              | `/certgame stats`                  |
| `plan`               | `/certgame plan`                   |
| `billing`            | `/certgame billing`                |
| `debug`              | `/certgame debug`                  |
| `doctor`             | `/certgame doctor`                 |
| `notify-test`        | `/certgame notify-test`            |

Full reference: [Slash Commands](../slack/commands.md).

## Scopes

The OAuth bot scopes the manifest requests are listed in
[Permissions & Scopes](../slack/permissions.md).

## Manifest

The single source of truth is
[slack-app-manifest.yaml](https://github.com/sfboss/slack_certification_salesforce_trivia/blob/main/slack-app-manifest.yaml).
The three `request_url` values **must** all be the same Salesforce Site endpoint.
