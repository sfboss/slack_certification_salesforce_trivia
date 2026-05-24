# Slack App Setup

This guide walks through setting up the Slack App that pairs with the `CertGameSlackManager` Salesforce package.

## 1. Create the Slack App

1. Visit https://api.slack.com/apps → **Create New App** → **From scratch**.
2. App name: `Cert Game`. Pick the target workspace for development.

## 2. Configure OAuth & Permissions

Add the following **Bot Token Scopes**:

- `app_mentions:read`
- `channels:read`
- `chat:write`
- `chat:write.public`
- `commands`
- `groups:read`
- `im:history`
- `im:read`
- `im:write`
- `team:read`
- `users:read`
- `users:read.email` _(optional, for player profile enrichment)_

## 3. Slash Commands

Create the slash command `/certgame` and point the request URL at the Salesforce REST endpoint:

```
https://<my-domain>.my.salesforce-sites.com/services/apexrest/slack/events
```

Short description: `Run Salesforce certification trivia`.

## 4. Interactivity & Shortcuts

- Enable **Interactivity**.
- Request URL: same `/services/apexrest/slack/events` endpoint.

## 5. Event Subscriptions

- Enable events.
- Request URL: same as above (responds to `url_verification` challenge automatically).
- Subscribe to bot events:
    - `app_home_opened`
    - `app_uninstalled`
    - `tokens_revoked`

## 6. App Home

- Enable the **Home tab**.
- (Optional) Enable Messages Tab.

## 7. Install to Workspace

Install the app and grab the **Bot User OAuth Token** (`xoxb-…`) and **Signing Secret**.

## 8. Configure Named Credentials in Salesforce

After deploying the package:

1. **Setup → Security → Named Credentials → External Credentials**: create one per Named Credential below, attach to a Permission Set Group, and store the secret in the **Principal**.
    - `Slack_Bot` → Custom Header `Authorization: Bearer <xoxb token>`
    - `Slack_Signing` → Custom Header `X-Slack-Signing-Secret: <signing secret>` (only used by `SlackSignatureVerifier`; the secret may also live in `App_Setting__mdt` for tests).
    - `OpenAI` → Custom Header `Authorization: Bearer <sk-…>`
    - `Stripe` → Custom Header `Authorization: Bearer <sk_live_…>`
2. Update `App_Setting__mdt.Default` with the Named Credential developer names if they differ from defaults.

## 9. Smoke Test

Run `/certgame help` from any channel after install. You should see the help block.

curl -i -X POST 'https://dream-dream-110-dev-ed.scratch.my.salesforce-sites.com/certgame' \
 -H 'Content-Type: application/json' \
 -d '{"type":"url_verification","challenge":"hello123"}'
