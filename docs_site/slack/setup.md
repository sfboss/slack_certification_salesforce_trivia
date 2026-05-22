# Slack App Setup

The detailed canonical guide is at
[docs/slack-app-setup.md](https://github.com/sfboss/slack_certification_salesforce_trivia/blob/main/docs/slack-app-setup.md).
This page is the operational summary.

## 1. Create the app from the manifest

1. Open <https://api.slack.com/apps> → **Create New App** → **From an app manifest**.
2. Select your workspace.
3. Paste the contents of
   [slack-app-manifest.yaml](https://github.com/sfboss/slack_certification_salesforce_trivia/blob/main/slack-app-manifest.yaml).
4. Replace each `request_url` with your Salesforce Site URL +
   `/services/apexrest/slack/events`.
5. Create.

!!! tip "Same URL three times"
    The slash command, Interactivity, and Event subscription URLs **must** all point at the
    same Salesforce endpoint. Mismatched URLs are the #1 cause of "buttons don't do
    anything."

## 2. Install to workspace

In the app config screen:

1. **Install App** → install → authorize.
2. Copy the **Bot User OAuth Token** (`xoxb-…`).
3. Under **Basic Information**, copy the **Signing Secret**.

## 3. Bind secrets in Salesforce

Two places need the secrets — see [Authentication](../salesforce/authentication.md) for
field-by-field guidance.

| Where | Field | Value |
| --- | --- | --- |
| External Credential `Slack_Bot` | Principal header `Authorization` | `Bearer xoxb-…` |
| `App_Setting__mdt.Default` | `Slack_Signing_Secret__c` | Signing secret |
| `App_Setting__mdt.Default` | `Slack_Verification_Token__c` *(optional)* | Slack legacy verification token (used as a fallback for form-encoded slash commands) |

## 4. Confirm the URL verification handshake

When you first set the request URL, Slack POSTs a `url_verification` payload. The router
short-circuits this before signature verification (signing secret may not be configured
yet) and echoes the `challenge` back. You should see a green check next to each URL.

Manual test:

```bash
curl -i -X POST 'https://<your-site>.my.salesforce-sites.com/services/apexrest/slack/events' \
  -H 'Content-Type: application/json' \
  -d '{"type":"url_verification","challenge":"hello123"}'
```

Expected: `200` with body `hello123`.

## 5. App Home tab

The manifest enables the Home tab. The first time a user opens the app DM, the
`app_home_opened` event is dispatched to
[`SlackCertGameEventHandler`](../api-reference/apex.md#slackcertgameeventhandler), which
calls `CertGameAppHomeService` → `views.publish`.

## 6. Smoke test

```text
/certgame help
```

You should see the help block. If you see a "dispatch_failed" Slack error, check
[Troubleshooting](../user-guide/troubleshooting.md).

## 7. Optional Slack notifications for CI

A separate one-way webhook drives GitHub Actions → Slack notifications. Setup in
[docs/slack-webhook-quick-setup.md](https://github.com/sfboss/slack_certification_salesforce_trivia/blob/main/docs/slack-webhook-quick-setup.md).
This is independent of the Cert Game app.
