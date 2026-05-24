# Installation

End-to-end install of the package into a scratch org and the Slack app into a workspace.

## 1. Clone

```bash
git clone https://github.com/sfboss/slack_certification_salesforce_trivia.git
cd slack_certification_salesforce_trivia
```

## 2. Create a scratch org

The scratch config in [config/project-scratch-def.json](https://github.com/sfboss/slack_certification_salesforce_trivia/blob/main/config/project-scratch-def.json)
is intentionally minimal.

```bash
sf org create scratch \
  -f config/project-scratch-def.json \
  -a certgame -d -y 30
```

`-y 30` gives you a 30-day org. `-d` makes it your default.

## 3. Deploy source

```bash
sf project deploy start -o certgame --ignore-conflicts
```

Expected: ~210 components deploy. The first deploy takes ~3 minutes on a fresh scratch org.

## 4. Assign the permission set group

```bash
sf org assign permsetgroup -n Cert_Game_All_Admin -o certgame
```

`Cert_Game_All_Admin` is defined in
[force-app/main/default/permissionsetgroups](https://github.com/sfboss/slack_certification_salesforce_trivia/tree/main/force-app/main/default/permissionsetgroups)
and bundles every persona permission set
([see permissions](../salesforce/setup.md#permission-sets)).

## 5. Open the Cert Game Manager app

```bash
sf org open -o certgame -p /lightning/app/Cert_Game_Manager
```

The app definition lives at
[force-app/main/default/applications/Cert_Game_Manager.app-meta.xml](https://github.com/sfboss/slack_certification_salesforce_trivia/blob/main/force-app/main/default/applications/Cert_Game_Manager.app-meta.xml).

## 6. Run the test suite

```bash
sf apex run test -o certgame -r human -w 20 --code-coverage
```

Targets ([per AGENTS.md §0](https://github.com/sfboss/slack_certification_salesforce_trivia/blob/main/AGENTS.md)):

- Overall coverage ≥ 85%.
- `EntitlementGuard`, `SlackSignatureVerifier`, `CertGameScoringService`,
  `StripeWebhookHandler` ≥ 95%.

## 7. Install the Slack app

Use the manifest at
[slack-app-manifest.yaml](https://github.com/sfboss/slack_certification_salesforce_trivia/blob/main/slack-app-manifest.yaml):

1. Visit <https://api.slack.com/apps> → **Create New App** → **From an app manifest**.
2. Pick your target workspace.
3. Paste the YAML, replacing the three `request_url` values with **your** Salesforce Site
   URL plus `/services/apexrest/slack/events`.
4. **Install to Workspace**.
5. Copy the **Bot User OAuth Token** (`xoxb-…`) and the **Signing Secret**.

Full Slack-side walkthrough: [Slack setup](../slack/setup.md).

## 8. Wire the secrets in Salesforce

The package ships these Named Credentials (no-auth shells; secrets bound at install):

| Named Credential | Header                                                                                                                      |
| ---------------- | --------------------------------------------------------------------------------------------------------------------------- |
| `Slack_Bot`      | `Authorization: Bearer <xoxb-…>`                                                                                            |
| `Slack_Signing`  | stores the signing secret as a custom header (also mirrored to `App_Setting__mdt.Slack_Signing_Secret__c` for the verifier) |
| `OpenAI`         | `Authorization: Bearer <sk-…>`                                                                                              |
| `Stripe`         | `Authorization: Bearer <sk_live_…>`                                                                                         |

Setup:

1. **Setup → Security → Named Credentials → External Credentials** → open each → attach to
   `Cert_Game_All_Admin` Permission Set Group → store the secret in the Principal.
2. **Setup → Custom Metadata Types → App Setting → Manage → Default** → set
   `Slack_Signing_Secret__c` and any feature flags you want on.

Full secret reference: [Salesforce authentication](../salesforce/authentication.md).

## 9. Smoke test

In Slack:

```text
/certgame help
```

You should see the help block render. If you get "dispatch_failed" or no response, see
[Troubleshooting](../user-guide/troubleshooting.md).
