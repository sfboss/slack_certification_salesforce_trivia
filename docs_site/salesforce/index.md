# Salesforce Guide

The Salesforce package is the **source of truth** for every gameplay artifact. Slack is a
thin controller — every command goes through HMAC-verified webhook → Apex services → custom
objects.

In this section:

- [Overview](overview.md) — what lives in Salesforce and why.
- [Setup](setup.md) — orgs, permission sets, custom metadata.
- [Data Model](../data-model/index.md) — the 27 custom objects.
- [APIs](apis.md) — public Apex REST endpoints exposed via Salesforce Site.
- [Authentication](authentication.md) — Named Credentials, signing secrets.
- [Deployment](deployment.md) — sandbox, production, 2GP packaging.
