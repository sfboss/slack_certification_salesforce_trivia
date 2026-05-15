# GitHub Actions Slack Notifications Setup

This document explains how to set up Slack notifications for GitHub Actions workflows in the Slack Certification Trivia repository.

## Overview

The repository includes three GitHub Actions workflows with Slack notifications:

1. **CI - Build and Test** (`ci.yml`) - Runs on push/PR to main/develop branches
2. **Deploy to Scratch Org** (`deploy-scratch-org.yml`) - Manual deployment workflow
3. **PR Notifications** (`pr-notifications.yml`) - Notifies on PR events

## Prerequisites

- Admin access to your Slack workspace
- Admin access to the GitHub repository
- A Slack channel where you want to receive notifications

## Step 1: Create a Slack Incoming Webhook

### Option A: Using Slack Workflow Builder (Recommended)

1. Open your Slack workspace in a web browser
2. Go to your Slack workspace settings: `https://[your-workspace].slack.com/admin`
3. Navigate to **Manage Apps** or go directly to `https://api.slack.com/apps`
4. Click **Create New App**
5. Select **From scratch**
6. Enter app details:
   - **App Name**: `GitHub Actions Notifications` (or your preferred name)
   - **Pick a workspace**: Select your workspace
   - Click **Create App**

7. In the left sidebar, click **Incoming Webhooks**
8. Toggle **Activate Incoming Webhooks** to **On**
9. Click **Add New Webhook to Workspace**
10. Select the channel where you want notifications (e.g., `#deployments`, `#github-notifications`)
11. Click **Allow**

12. Copy the **Webhook URL** - it will look like:
   ```
   https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXX
   ```

### Option B: Using Legacy Incoming Webhooks App

1. Go to `https://[your-workspace].slack.com/apps/A0F7XDUAZ-incoming-webhooks`
2. Click **Add to Slack**
3. Select a channel for notifications
4. Click **Add Incoming WebHooks integration**
5. Copy the **Webhook URL**

## Step 2: Add the Webhook URL as a GitHub Repository Secret

1. Navigate to your GitHub repository: `https://github.com/sfboss/slack_certification_salesforce_trivia`

2. Click on **Settings** tab

3. In the left sidebar, click **Secrets and variables** → **Actions**

4. Click **New repository secret**

5. Enter the secret details:
   - **Name**: `SLACK_WEBHOOK_URL`
   - **Secret**: Paste the webhook URL you copied from Slack
   - Click **Add secret**

## Step 3: (Optional) Add Salesforce Dev Hub Authentication

For the CI workflow to create scratch orgs and run Apex tests, you need to add your Dev Hub authentication URL:

1. Authenticate with your Dev Hub org locally:
   ```bash
   sf org login web --alias devhub --set-default-dev-hub
   ```

2. Generate the SFDX Auth URL:
   ```bash
   sf org display --verbose --json --target-org devhub
   ```

   Look for the `sfdxAuthUrl` in the output.

3. Add it as a GitHub secret:
   - **Name**: `SFDX_AUTH_URL`
   - **Secret**: The `sfdxAuthUrl` value

## Step 4: Test the Setup

### Test CI Workflow

1. Make a small change to any file in the repository
2. Commit and push to the `main` or `develop` branch:
   ```bash
   git add .
   git commit -m "test: verify Slack notifications"
   git push origin main
   ```
3. Check your Slack channel for the build notification

### Test PR Notifications

1. Create a new branch:
   ```bash
   git checkout -b test/slack-notifications
   ```
2. Make a small change and push:
   ```bash
   git add .
   git commit -m "test: PR notification"
   git push origin test/slack-notifications
   ```
3. Create a pull request on GitHub
4. Check your Slack channel for the PR notification

### Test Deployment Workflow

1. Go to **Actions** tab in your GitHub repository
2. Select **Deploy to Scratch Org** workflow
3. Click **Run workflow**
4. Fill in the parameters and run
5. Check your Slack channel for deployment notifications

## Notification Examples

### Success Notification
When a build succeeds, you'll receive:
- ✅ Green header with "CI Build Successful"
- Repository, branch, commit, and author information
- Commit message
- Button to view the workflow run

### Failure Notification
When a build fails, you'll receive:
- ❌ Red header with "CI Build Failed"
- Repository, branch, commit, and author information
- Warning message
- Button to view the failed workflow run

### PR Notifications
- 🔔 New PR opened/reopened
- ✅ PR merged
- 🚫 PR closed without merging

## Troubleshooting

### Notifications Not Appearing

1. **Check the secret name**: Ensure it's exactly `SLACK_WEBHOOK_URL` (case-sensitive)
2. **Verify webhook URL**: Test the webhook manually:
   ```bash
   curl -X POST -H 'Content-type: application/json' \
     --data '{"text":"Hello from GitHub Actions!"}' \
     YOUR_WEBHOOK_URL
   ```
3. **Check workflow logs**: Look for Slack notification steps in the Actions tab
4. **Verify channel permissions**: Ensure the Slack app has permission to post to the channel

### Workflows Not Running

1. **Check branch names**: CI workflow runs on `main` and `develop` branches
2. **Check file paths**: Ensure workflow files are in `.github/workflows/`
3. **Verify YAML syntax**: Use a YAML validator to check for syntax errors

### Scratch Org Creation Fails

1. **Check SFDX_AUTH_URL**: Ensure the secret is set correctly
2. **Verify Dev Hub**: Make sure Dev Hub is enabled in your Salesforce org
3. **Check quota**: Ensure you haven't exceeded scratch org limits

## Customization

### Changing Notification Channel

To change which Slack channel receives notifications:

1. Go to your Slack app settings: `https://api.slack.com/apps`
2. Select your GitHub Actions app
3. Click **Incoming Webhooks**
4. Delete the old webhook
5. Add a new webhook to the desired channel
6. Update the `SLACK_WEBHOOK_URL` secret in GitHub

### Customizing Messages

Edit the workflow files in `.github/workflows/` to customize:
- Message content
- Block Kit formatting
- Which events trigger notifications
- Additional context/fields

### Adding More Workflows

Create new workflow files in `.github/workflows/` and include the Slack notification steps:

```yaml
- name: Notify Slack
  if: secrets.SLACK_WEBHOOK_URL != ''
  uses: slackapi/slack-github-action@v1.27.0
  with:
    payload: |
      {
        "text": "Your notification message",
        "blocks": [
          {
            "type": "section",
            "text": {
              "type": "mrkdwn",
              "text": "Your formatted message here"
            }
          }
        ]
      }
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
    SLACK_WEBHOOK_TYPE: INCOMING_WEBHOOK
```

## Security Best Practices

1. **Never commit the webhook URL** to your repository
2. **Rotate webhooks regularly** if they may have been exposed
3. **Limit webhook permissions** to only the necessary channels
4. **Monitor webhook usage** in Slack app settings
5. **Use repository secrets** for all sensitive data

## Additional Resources

- [Slack Incoming Webhooks Documentation](https://api.slack.com/messaging/webhooks)
- [Slack Block Kit Builder](https://app.slack.com/block-kit-builder)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [GitHub Encrypted Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [Slack GitHub Action](https://github.com/slackapi/slack-github-action)

## Support

For issues or questions:
- GitHub Actions issues: Check the Actions tab for workflow logs
- Slack integration issues: Review Slack app settings and webhook logs
- Repository issues: Open an issue in the GitHub repository
