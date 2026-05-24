# Deployment

## Targets

| Target                           | When      | Command                                                                         |
| -------------------------------- | --------- | ------------------------------------------------------------------------------- |
| **Scratch org**                  | Local dev | `sf org create scratch -f config/project-scratch-def.json -a certgame -d -y 30` |
| **Sandbox**                      | Pre-prod  | `sf project deploy start -o <sandbox> --ignore-conflicts`                       |
| **Production (managed package)** | Customers | Install the published 2GP managed package URL.                                  |

## Source deploy

Full deploy:

```bash
sf project deploy start -o certgame --ignore-conflicts
```

Targeted deploy of a single class:

```bash
sf project deploy start -o certgame \
  -d force-app/main/default/classes/SlackCertGameInteractionHandler.cls \
  --ignore-conflicts
```

Validation-only (no commit):

```bash
sf project deploy validate -o certgame --test-level RunLocalTests --wait 30
```

## 2GP packaging

`sfdx-project.json` defines the package alias `CertGameSlackManager` at `0.1.0.NEXT`.

Create a beta version from your Dev Hub:

```bash
sf package version create \
  --package CertGameSlackManager \
  --installation-key-bypass \
  --code-coverage \
  --wait 20 \
  --target-dev-hub devhub
```

Promote to released:

```bash
sf package version promote --package <subscriberPackageVersionId>
```

## Install in a customer org

```bash
sf package install \
  --package <04t...> \
  --target-org <customerOrg> \
  --wait 20
```

Then in the target org:

1. Assign `Cert_Game_All_Admin` Permission Set Group.
2. Bind secrets in each Named Credential.
3. Set `Slack_Signing_Secret__c` in `App_Setting__mdt.Default`.

## CI

GitHub Actions workflows are documented in
[docs/github-actions-workflows.md](https://github.com/sfboss/slack_certification_salesforce_trivia/blob/main/docs/github-actions-workflows.md).
Slack notifications are wired via `SLACK_WEBHOOK_URL` secret — see
[docs/slack-webhook-quick-setup.md](https://github.com/sfboss/slack_certification_salesforce_trivia/blob/main/docs/slack-webhook-quick-setup.md).

## Post-deploy verification

```bash
sf apex run test -o certgame -r human -w 20 --code-coverage
sf scanner run --target force-app --severity-threshold 2
```

Both must come back clean before a phase is considered done — see
[AGENTS.md §6](https://github.com/sfboss/slack_certification_salesforce_trivia/blob/main/AGENTS.md).
