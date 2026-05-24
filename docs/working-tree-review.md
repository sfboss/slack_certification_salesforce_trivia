# Working-Tree Review — Gaps & Deploy Plan

Snapshot of every uncommitted change in the tree as of branch `main`, what's complete, what's missing, and what has to happen before this goes to an org.

---

## 1. What's actually in flight (five themes)

Group the 35-ish dirty paths so you're not staring at a flat list.

### A. Question-review workflow (the biggest cluster)

New two-step publish gate: **Needs Review → Fact Verified → Published**, with a "Needs Revision" off-ramp and reviewer notes.

Touches:

- `Trivia_Question__c/fields/Status__c.field-meta.xml` (M) — adds picklist values `Needs Review`, `Needs Revision`, `Fact Verified`.
- 6 **new** Trivia_Question**c fields: `Fact_Check_Passed**c`, `Fact_Checked_By**c`, `Fact_Checked_Date**c`, `Published_By**c`, `Published_Date**c`, `Reviewer_Notes\_\_c`.
- `QuestionReviewController.cls` (M, +349 lines) — DTOs renamed `DraftQuestionDto` → `ReviewQuestionDto`; new methods `markFactsVerified`, `clearFactsVerified`, `needsRevision`, `verifyCitation`; `publish` now requires `Fact_Check_Passed__c=true`.
- `QuestionReviewController_Test.cls` (M) — 14 `@IsTest` methods, covers the new flow including the publish-block.
- `CitationLinkVerifier.cls` + `_Test.cls` (new) — HEAD/GET reachability check; ~100% covered.
- `lwc/questionReviewConsole/` — `.html`, `.js`, **new** `.css` to drive the new actions.

### B. Readiness Report (new player-facing page)

A signed-token Visualforce page on the public `certgame` Site that renders a personalized readiness/diagnostic report. Linked from the Slack "Game Over" card via a "View full report" button.

Touches:

- **New** `CertGameReadinessReportController.cls` — VF controller, reads `?p=`/`?t=`/`?e=` and `mintReportUrl(playerId, examId)` helper.
- **New** `CertGameReadinessReportService.cls` — ~545 lines, all merge-field generation, charts, domain rows, weak-question rollup, "verdict" prose.
- **New** `pages/CertGameReadinessReport.page` + meta — VF page wrapping the merged HTML.
- **New** `staticresources/readinessReportTemplate.html` + meta — the HTML shell with `{{merge}}` placeholders.
- `CertGameSlackRenderService.cls` (M) — overload `gameOverBlocks(..., Id playerId, Id examId)` adds the "View full report" button when a player id is passed.
- `CertGameSessionService.cls` (M, 1 line) — passes `player.Id` + `sess.Certification_Exam__c` into the overload.
- Profile updates (see §3) grant class + page access.

### C. Leaderboard polish

- `CertGameLeaderboardController.cls` (M, +301 lines).
- `lwc/certGameLeaderboard/` `.html` + `.js` updated, **new** `.css` (KPI tiles, podium, accuracy bars, gold/silver/bronze row tints).

### D. Admin/config metadata

- `App_Setting.Default.md-meta.xml` (M) — **secrets pasted in plain text** (see §2).
- `profiles/Admin.profile-meta.xml` (M) — adds class access to the two readiness classes + page access.
- `profiles/certgame Profile.profile-meta.xml` (M) — same plus `WebSessionToken` class access (this is the public Site's profile, given the `urlPathPrefix=certgame`).

### E. Question-import tooling (no code dependencies, pure helpers)

- `docs/certification_exam_import.md` (new) — short authoring guide.
- `scripts/convert_cert_csv.py` (new) — one-shot CSV → Certification_Exam\_\_c shape.
- `scripts/README_cert_exam_import.txt` (new).
- `slack-100-cards-separated.sh` (new, **104 KB at repo root**) — see §4.

---

## 2. Deploy blockers (must fix before any commit / push)

### B1. Secrets committed to `App_Setting.Default.md-meta.xml`

This file currently contains real-looking values for:

- `Slack_Bot_Token__c` = `xoxb-1509154061287-11141634831254-…`
- `Slack_Signing_Secret__c` = `94fdc2dd…`
- `Slack_Verification_Token__c` = `kNrZKYvNP23ZthaI0PS7YdBO`
- `Web_Google_Client_Id__c` = `996785802571-…apps.googleusercontent.com`
- `Web_Session_Secret__c` = `f8659cbba8…` (64-hex; this is the HMAC key for `WebSessionToken`)

AGENTS.md §0 rule #3 — _"No secrets in code. All API keys go through Named Credentials + External Credentials."_ This violates it.

**Action — in this order:**

1. Rotate the Slack signing secret and bot token in `api.slack.com/apps`. Rotate the Google OAuth client secret if it was paired with this client id. Rotate `Web_Session_Secret__c` — every minted readiness URL signed with this key is now invalid anyway, so rotating costs nothing.
2. Revert this file: `git checkout -- force-app/main/default/customMetadata/App_Setting.Default.md-meta.xml` (or set those `<value>` nodes back to `xsi:nil="true"`).
3. Bind the new secrets via External Credentials + Permission Set in the deployed org (manual, post-deploy), not in metadata.
4. If the file was ever pushed, scrub the secret from history (`git filter-repo` or BFG) and force-push — but the rotation in step 1 is the real fix; the scrub is hygiene.

### B2. New fields have no FLS in any profile or permission set

The 6 new Trivia_Question\_\_c fields are not granted in:

- `Admin.profile-meta.xml`
- `certgame Profile.profile-meta.xml`
- any of the 7 `permissionsets/Cert_Game_*.permissionset-meta.xml`

The Apex saves with `update as system` so writes will succeed, but reviewers won't see these fields in standard layouts, list views, or report types. `Cert_Game_Question_Reviewer` is the natural home — add `<fieldPermissions>` entries for all six fields (read + edit).

### B3. No tests for the two new readiness classes

`CertGameReadinessReportController` and `CertGameReadinessReportService` total ~615 lines of new Apex with **zero `_Test` class**. AGENTS.md §0 rule #9 — _"≥85% coverage overall."_ Right now, deploying these classes will fail the suite-wide threshold once the lines-of-code denominator grows.

Minimum viable test class (one file, ~6 tests) covers:

1. `renderHtml(null, null)` returns the "Candidate / Salesforce Certification" branch.
2. `renderHtml(playerId, null)` with seeded `Player_Answer__c` / `Player_Topic_Stat__c` exercises the trend + domain + weak-question paths.
3. `mintReportUrl(null, null)` returns null; `mintReportUrl(playerId, null)` returns a URL containing `p=` and `t=`.
4. Controller constructor in **demo mode** (`demo=1` page param) renders without a token.
5. Controller constructor with an **invalid token** sets `errorMessage`.
6. `escape()` and `applyMerge()` (both `@TestVisible`) round-trip a payload with `<>&"'`.

### B4. New static resource has no test mock

`CertGameReadinessReportService.loadTemplate()` queries the `readinessReportTemplate` static resource. In tests the resource exists (it's in the package), so this is fine — but verify a `@SeeAllData=false` test can still see it. Salesforce treats `StaticResource` as setup data, so this works; just include an assertion in the test class so a future rename breaks loudly.

---

## 3. Tightening that should ship with this PR

### Permission sets, not profiles

You added class/page access on `Admin.profile` and `certgame Profile`. For the AppExchange path (AGENTS.md Phase 10 / 2GP), grant the two readiness classes and the page via `Cert_Game_All_Admin` permset group (or a new `Cert_Game_Web_Guest` set for the Site profile) rather than touching the system Admin profile. The profile edits stay in for the dev org; the permset is what packages cleanly.

### `update as system` in QuestionReviewController

The controller uses `update as system` on every mutation. That's pragmatic — reviewers don't need direct CRUD on `Trivia_Question__c` — but AGENTS.md §0 rule #4 calls for `with sharing` + CRUD/FLS. Leave a one-line comment at the top of `applyEdits`/`publish`/etc. explaining _why_ system mode (the queue console enforces its own gating via `ALLOWED_STATUS` + `Fact_Check_Passed__c`). Security review will ask.

### Status picklist back-compat

You kept `Reviewed` in `ALLOWED_STATUS` so existing rows don't break, but the new flow never sets it. Two options:

1. Leave it for now, add a comment that `Reviewed` is deprecated.
2. Write a one-off Apex migration that flips any existing `Status__c = 'Reviewed'` to `Fact Verified` (with `Fact_Check_Passed__c=true` if and only if the row has citations) — then remove `Reviewed` from `ALLOWED_STATUS`.

Either is fine. (1) is the right default unless you have prod data already.

### Layouts

There's no `force-app/main/default/layouts/Trivia_Question__c-*.layout-meta.xml`. New fields will be invisible in the standard record page unless you ship a layout or rely on Dynamic Forms. If you're not using the standard UI for reviewers (the LWC console is the only surface), this is fine — but note it in the PR so it's a conscious choice.

### LWC Jest tests

There are no `__tests__/` folders under any LWC. `jest.config.js` exists and points at sfdx-lwc-jest. Even one smoke test per modified LWC (`certGameLeaderboard`, `questionReviewConsole`) would catch the cheap template-binding regressions.

### Slack render service backward compat

`gameOverBlocks(..., String examCode)` still exists and delegates to the new 6-arg overload with nulls. Good. Verify the only remaining caller is the test class — `CertGameSessionService` now uses the long form. Grep:

```bash
rg 'gameOverBlocks\(' force-app
```

If anything else still calls the 4-arg form in production code, the link to the readiness report won't appear for that path.

---

## 4. Repo hygiene (not blockers, but should be done)

- `slack-100-cards-separated.sh` (104 KB), `slack-50-cards-separated.sh` (53 KB), `slack-50-cards.sh` (50 KB) live at repo root and look like ad-hoc Block Kit demo payloads. Either move them to `scripts/demos/` and `.gitignore` regeneration output, or drop them entirely if `sample_data/` already covers the case.
- `.apexerr.txt` is a zero-byte stub from a prior `sf` run — `.gitignore` it.
- `PROJECT_LOG.md` is being treated as a phase journal; consider moving it to `docs/phase-log.md` so the repo root stays clean.

---

## 5. Suggested commit ordering (for one cohesive PR)

If you split into reviewable commits, this is the order that minimizes broken intermediate states:

1. **`feat(data): add fact-check + publish-audit fields on Trivia_Question__c`**
   The 6 new field XMLs + the `Status__c` picklist addition + permission-set FLS grants.
2. **`feat(review): two-step publish gate in QuestionReviewController + console`**
   Apex + LWC HTML/JS/CSS + updated test class + CitationLinkVerifier (cls + test).
3. **`feat(readiness): public-Site readiness report from Game Over card`**
   New two classes + Visualforce page + static resource + minimal test class + SlackRenderService overload + SessionService one-liner + profile/permset access.
4. **`feat(leaderboard): KPI tiles + podium + medal styling`**
   Leaderboard controller + LWC HTML/JS/CSS.
5. **`chore(scripts): cert-exam CSV converter + import doc`**
   `scripts/convert_cert_csv.py` + `docs/certification_exam_import.md` + `scripts/README_cert_exam_import.txt`.
6. **`chore: gitignore demo shell scripts and stub files`**
   Move/remove the 100KB shell scripts and `.apexerr.txt`.

**Do not commit** the `App_Setting.Default.md-meta.xml` change as-is — revert it (see §2 / B1).

---

## 6. Pre-deploy checklist

Run in order against your `certgame` scratch org:

```bash
# 0. Confirm no secrets in the diff
git diff -- force-app/main/default/customMetadata/

# 1. Validate-only deploy (catches metadata wiring without committing)
sf project deploy validate -o certgame --test-level RunLocalTests

# 2. Confirm coverage on the new readiness classes is ≥85% once tests land
sf apex run test -o certgame -r human -w 20 --code-coverage \
  --class-names CertGameReadinessReportController_Test,CertGameReadinessReportService_Test,QuestionReviewController_Test,CitationLinkVerifier_Test

# 3. Security scanner (per AGENTS.md §9)
sf scanner run --target "force-app" --severity-threshold 2

# 4. After deploy: bind real Slack/Stripe secrets via External Credentials in the org UI,
#    NOT in App_Setting.Default.md-meta.xml.

# 5. Smoke test the public readiness page
#    https://<your-site-domain>/certgame/CertGameReadinessReport?demo=1
```

---

## 7. TL;DR — gap matrix

| Gap                                                       | Severity    | Owner action                                                      |
| --------------------------------------------------------- | ----------- | ----------------------------------------------------------------- |
| Secrets in App_Setting.Default.md-meta.xml                | **Blocker** | Rotate + revert file (see §2 B1)                                  |
| No FLS for 6 new Trivia_Question\_\_c fields              | **Blocker** | Add `<fieldPermissions>` to `Cert_Game_Question_Reviewer` permset |
| No test class for the two readiness Apex classes          | **Blocker** | Add `CertGameReadinessReport*_Test.cls` (≥85% on both)            |
| `Admin.profile` edited instead of permset for new access  | High        | Move grants to `Cert_Game_All_Admin` permset group                |
| `update as system` without justification comment          | Medium      | One-line comment per mutation method                              |
| `Reviewed` status now orphaned in new flow                | Low         | Comment as deprecated; migration optional                         |
| No Trivia_Question\_\_c page layout / Dynamic Form update | Low         | Add fields to layout or document LWC-only                         |
| No LWC Jest tests for changed components                  | Low         | One smoke test per LWC                                            |
| 104 KB demo `.sh` scripts at repo root                    | Low         | Move to `scripts/demos/` or `.gitignore`                          |
| `.apexerr.txt`, `PROJECT_LOG.md` at root                  | Cleanup     | `.gitignore` / move to `docs/`                                    |
