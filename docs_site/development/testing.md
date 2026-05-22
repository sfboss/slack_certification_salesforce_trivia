# Testing

## Apex

Run the full suite:

```bash
sf apex run test -o certgame -r human -w 20 --code-coverage
```

Targets (per [AGENTS.md §0](https://github.com/sfboss/slack_certification_salesforce_trivia/blob/main/AGENTS.md)):

- Org-wide coverage ≥ **85%**
- `EntitlementGuard`, `SlackSignatureVerifier`, `CertGameScoringService`,
  `StripeWebhookHandler` ≥ **95%**

Current state recorded in
[PROJECT_LOG.md](https://github.com/sfboss/slack_certification_salesforce_trivia/blob/main/PROJECT_LOG.md):

| Metric | Value |
| --- | --- |
| Tests run | 151 |
| Pass rate | 100% |
| Org-wide coverage | 90% |
| `EntitlementGuard` | 96% |
| `SlackSignatureVerifier` | 97% |
| `CertGameScoringService` | 100% |
| `StripeWebhookHandler` | 98% |

### Run a single class

```bash
sf apex run test -o certgame -n CertGameSessionService_Test -r human -w 20
```

### Mocking callouts

All Slack / OpenAI / Stripe outbound calls go through Named Credentials. Tests must supply
an `HttpCalloutMock`:

```apex
@IsTest
static void itPostsToSlack() {
    Test.setMock(HttpCalloutMock.class, new SlackHappyPathMock());
    Test.startTest();
    SlackApiClient.postMessage(new Map<String,Object>{ 'channel' => 'C1', 'text' => 'hi' });
    Test.stopTest();
}
```

### Signature override

Verifier classes expose `@TestVisible secretOverride`:

```apex
SlackSignatureVerifier.secretOverride = 'test-signing-secret';
```

## LWC (Jest)

Config: [jest.config.js](https://github.com/sfboss/slack_certification_salesforce_trivia/blob/main/jest.config.js).

```bash
npm install
npm test
```

## Python

Schema validation against the question pack contract:

```bash
python scripts/validate-question-json.py \
  sample_data/adm201-question-pack.sample.json
```

Citation URL audit:

```bash
python scripts/verify-citations.py --org certgame
```

## Static analysis

```bash
sf scanner run --target force-app --severity-threshold 2 --format table
```

Severity ≤ 2 (High) findings must be **0** before merge.

PMD:

```bash
npx pmd check -d force-app -R pmd-ruleset.xml -f text
```

Style findings (~830 pre-existing) are tracked as backlog and do not block merges. See
[PROJECT_LOG.md](https://github.com/sfboss/slack_certification_salesforce_trivia/blob/main/PROJECT_LOG.md).

## Test conventions

- `@IsTest` with explicit `static testMethod` is avoided; use `@IsTest static void ...`.
- `@TestSetup` for shared data.
- Always wrap callouts with `Test.startTest()/stopTest()`.
- Use mocks rather than `SeeAllData=true`.
- One assertion per behavior; prefer `System.assertEquals(expected, actual, 'message')`.

## CI

GitHub Actions workflows are documented in
[docs/github-actions-workflows.md](https://github.com/sfboss/slack_certification_salesforce_trivia/blob/main/docs/github-actions-workflows.md).
The pipeline runs Apex tests against a freshly created scratch org and posts results to
the configured Slack webhook.
