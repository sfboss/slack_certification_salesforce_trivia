# Troubleshooting

| Symptom                                                | Likely cause                                                         | Fix                                                                                                             |
| ------------------------------------------------------ | -------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| Slack reports `dispatch_failed` or `operation_timeout` | Apex took > 3s to ack.                                               | Check `App_Log__c` for slow SOQL; ensure the Site Guest User has the integration permission set.                |
| `/certgame help` returns no response                   | Slash command URL not pointing at `/services/apexrest/slack/events`. | Fix the Slack manifest URL.                                                                                     |
| `/certgame play X` → "No published questions yet"      | Drafts not published.                                                | Open **Review Drafts** and publish.                                                                             |
| `/certgame play X` → "Daily quota reached"             | Tenant is Free and exceeded `Max_Games_Per_Day_Free__c`.             | Upgrade or raise the limit in `App_Setting.Default`.                                                            |
| Buttons do nothing                                     | Interactivity URL ≠ slash command URL.                               | All three Slack URLs must be the **same** Salesforce endpoint.                                                  |
| `401 invalid signature` in `App_Log__c`                | `Slack_Signing_Secret__c` is wrong or rotated.                       | Re-paste the signing secret.                                                                                    |
| `400 invalid signature` from Stripe webhook            | Stripe webhook secret mismatch.                                      | Update the Stripe External Credential principal.                                                                |
| Tournament save → "Something went wrong"               | `Certification_Exam__c` required field not selected.                 | Pick an exam in the combobox.                                                                                   |
| Generation Jobs tab is empty                           | No job has been run.                                                 | Trigger a job from Apex or via `/certgame plan` on a qualifying tenant.                                         |
| `dispatch_failed` on slash command but events work     | Form-encoded body HMAC mismatch (Site strips raw bytes).             | Set `App_Setting.Default.Slack_Verification_Token__c` to enable the token fallback.                             |
| Citations panel shows red badges                       | Citation auditor flagged URL as 4xx/5xx.                             | Fix the URL and re-publish.                                                                                     |
| Player_Answer insert fails                             | Duplicate `Unique_Key__c` (round + player).                          | Expected — Apex falls back to `Database.upsert(..., AccessLevel.SYSTEM_MODE)` and treats duplicates as a no-op. |

## Diagnostic commands

```text
/certgame doctor
```

Runs [`CertGameDoctorService`](../api-reference/apex.md#certgamedoctorservice) end-to-end:

- Named Credentials exist
- Signing secret configured
- At least one `Published` `Trivia_Question__c` per exam
- App Home view renders

```text
/certgame debug
```

Returns the last hour of `App_Log__c` entries from Apex.

```text
/certgame notify-test
```

Confirms outbound `chat.postMessage` works against the bound `Slack_Bot` credential.

## Log surfaces

| Surface                   | Object               | Owner                  |
| ------------------------- | -------------------- | ---------------------- |
| Apex info/warn/error      | `App_Log__c`         | `AppLogger`            |
| Tamper-evident audit      | `Audit_Log__c`       | `AuditLogger`          |
| Inbound Slack idempotency | `Slack_Event_Log__c` | `SlackRequestRouter`   |
| Stripe webhook events     | `License_Event__c`   | `StripeWebhookHandler` |

## Replays

You cannot manually replay a Slack request — the idempotency key in
`Slack_Event_Log__c` will short-circuit it. To force a replay during diagnosis, delete the
matching row first (admin-only).

## Useful SOQL queries

```sql
-- Recent errors
SELECT Class_Name__c, Method_Name__c, Message__c, Occurred_At__c
FROM App_Log__c
WHERE Level__c = 'ERROR' AND Occurred_At__c = LAST_N_HOURS:24
ORDER BY Occurred_At__c DESC LIMIT 50

-- Published-question counts per exam
SELECT Certification_Exam__r.Certification_Code__c code, COUNT(Id) n
FROM Trivia_Question__c
WHERE Status__c = 'Published'
GROUP BY Certification_Exam__r.Certification_Code__c

-- Tenants in non-Active states
SELECT Name, Plan__c, Status__c FROM Tenant__c WHERE Status__c != 'Active'

-- Recent inbound Slack events
SELECT Slack_Event_Id__c, Event_Type__c, Slack_Team_Id__c, Received_At__c
FROM Slack_Event_Log__c
WHERE Received_At__c = LAST_N_HOURS:1
ORDER BY Received_At__c DESC LIMIT 50
```

More canned queries: [docs/soql-query-reference.md](https://github.com/sfboss/slack_certification_salesforce_trivia/blob/main/docs/soql-query-reference.md).
