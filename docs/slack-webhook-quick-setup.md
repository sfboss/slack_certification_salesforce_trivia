# Quick Setup Guide - Slack Webhook URL

## TL;DR - 5 Minute Setup

### 1. Create Slack Webhook (2 minutes)

```
1. Go to: https://api.slack.com/apps
2. Click "Create New App" → "From scratch"
3. Name it "GitHub Actions" → Select your workspace
4. Click "Incoming Webhooks" → Toggle ON
5. Click "Add New Webhook to Workspace"
6. Select channel (e.g., #github-notifications)
7. Copy the webhook URL
```

### 2. Add to GitHub Secrets (1 minute)

```
1. Go to: https://github.com/sfboss/slack_certification_salesforce_trivia/settings/secrets/actions
2. Click "New repository secret"
3. Name: SLACK_WEBHOOK_URL
4. Value: [paste your webhook URL]
5. Click "Add secret"
```

### 3. Test (2 minutes)

```bash
# Push a commit to trigger CI
git add .
git commit -m "test: slack notifications"
git push origin main

# Check your Slack channel for the notification!
```

## Your Webhook URL Format

Your webhook URL should look like this:

```
https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXX
```

## What You Get

✅ **CI Build notifications** - Success/failure on every push to main/develop
✅ **PR notifications** - When PRs are opened, merged, or closed
✅ **Deployment notifications** - When scratch orgs are deployed
✅ **Rich formatting** - Beautiful Block Kit messages with buttons

## Need Help?

See full documentation: [docs/slack-notifications-setup.md](./slack-notifications-setup.md)
