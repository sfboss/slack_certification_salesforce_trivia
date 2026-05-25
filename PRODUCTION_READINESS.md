# Salesforce Trivia Slack Bot — Production Readiness

## Current Working State

- Slack app is installed in Slack.
- Slack bot/game works locally.
- Slack admin app exists in repo.
- Repo validates and builds.
- Questions are stored in Salesforce.
- Slack game pulls questions from Salesforce DB.
- Google login is used to track users/points.
- Slack answer selection hits Apex REST.
- Apex REST resource is exposed through guest access.
- Long-term host/org is my Salesforce Partner Org.
- End users should not need their own Salesforce app/package to start playing.

---

## Production Goal

A real user can install or access the Slack trivia experience, answer Salesforce certification questions, have their score tracked, and continue using the app without local developer setup, placeholder data, or manual backend intervention.

---

## Production Definition of Done

### 1. Hosting / Runtime

- [ ] Slack admin app has a permanent production URL.
- [ ] Production app is not running from localhost.
- [ ] Production environment variables/secrets are configured.
- [ ] Production logs are accessible.
- [ ] App can restart/redeploy without losing data.

### 2. Salesforce Backend

- [ ] Production Salesforce org is selected.
- [ ] Required custom objects are deployed.
- [ ] Required fields are deployed.
- [ ] Required Apex classes are deployed.
- [ ] Required permission sets are deployed.
- [ ] Guest user access is explicitly documented.
- [ ] Guest user only has minimum required permissions.
- [ ] Apex REST endpoint works from Slack in production.
- [ ] Question data exists in production Salesforce.
- [ ] No sample/placeholder questions are required for operation.

### 3. Slack App

- [ ] Production Slack app config is documented.
- [ ] Slash commands/events/interactivity URLs point to production.
- [ ] Webhook URL is not hardcoded in repo.
- [ ] Slack signing secret is stored securely.
- [ ] Slack bot token is stored securely.
- [ ] Interactive answer buttons work in production.
- [ ] Failed/expired interactions return a clean message.

### 4. Authentication / Users

- [ ] Google login works in production.
- [ ] User identity maps cleanly to Slack user identity.
- [ ] Same user does not get duplicate records.
- [ ] User scores persist across sessions.
- [ ] Leaderboard or score history is queryable.

### 5. Game Logic

- [ ] User can start a trivia session.
- [ ] User can answer a question.
- [ ] Correct/incorrect result is stored.
- [ ] Score updates after answer.
- [ ] Question category/objective is tracked.
- [ ] Weak-topic tracking works.
- [ ] Repeated questions are controlled.
- [ ] Empty question pool fails gracefully.

### 6. Admin App

- [ ] Admin can view questions.
- [ ] Admin can create/edit/import questions.
- [ ] Admin can view users/scores.
- [ ] Admin can view topic weakness data.
- [ ] Admin actions hit production Salesforce.
- [ ] Admin app does not expose secrets/client credentials.

### 7. Data Quality

- [ ] Every question has exam name.
- [ ] Every question has objective/category.
- [ ] Every question has correct answer.
- [ ] Every question has explanation.
- [ ] Every question has source/reference field if available.
- [ ] No duplicate obvious questions.
- [ ] No placeholder text.
- [ ] No fake/demo-only records required.

### 8. Security

- [ ] No secrets committed to git.
- [ ] `.env` is ignored.
- [ ] Salesforce credentials are not hardcoded.
- [ ] Slack credentials are not hardcoded.
- [ ] Google OAuth credentials are not hardcoded.
- [ ] Guest Apex endpoint validates payloads.
- [ ] Slack request signing is verified where applicable.
- [ ] Rate limiting or abuse protection is considered.
- [ ] Public endpoints have least-privilege access.

### 9. Deployment

- [ ] Fresh clone instructions work.
- [ ] Build command works.
- [ ] Test command works.
- [ ] Deploy command is documented.
- [ ] Salesforce deploy command is documented.
- [ ] Production deploy can be repeated.
- [ ] Rollback/recovery steps exist.

### 10. Site / Marketing

- [ ] Landing page exists.
- [ ] Each exam has a keyword-targeted post/page.
- [ ] App value prop is clear.
- [ ] CTA is clear.
- [ ] Slack install/start flow is clear.
- [ ] Reddit-safe launch blurb exists.
- [ ] No overclaiming about official Salesforce affiliation.
- [ ] Pricing/free-beta positioning is clear.

---

## Immediate Next Action

Run a fresh repo inventory and paste the output below.

```bash
pwd
git status` --short
find . -maxdepth 3 -type f \
  | sed 's#^\./##' \
  | sort \
  | grep -v node_modules \
  | grep -v .git