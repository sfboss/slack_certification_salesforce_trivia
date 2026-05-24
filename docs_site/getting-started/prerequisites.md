# Prerequisites

## Tooling

| Tool                                                                          | Minimum version | Used for                                            |
| ----------------------------------------------------------------------------- | --------------- | --------------------------------------------------- |
| [Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli) (`sf`) | 2.0+            | Scratch org create, deploy, test                    |
| Node.js                                                                       | 20+             | LWC + Jest tests (`jest.config.js`)                 |
| Python                                                                        | 3.11+           | JSON validators and import scripts under `scripts/` |
| Git                                                                           | recent          | source control                                      |

Verify:

```bash
sf --version
node --version
python3 --version
git --version
```

## Salesforce accounts

- A **Dev Hub** org (Production org with Dev Hub enabled, or a trial).
- Authenticate the CLI to it:

```bash
sf org login web -a devhub --set-default-dev-hub
```

## Slack workspace

- A Slack workspace where you can create and install apps (workspace admin or an admin who
  can pre-approve apps for you).
- Ability to reach `api.slack.com/apps` from your browser.

## Optional integrations

These are gated by feature flags in `App_Setting__mdt`; you do **not** need them to play
games or run the import pipeline.

- **OpenAI / Gemini / Claude** API key — only required if you want to use
  [dynamic question generation](../user-guide/workflows.md#generate-questions).
- **Stripe** account + signing secret — only required if you turn on billing
  (`Feature_Flag_Billing__c = true`).

## Python virtual environment

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r scripts/requirements.txt
```

`scripts/requirements.txt` pins `jsonschema`, `requests`, `simple-salesforce`, and
`python-dotenv`.

## VS Code

Recommended extensions:

- Salesforce Extension Pack
- Apex PMD
- ESLint
- Prettier with `prettier-plugin-apex`

The repo includes [eslint.config.js](https://github.com/sfboss/slack_certification_salesforce_trivia/blob/main/eslint.config.js)
and [pmd-ruleset.xml](https://github.com/sfboss/slack_certification_salesforce_trivia/blob/main/pmd-ruleset.xml).
