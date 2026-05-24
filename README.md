# Slack Certification Salesforce Trivia

A Salesforce-powered Slack app for certification exam trivia and study management.

## Quick Start

### GitHub Actions & Slack Notifications

This repository includes automated CI/CD workflows with Slack notifications. To enable:

1. **Set up Slack Webhook** (5 minutes) - [Quick Setup Guide](docs/slack-webhook-quick-setup.md)
2. **Add GitHub Secret**: `SLACK_WEBHOOK_URL` - [Full Documentation](docs/slack-notifications-setup.md)

You'll get automatic notifications for:

- CI builds (success/failure)
- Pull requests (opened/merged/closed)
- Scratch org deployments

## How Do You Plan to Deploy Your Changes?

Do you want to deploy a set of changes, or create a self-contained application? Choose a [development model](https://developer.salesforce.com/tools/vscode/en/user-guide/development-models).

## Configure Your Salesforce DX Project

The `sfdx-project.json` file contains useful configuration information for your project. See [Salesforce DX Project Configuration](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_dev_ws_config.htm) in the _Salesforce DX Developer Guide_ for details about this file.

## Read All About It

- [Salesforce Extensions Documentation](https://developer.salesforce.com/tools/vscode/)
- [Salesforce CLI Setup Guide](https://developer.salesforce.com/docs/atlas.en-us.sfdx_setup.meta/sfdx_setup/sfdx_setup_intro.htm)
- [Salesforce DX Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_dev_intro.htm)
- [Salesforce CLI Command Reference](https://developer.salesforce.com/docs/atlas.en-us.sfdx_cli_reference.meta/sfdx_cli_reference/cli_reference.htm)
