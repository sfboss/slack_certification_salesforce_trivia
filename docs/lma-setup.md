# License Management App (LMA) Setup

The `CertGameSlackManager` package distributes via AppExchange and tracks subscribers
through the License Management App in the partner org.

## 1. Request the LMA

1. From the [Partner Console](https://partners.salesforce.com), open **Publishing → Organizations**
   and choose your **License Management Org (LMO)**.
2. From the LMO, install the License Management App from
   https://help.salesforce.com/s/articleView?id=lma_install.htm.

## 2. Link your package

1. In the LMO, open **License Management App → Packages**.
2. Click **New** and enter the **Package Id** from `sfdx-project.json → packageAliases.CertGameSlackManager`.
3. Save. New installs of the 2GP package automatically create `License` and `Subscriber` records.

## 3. Default license configuration

- License Type: **Active**
- Default Seats: **Site License** (workspace-level, not per-user)
- Default Expiration: **None** (subscription is governed by `Tenant__c.Plan__c` + Stripe)

## 4. Provisioning flow

1. A workspace installs the Slack App → Slack OAuth callback fires `CertGameTenantService.handleInstall`,
   inserting a `Tenant__c` row with `Plan__c='Trial'`.
2. When the AppExchange install completes, the LMA inserts a corresponding `License` record. Use a
   Flow or trigger in the LMO to mirror license expiration into the subscriber org's `Tenant__c` if needed.
3. Plan upgrades flow through `CertGameBillingService.handleUpgradeSubmission` and Stripe webhooks
   (`StripeWebhookHandler`) which set `Tenant__c.Plan__c` and `Tenant__c.Status__c`.

## 5. Suspending a subscriber

- Set `License.Status = Suspended` in the LMO.
- A scheduled Flow in the LMO can call the subscriber org via a Named Credential to mark
  `Tenant__c.Status__c = 'Suspended'`. The `EntitlementGuard` then blocks gameplay
  for non-`Active` tenants.

## 6. Telemetry

- `Usage_Metric__c` aggregates per tenant per month (`Period__c = YYYY-MM`).
- Reporting packages can subscribe to the subscriber org via Salesforce-to-Salesforce or use the
  License Management App's standard usage reports.
