# GitHub Actions Workflows

This repository uses GitHub Actions for automated CI/CD with Slack notifications.

## Workflows Overview

### 1. CI - Build and Test (`ci.yml`)

**Triggers:**

- Push to `main` or `develop` branches
- Pull requests to `main` or `develop` branches

**What it does:**

1. Checks out code
2. Sets up Node.js and Salesforce CLI
3. Runs ESLint on Lightning Web Components
4. Runs LWC unit tests
5. Creates a scratch org (if `SFDX_AUTH_URL` is configured)
6. Deploys code to scratch org
7. Runs Apex tests
8. Sends Slack notification on success or failure

**Required Secrets:**

- `SLACK_WEBHOOK_URL` (optional but recommended)
- `SFDX_AUTH_URL` (optional, enables scratch org creation)

**Slack Notifications:**

- ✅ Success: Green header with commit details and link to workflow
- ❌ Failure: Red header with error details and link to workflow

---

### 2. Deploy to Scratch Org (`deploy-scratch-org.yml`)

**Triggers:**

- Manual workflow dispatch (Actions tab → Run workflow)

**Input Parameters:**

- `org_alias`: Name for the scratch org (default: `certgame`)
- `duration`: Org lifetime in days (default: `30`)

**What it does:**

1. Checks out code
2. Authenticates with Dev Hub
3. Creates a new scratch org
4. Deploys all source code
5. Assigns permission set group
6. Sends Slack notification with org details

**Required Secrets:**

- `SFDX_AUTH_URL` (required)
- `SLACK_WEBHOOK_URL` (optional but recommended)

**Slack Notifications:**

- 🚀 Success: Deployment details with org alias and duration
- ❌ Failure: Error notification with link to logs

---

### 3. PR Notifications (`pr-notifications.yml`)

**Triggers:**

- Pull request opened
- Pull request reopened
- Pull request closed (merged or not merged)
- Pull request marked as ready for review

**What it does:**

- Sends formatted Slack messages for PR lifecycle events

**Required Secrets:**

- `SLACK_WEBHOOK_URL` (required for this workflow)

**Slack Notifications:**

- 🔔 PR Opened/Reopened: Shows title, author, branches, and description
- ✅ PR Merged: Shows title, author, merger, and branches
- 🚫 PR Closed: Shows title and author when closed without merging

---

## Setup Instructions

### 1. Configure Slack Webhook

See [slack-webhook-quick-setup.md](./slack-webhook-quick-setup.md) for a 5-minute setup guide.

### 2. Add Repository Secrets

Navigate to: `Settings → Secrets and variables → Actions`

Add the following secrets:

#### `SLACK_WEBHOOK_URL` (Recommended)

- **Purpose**: Enables Slack notifications for all workflows
- **Format**: `https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXX`
- **How to get**: [Create a Slack Incoming Webhook](./slack-notifications-setup.md#step-1-create-a-slack-incoming-webhook)

#### `SFDX_AUTH_URL` (Optional)

- **Purpose**: Enables scratch org creation and Apex testing in CI
- **Format**: `force://...` (output from `sf org display --verbose --json`)
- **How to get**:
    ```bash
    sf org login web --alias devhub --set-default-dev-hub
    sf org display --verbose --json --target-org devhub | grep sfdxAuthUrl
    ```

---

## Workflow Status Badges

Add status badges to your README:

### CI Status

```markdown
![CI](https://github.com/sfboss/slack_certification_salesforce_trivia/actions/workflows/ci.yml/badge.svg)
```

### Deployment Status

```markdown
![Deploy](https://github.com/sfboss/slack_certification_salesforce_trivia/actions/workflows/deploy-scratch-org.yml/badge.svg)
```

---

## Manual Workflow Execution

### Deploy to Scratch Org

1. Go to **Actions** tab
2. Select **Deploy to Scratch Org** workflow
3. Click **Run workflow**
4. Enter parameters:
    - Org alias (e.g., `feature-test`)
    - Duration in days (e.g., `7`)
5. Click **Run workflow** button

---

## Customizing Workflows

### Modifying CI Behavior

Edit `.github/workflows/ci.yml`:

**Change test commands:**

```yaml
- name: Run ESLint
  run: npm run lint:lwc
```

**Add additional steps:**

```yaml
- name: Run Apex PMD
  run: sf scanner run --target "force-app" --format table
```

**Change trigger branches:**

```yaml
on:
    push:
        branches: [main, develop, staging] # Add more branches
```

### Modifying Slack Messages

Edit the `payload` section in any workflow:

```yaml
- name: Notify Slack
  uses: slackapi/slack-github-action@v1.27.0
  with:
      payload: |
          {
            "text": "Your custom message",
            "blocks": [
              {
                "type": "section",
                "text": {
                  "type": "mrkdwn",
                  "text": "Your *formatted* message"
                }
              }
            ]
          }
```

Use the [Slack Block Kit Builder](https://app.slack.com/block-kit-builder) to design messages.

---

## Troubleshooting

### Workflows Not Running

1. Check that workflow files are in `.github/workflows/`
2. Verify YAML syntax (use a validator)
3. Check branch names in triggers match your branches
4. Ensure GitHub Actions are enabled: `Settings → Actions → General`

### Slack Notifications Not Appearing

1. Verify `SLACK_WEBHOOK_URL` secret is set correctly
2. Test webhook manually:
    ```bash
    curl -X POST -H 'Content-type: application/json' \
      --data '{"text":"Test from CLI"}' \
      YOUR_WEBHOOK_URL
    ```
3. Check workflow logs for Slack step errors
4. Verify webhook app has permission to post to the channel

### Scratch Org Creation Fails

1. Verify `SFDX_AUTH_URL` secret is set
2. Ensure Dev Hub is enabled in your Salesforce org
3. Check scratch org allocation limits
4. Review workflow logs for specific error messages

### Permission Errors

If you see "No permission to create scratch orgs":

1. Verify your Dev Hub user has the proper permissions
2. Ensure the auth URL is for a Dev Hub org, not a regular org
3. Try re-authenticating and regenerating the auth URL

---

## Security Best Practices

1. **Never commit secrets** to the repository
2. **Rotate webhook URLs** if exposed or annually
3. **Use environment protection rules** for production deployments
4. **Limit secret access** to necessary workflows only
5. **Review workflow changes** in PRs carefully
6. **Enable required reviews** for workflow file changes

---

## Monitoring and Logs

### View Workflow Runs

- Go to **Actions** tab in GitHub
- Click on any workflow run to see details
- Expand steps to see logs

### Slack Channel

- All notifications appear in your configured Slack channel
- Each notification includes a link to the workflow run

### Failed Workflows

- GitHub sends email notifications for failures (if enabled)
- Slack sends red notifications with error context
- Workflow logs contain detailed error messages

---

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Salesforce CLI Documentation](https://developer.salesforce.com/docs/atlas.en-us.sfdx_cli_reference.meta/sfdx_cli_reference/)
- [Slack Incoming Webhooks](https://api.slack.com/messaging/webhooks)
- [Slack Block Kit](https://api.slack.com/block-kit)
- [YAML Validator](https://www.yamllint.com/)

---

## Support

For issues or questions:

- **GitHub Actions**: Check workflow logs in Actions tab
- **Slack Integration**: Review Slack app settings
- **Salesforce CLI**: Run commands locally to debug
- **Repository Issues**: Open an issue on GitHub
