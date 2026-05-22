# AGENTS.md — DevOps / GitHub Actions Authoring Guide

## Mission
You are an automation agent responsible for authoring and maintaining the GitHub Actions workflows that **build, validate, and deploy** this Salesforce DX (SFDX) project. Every workflow you produce MUST surface its status, deployment details, and failures back into Slack using the project's existing Slack posting capabilities. DevOps without visibility is a non-goal — Slack notifications are a first-class deliverable, not an afterthought.

## Repository Context
- This is a Salesforce DX project (see `sfdx-project.json`, `force-app/`, `config/project-scratch-def.json`).
- The project already contains Slack posting logic (Apex / utility classes referenced elsewhere in the repo). Reuse that capability conceptually for runtime notifications, and use Slack webhook/API for CI-time notifications from GitHub Actions runners.
- Salesforce CLI: prefer the modern `sf` CLI (`@salesforce/cli`) over legacy `sfdx`. Authenticate using **SFDX Auth URLs** via `sf org login sfdx-url`.

## Required Secrets / Env Vars
Workflows MUST read these from the repository / environment secrets (never hardcode):

| Secret | Purpose | Required |
| --- | --- | --- |
| `SFDX_AUTH_URL` | Auth URL for the **Dev Hub** org. Used to create / delete scratch orgs. | ✅ Always |
| `SFDX_AUTH_URL_SCRATCH` | Optional pre-provisioned scratch / sandbox / target org auth URL. If present, skip scratch creation and deploy directly to it. | ⚠️ Optional but smart-detected |
| `SLACK_WEBHOOK_URL` | Incoming webhook used by CI to post build & deploy status to Slack. | ✅ Always |
| `SLACK_BOT_TOKEN` | Optional, only if richer Slack Web API posts (threading, file uploads) are needed. | ⚠️ Optional |
| `SLACK_CHANNEL_ID` | Target channel for status messages when using bot token. | ⚠️ Optional |

The agent MUST write workflows that:
1. Fail fast with a clear Slack message if `SFDX_AUTH_URL` or `SLACK_WEBHOOK_URL` is missing.
2. Detect presence of `SFDX_AUTH_URL_SCRATCH` and branch logic accordingly (see Decision Matrix).

## Decision Matrix — Scratch Org Lifecycle

| Trigger | `SFDX_AUTH_URL_SCRATCH` set? | Behavior |
| --- | --- | --- |
| PR / push (build validation only) | No | Auth Dev Hub → create scratch org → deploy source → run tests → **DELETE scratch org** (limit: 2 active per Dev Hub). |
| PR / push (build validation only) | Yes | Auth Dev Hub + target → deploy/validate against existing org → **do NOT delete**. |
| Release / `main` deploy | No | Auth Dev Hub → create scratch org → deploy → run tests → keep until job end, then delete (unless promoted). |
| Release / `main` deploy | Yes | Auth Dev Hub + target → deploy source → run tests → keep org. |

**Hard rule:** any workflow that *creates* a scratch org MUST register a cleanup step that runs `if: always()` to delete it, unless the workflow's explicit purpose is to provision a long-lived org. This protects the 2-active-scratch-org Dev Hub limit.

## Workflows to Produce

Create these files under `.github/workflows/`:

### 1. `validate-build.yml`
- Trigger: `pull_request`, `push` to non-`main` branches, and `workflow_dispatch`.
- Steps:
  1. Checkout.
  2. Setup Node (LTS) + install `@salesforce/cli`.
  3. Post Slack message: "🟡 Build validation started for `<sha>` on `<branch>` by `<actor>`".
  4. Auth Dev Hub from `SFDX_AUTH_URL`.
  5. If `SFDX_AUTH_URL_SCRATCH` exists → auth that org as `targetOrg`. Else → `sf org create scratch -f config/project-scratch-def.json -a targetOrg -d -y 1`.
  6. `sf project deploy start -o targetOrg` (validate / deploy).
  7. `sf apex run test -o targetOrg -l RunLocalTests -w 30 -r human` (and `-r json` to a file for parsing).
  8. Post Slack message with: ✅/❌ status, duration, test pass/fail counts, code coverage %, deploy ID, link to GitHub Actions run.
  9. Cleanup step (`if: always()`): if scratch org was created in step 5, run `sf org delete scratch -o targetOrg -p`. Post Slack message confirming cleanup (or warning if cleanup failed).

### 2. `deploy.yml`
- Trigger: `push` to `main`, `release: [published]`, and `workflow_dispatch` (with input for target org alias).
- Steps mirror `validate-build.yml`, except:
  - Use `sf project deploy start` (not validate-only) against the target.
  - Do NOT delete the target org on success when `SFDX_AUTH_URL_SCRATCH` is provided.
  - Post a richer Slack message (Block Kit) including: commit message, author, files changed count, deploy ID, test results, environment name, and a link to the run.
  - On failure, post Slack message with the last ~50 lines of deploy log in a code block (or upload log as a Gist / artifact and link it).

### 3. `scratch-cleanup.yml` (safety net)
- Trigger: `schedule` (daily) + `workflow_dispatch`.
- Auth Dev Hub, list scratch orgs (`sf org list --all --json`), delete any tagged with `ci-ephemeral-*` older than 24h.
- Post Slack summary of what was reaped.

## Slack Notification Standards

Every workflow MUST notify Slack at minimum:
- **Start** — yellow / 🟡, with trigger metadata.
- **Success** — green / ✅, with deploy ID, test results, coverage, duration, run URL.
- **Failure** — red / ❌, with failing step, error summary, run URL.
- **Cleanup** — neutral / 🧹, confirming scratch org deletion (only when applicable).

Use `curl` against `SLACK_WEBHOOK_URL` with Block Kit JSON payloads. Centralize the payload construction in a reusable composite action or shell script under `.github/actions/slack-notify/` so message formatting stays DRY across the three workflows.

Required fields in every Slack post:
- Repo + branch + commit SHA (short) + commit message (first line).
- Actor (`github.actor`).
- Workflow name + job + run URL (`${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}`).
- Status emoji + human-readable status.
- For deploys: deploy ID, target org alias / username, test pass/fail/coverage.

## Implementation Guidelines

- Use `actions/checkout@v4`, `actions/setup-node@v4` (Node 20).
- Install CLI via `npm i -g @salesforce/cli` and verify with `sf --version`.
- Auth pattern:
  ```bash
  echo "$SFDX_AUTH_URL" > ./DEVHUB_AUTH.txt
  sf org login sfdx-url -f ./DEVHUB_AUTH.txt -a devhub -d
  rm -f ./DEVHUB_AUTH.txt
  ```
- Always `set -euo pipefail` in shell steps.
- Mask secrets; never `echo` auth URLs.
- Use job outputs to pass `scratchCreated=true|false` between steps so cleanup logic is deterministic.
- Prefer composite actions over duplicated YAML.
- Tag created scratch orgs with alias `ci-ephemeral-${{ github.run_id }}` for traceability and for the scheduled cleanup workflow.
- Concurrency: add `concurrency: { group: deploy-${{ github.ref }}, cancel-in-progress: false }` to `deploy.yml` to prevent overlapping deploys.

## Acceptance Criteria
A workflow is "done" only when ALL are true:
- [ ] Reads `SFDX_AUTH_URL` (Dev Hub) and optionally `SFDX_AUTH_URL_SCRATCH` from secrets.
- [ ] Smart-detects whether to create a scratch org or use the provided one.
- [ ] Deletes any scratch org it created, even on failure (`if: always()`).
- [ ] Posts Slack messages on start, success, failure, and (when applicable) cleanup.
- [ ] Includes deploy ID, test results, coverage, and a link to the GitHub Actions run in the Slack message.
- [ ] Respects the 2-active-scratch-org Dev Hub limit (no leaks).
- [ ] Secrets never appear in logs.
- [ ] Lints cleanly (`actionlint`) and the YAML is valid.

## Out of Scope
- Do not modify Apex source to add CI hooks; CI Slack notifications come from the runner, not from Apex.
- Do not introduce third-party deploy tools (Copado, Gearset, etc.).
- Do not commit any auth URL, token, or org credential to the repo.
