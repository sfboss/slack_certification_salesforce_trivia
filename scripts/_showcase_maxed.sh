#!/usr/bin/env bash
# ============================================================================
#  run_slack_blockkit_showcase_maxed.sh
#  ---------------------------------------------------------------------------
#  Showcase script demonstrating maximum Block Kit surface area for incoming
#  webhooks. Each card intentionally exercises a different combination of
#  block types and elements so the file doubles as a copy/paste reference.
#
#  Block types used across the cards:
#    header, section (with text, fields, accessory variants), divider,
#    context (with image + mrkdwn elements), image, rich_text
#    (rich_text_section, rich_text_list, rich_text_preformatted,
#     rich_text_quote, with styled spans), actions
#
#  Interactive elements demonstrated:
#    button (primary, danger, default, with confirm dialog), url buttons,
#    overflow menu, static_select, multi_static_select, users_select,
#    conversations_select, channels_select, datepicker, timepicker,
#    datetimepicker, radio_buttons, checkboxes, image accessory
#
#  NOTE ON WEBHOOKS:
#  Incoming webhooks render every block type but they cannot RECEIVE
#  interaction payloads. URL buttons work as plain links. Selects,
#  datepickers, radios, and checkboxes will render and be interactive in
#  the UI, but their values won't be POSTed anywhere unless this is sent
#  via chat.postMessage from a Slack app with an Interactivity Request
#  URL configured. They still render beautifully — which is the point of
#  a showcase deck.
# ============================================================================

set -euo pipefail

SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL:?Set SLACK_WEBHOOK_URL env var to your Slack Incoming Webhook URL}"

post() {
  local label="$1"
  local payload="$2"
  printf "  → %-32s " "$label"
  local http_code
  http_code=$(curl -sS -o /tmp/slack_resp.txt -w "%{http_code}" \
    -X POST -H 'Content-type: application/json' \
    --data "$payload" "$SLACK_WEBHOOK_URL" || echo "000")
  if [[ "$http_code" == "200" ]]; then
    printf "✓ ok\n"
  else
    printf "✗ HTTP %s — %s\n" "$http_code" "$(cat /tmp/slack_resp.txt)"
  fi
  sleep 0.4   # be polite to Slack rate limits
}

echo
echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║  Slack Block Kit — Maximum Surface Area Showcase                  ║"
echo "║  Posting 6 cards, each exercising a different element family.     ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo

# ============================================================================
# CARD 1 — Executive DevOps Digest
# Showcase focus: section accessories (image + overflow), rich_text with
# styled spans (bold/code/colored), context block with avatar stack
# ============================================================================
post "Executive DevOps Digest" '{
  "text": "Salesforce DevOps Executive Digest",
  "attachments": [{
    "color": "#2EB67D",
    "blocks": [
      {
        "type": "header",
        "text": {"type": "plain_text", "text": "🧭 Salesforce DevOps Executive Digest", "emoji": true}
      },
      {
        "type": "section",
        "text": {
          "type": "mrkdwn",
          "text": "*Daily operating signal* — org backup, metadata diff, deployment readiness, and automation risk scan completed.\n\n_Generated 06:00 UTC • next run in 23h 58m_"
        },
        "accessory": {
          "type": "image",
          "image_url": "https://emoji.slack-edge.com/T0CAF47AT/salesforce/9d33e7c2c5589a26.png",
          "alt_text": "Salesforce"
        }
      },
      {
        "type": "section",
        "fields": [
          {"type": "mrkdwn", "text": "*Org*\n`Production`"},
          {"type": "mrkdwn", "text": "*Overall*\n🟢 Stable"},
          {"type": "mrkdwn", "text": "*Deployability*\n✅ Ready"},
          {"type": "mrkdwn", "text": "*Automation Risk*\n🟡 3 warnings"},
          {"type": "mrkdwn", "text": "*Metadata Drift*\n2 components"},
          {"type": "mrkdwn", "text": "*Governance Gate*\n1 pending"}
        ],
        "accessory": {
          "type": "overflow",
          "options": [
            {"text": {"type": "plain_text", "text": "📌 Pin to channel"}, "value": "pin"},
            {"text": {"type": "plain_text", "text": "🔕 Mute digest 24h"}, "value": "mute"},
            {"text": {"type": "plain_text", "text": "📤 Forward to manager"}, "value": "forward"},
            {"text": {"type": "plain_text", "text": "📊 View 7-day trend"}, "value": "trend"}
          ]
        }
      },
      {"type": "divider"},
      {
        "type": "rich_text",
        "elements": [
          {
            "type": "rich_text_section",
            "elements": [
              {"type": "text", "text": "Recommended actions", "style": {"bold": true}},
              {"type": "text", "text": "  (in priority order)"}
            ]
          },
          {
            "type": "rich_text_list",
            "style": "ordered",
            "elements": [
              {"type": "rich_text_section", "elements": [
                {"type": "text", "text": "Review "},
                {"type": "text", "text": "Flow", "style": {"code": true}},
                {"type": "text", "text": " warnings before next standup"}
              ]},
              {"type": "rich_text_section", "elements": [
                {"type": "text", "text": "Approve or reject "},
                {"type": "text", "text": "PR #482", "style": {"code": true, "bold": true}},
                {"type": "text", "text": " (metadata)"}
              ]},
              {"type": "rich_text_section", "elements": [
                {"type": "text", "text": "Confirm release window with "},
                {"type": "user", "user_id": "U000RELMGR"}
              ]}
            ]
          }
        ]
      },
      {
        "type": "actions",
        "elements": [
          {"type": "button", "text": {"type": "plain_text", "text": "Open Dashboard"}, "url": "https://example.com/devops-dashboard", "style": "primary"},
          {"type": "button", "text": {"type": "plain_text", "text": "View PR"}, "url": "https://example.com/pull-request"},
          {"type": "button", "text": {"type": "plain_text", "text": "Runbook"}, "url": "https://example.com/runbook"}
        ]
      },
      {
        "type": "context",
        "elements": [
          {"type": "image", "image_url": "https://avatars.githubusercontent.com/u/0?v=4", "alt_text": "bot"},
          {"type": "mrkdwn", "text": "scanned 14 repos •"},
          {"type": "image", "image_url": "https://emoji.slack-edge.com/T0CAF47AT/sfdx/abc.png", "alt_text": "sfdx"},
          {"type": "mrkdwn", "text": "`SLK-DIGEST-001` • generated by *DevOps Notifier* • <https://example.com/audit|audit log>"}
        ]
      }
    ]
  }]
}'

# ============================================================================
# CARD 2 — Incident Command
# Showcase focus: image block (status visualization), rich_text_quote,
# users_select for assigning owner, danger button with confirm dialog,
# radio_buttons for severity escalation
# ============================================================================
post "Incident Command" '{
  "text": "Salesforce Incident Command",
  "attachments": [{
    "color": "#E01E5A",
    "blocks": [
      {
        "type": "header",
        "text": {"type": "plain_text", "text": "🚨 Salesforce Incident Command", "emoji": true}
      },
      {
        "type": "section",
        "text": {
          "type": "mrkdwn",
          "text": "*Flow error spike detected* on Opportunity automation.\nThis card is structured for triage — not just notification."
        }
      },
      {
        "type": "section",
        "fields": [
          {"type": "mrkdwn", "text": "*Severity*\n🔴 High"},
          {"type": "mrkdwn", "text": "*Status*\n`investigating`"},
          {"type": "mrkdwn", "text": "*Object*\nOpportunity"},
          {"type": "mrkdwn", "text": "*Automation*\nRecord-triggered Flow"},
          {"type": "mrkdwn", "text": "*First Seen*\n2 min ago"},
          {"type": "mrkdwn", "text": "*Error Rate*\n42 / 5m"}
        ]
      },
      {
        "type": "rich_text",
        "elements": [
          {
            "type": "rich_text_quote",
            "elements": [
              {"type": "text", "text": "FLOW_INTERVIEW_FAILED: ", "style": {"bold": true, "code": false}},
              {"type": "text", "text": "Cannot read property \u0027Amount__c\u0027 of null at OpportunityAfterSave.assignSegment"}
            ]
          }
        ]
      },
      {"type": "divider"},
      {
        "type": "section",
        "text": {"type": "mrkdwn", "text": "*Assign incident commander*"},
        "accessory": {
          "type": "users_select",
          "placeholder": {"type": "plain_text", "text": "Select a user"},
          "action_id": "incident_owner_select"
        }
      },
      {
        "type": "section",
        "text": {"type": "mrkdwn", "text": "*Escalate severity*"},
        "accessory": {
          "type": "radio_buttons",
          "action_id": "severity_radio",
          "options": [
            {"text": {"type": "plain_text", "text": "🔴 SEV-1 (page on-call)"}, "value": "sev1"},
            {"text": {"type": "plain_text", "text": "🟠 SEV-2 (notify leads)"}, "value": "sev2"},
            {"text": {"type": "plain_text", "text": "🟡 SEV-3 (continue triage)"}, "value": "sev3"}
          ],
          "initial_option": {"text": {"type": "plain_text", "text": "🟠 SEV-2 (notify leads)"}, "value": "sev2"}
        }
      },
      {
        "type": "section",
        "text": {"type": "mrkdwn", "text": "*Triage checklist*"},
        "accessory": {
          "type": "checkboxes",
          "action_id": "triage_checklist",
          "options": [
            {"text": {"type": "mrkdwn", "text": "Check failed flow interviews"}, "value": "interviews"},
            {"text": {"type": "mrkdwn", "text": "Identify changed metadata"}, "value": "metadata"},
            {"text": {"type": "mrkdwn", "text": "Confirm affected users"}, "value": "users"},
            {"text": {"type": "mrkdwn", "text": "Reproduce in sandbox"}, "value": "sandbox"},
            {"text": {"type": "mrkdwn", "text": "Patch or rollback"}, "value": "patch"}
          ]
        }
      },
      {
        "type": "actions",
        "elements": [
          {
            "type": "button",
            "text": {"type": "plain_text", "text": "Rollback Now"},
            "url": "https://example.com/rollback",
            "style": "danger",
            "confirm": {
              "title": {"type": "plain_text", "text": "Rollback production?"},
              "text": {"type": "mrkdwn", "text": "This will revert the Opportunity_After_Save Flow to the previous deployed version. Active interviews may be interrupted."},
              "confirm": {"type": "plain_text", "text": "Yes, rollback"},
              "deny": {"type": "plain_text", "text": "Cancel"},
              "style": "danger"
            }
          },
          {"type": "button", "text": {"type": "plain_text", "text": "View Failed Interviews"}, "url": "https://example.com/flow-errors"},
          {"type": "button", "text": {"type": "plain_text", "text": "Create Hotfix Branch"}, "url": "https://example.com/create-branch", "style": "primary"}
        ]
      },
      {
        "type": "context",
        "elements": [
          {"type": "image", "image_url": "https://emoji.slack-edge.com/T0CAF47AT/fire/abc.png", "alt_text": "fire"},
          {"type": "mrkdwn", "text": "`SLK-INCIDENT-001` • on-call rotation: *@clay* (primary), *@len* (secondary) • <https://example.com/oncall|view schedule>"}
        ]
      }
    ]
  }]
}'

# ============================================================================
# CARD 3 — Deployment Approval Gate
# Showcase focus: datepicker, timepicker, conversations_select,
# static_select (deployment window), rich_text_preformatted with language,
# image block with title
# ============================================================================
post "Deployment Approval Gate" '{
  "text": "Deployment Approval Gate",
  "attachments": [{
    "color": "#ECB22E",
    "blocks": [
      {
        "type": "header",
        "text": {"type": "plain_text", "text": "🧑‍⚖️ Deployment Approval Gate", "emoji": true}
      },
      {
        "type": "section",
        "text": {"type": "mrkdwn", "text": "*Human approval required* before metadata changes are promoted to production."}
      },
      {
        "type": "section",
        "fields": [
          {"type": "mrkdwn", "text": "*Source Branch*\n`feature/opp-flow-fix`"},
          {"type": "mrkdwn", "text": "*Target Org*\n`Production`"},
          {"type": "mrkdwn", "text": "*Validation*\n✅ Passed (412 / 412)"},
          {"type": "mrkdwn", "text": "*Apex Tests*\n✅ 94.2% coverage"},
          {"type": "mrkdwn", "text": "*Risk Class*\n🟡 Automation change"},
          {"type": "mrkdwn", "text": "*Approval State*\n⏳ Pending"}
        ]
      },
      {
        "type": "rich_text",
        "elements": [
          {
            "type": "rich_text_section",
            "elements": [{"type": "text", "text": "Components in this deployment", "style": {"bold": true}}]
          },
          {
            "type": "rich_text_preformatted",
            "elements": [
              {"type": "text", "text": "Flow              Opportunity_After_Save\nCustomMetadata    DevOps_Routing__mdt\nPermissionSet     Sales_Ops_User\nApexClass         OpportunityRouter\nApexTrigger       OpportunityTrigger"}
            ]
          }
        ]
      },
      {"type": "divider"},
      {
        "type": "section",
        "text": {"type": "mrkdwn", "text": "*Schedule deployment window*"},
        "accessory": {
          "type": "datepicker",
          "action_id": "deploy_date",
          "placeholder": {"type": "plain_text", "text": "Select date"},
          "initial_date": "2026-05-16"
        }
      },
      {
        "type": "section",
        "text": {"type": "mrkdwn", "text": "*Deployment start time* (UTC)"},
        "accessory": {
          "type": "timepicker",
          "action_id": "deploy_time",
          "placeholder": {"type": "plain_text", "text": "Select time"},
          "initial_time": "02:00"
        }
      },
      {
        "type": "section",
        "text": {"type": "mrkdwn", "text": "*Deployment strategy*"},
        "accessory": {
          "type": "static_select",
          "action_id": "deploy_strategy",
          "placeholder": {"type": "plain_text", "text": "Choose strategy"},
          "options": [
            {"text": {"type": "plain_text", "text": "🟢 Standard (validate + deploy)"}, "value": "standard"},
            {"text": {"type": "plain_text", "text": "🛡️ Blue/green (parallel orgs)"}, "value": "bluegreen"},
            {"text": {"type": "plain_text", "text": "🚦 Canary (5% users first)"}, "value": "canary"},
            {"text": {"type": "plain_text", "text": "🛑 Manual (push from CLI)"}, "value": "manual"}
          ],
          "initial_option": {"text": {"type": "plain_text", "text": "🟢 Standard (validate + deploy)"}, "value": "standard"}
        }
      },
      {
        "type": "section",
        "text": {"type": "mrkdwn", "text": "*Notify channel on completion*"},
        "accessory": {
          "type": "conversations_select",
          "action_id": "notify_channel",
          "placeholder": {"type": "plain_text", "text": "Choose a channel"},
          "default_to_current_conversation": true
        }
      },
      {
        "type": "actions",
        "elements": [
          {
            "type": "button",
            "text": {"type": "plain_text", "text": "✓ Approve & Deploy"},
            "url": "https://example.com/approve",
            "style": "primary",
            "confirm": {
              "title": {"type": "plain_text", "text": "Approve deployment?"},
              "text": {"type": "mrkdwn", "text": "This will deploy 5 components to *Production* at the selected window. Notifications will go to the chosen channel."},
              "confirm": {"type": "plain_text", "text": "Approve"},
              "deny": {"type": "plain_text", "text": "Not yet"}
            }
          },
          {"type": "button", "text": {"type": "plain_text", "text": "Review Diff"}, "url": "https://example.com/diff"},
          {
            "type": "button",
            "text": {"type": "plain_text", "text": "✗ Reject"},
            "url": "https://example.com/reject",
            "style": "danger",
            "confirm": {
              "title": {"type": "plain_text", "text": "Reject this deployment?"},
              "text": {"type": "mrkdwn", "text": "The PR will be marked as needing changes and the author will be notified."},
              "confirm": {"type": "plain_text", "text": "Reject"},
              "deny": {"type": "plain_text", "text": "Cancel"},
              "style": "danger"
            }
          }
        ]
      },
      {
        "type": "context",
        "elements": [
          {"type": "image", "image_url": "https://github.githubassets.com/favicons/favicon.png", "alt_text": "github"},
          {"type": "mrkdwn", "text": "`SLK-GATE-001` • PR <https://example.com/pull-request|#482> by *@clay* • last validation 3 min ago"}
        ]
      }
    ]
  }]
}'

# ============================================================================
# CARD 4 — Agent Run Telemetry
# Showcase focus: image block with title (telemetry sparkline chart),
# rich_text with code spans showing pipeline trace, multi_static_select
# for log filters, channels_select
# ============================================================================
post "Agent Run Telemetry" '{
  "text": "Agent Run Telemetry",
  "attachments": [{
    "color": "#36C5F0",
    "blocks": [
      {
        "type": "header",
        "text": {"type": "plain_text", "text": "🤖 Agent Run Telemetry", "emoji": true}
      },
      {
        "type": "section",
        "text": {"type": "mrkdwn", "text": "*Repo Intelligence Agent* completed scan and generated implementation context."},
        "accessory": {
          "type": "image",
          "image_url": "https://emoji.slack-edge.com/T0CAF47AT/robot_face/abc.png",
          "alt_text": "agent"
        }
      },
      {
        "type": "section",
        "fields": [
          {"type": "mrkdwn", "text": "*Agent*\nRepo Intelligence"},
          {"type": "mrkdwn", "text": "*Run State*\n✅ Completed"},
          {"type": "mrkdwn", "text": "*Duration*\n47s"},
          {"type": "mrkdwn", "text": "*Files Scanned*\n1,284"},
          {"type": "mrkdwn", "text": "*Large Files*\n3 (>500KB)"},
          {"type": "mrkdwn", "text": "*Stack*\nSFDX + Python"}
        ]
      },
      {
        "type": "rich_text",
        "elements": [
          {
            "type": "rich_text_section",
            "elements": [{"type": "text", "text": "Pipeline trace", "style": {"bold": true}}]
          },
          {
            "type": "rich_text_section",
            "elements": [
              {"type": "text", "text": "prompt_received", "style": {"code": true}},
              {"type": "text", "text": " → "},
              {"type": "text", "text": "repo_scan", "style": {"code": true}},
              {"type": "text", "text": " → "},
              {"type": "text", "text": "tree_summary", "style": {"code": true}},
              {"type": "text", "text": " → "},
              {"type": "text", "text": "risk_scan", "style": {"code": true}},
              {"type": "text", "text": " → "},
              {"type": "text", "text": "plan_ready", "style": {"code": true, "bold": true}}
            ]
          },
          {
            "type": "rich_text_section",
            "elements": [{"type": "text", "text": "\n"}]
          },
          {
            "type": "rich_text_preformatted",
            "elements": [
              {"type": "text", "text": "[06:00:01] INFO  agent.start    prompt=\"scan sfboss org\"\n[06:00:03] INFO  repo.scan      found 263 repos\n[06:00:18] INFO  tree.summary   depth=4 nodes=1284\n[06:00:41] WARN  risk.scan      3 large files flagged\n[06:00:47] INFO  plan.ready     ✓ context.md written"}
            ]
          }
        ]
      },
      {"type": "divider"},
      {
        "type": "section",
        "text": {"type": "mrkdwn", "text": "*Filter logs by level*"},
        "accessory": {
          "type": "multi_static_select",
          "action_id": "log_filter",
          "placeholder": {"type": "plain_text", "text": "Choose levels"},
          "options": [
            {"text": {"type": "plain_text", "text": "🔴 ERROR"}, "value": "error"},
            {"text": {"type": "plain_text", "text": "🟠 WARN"}, "value": "warn"},
            {"text": {"type": "plain_text", "text": "🔵 INFO"}, "value": "info"},
            {"text": {"type": "plain_text", "text": "⚪ DEBUG"}, "value": "debug"},
            {"text": {"type": "plain_text", "text": "🟣 TRACE"}, "value": "trace"}
          ],
          "initial_options": [
            {"text": {"type": "plain_text", "text": "🔴 ERROR"}, "value": "error"},
            {"text": {"type": "plain_text", "text": "🟠 WARN"}, "value": "warn"}
          ]
        }
      },
      {
        "type": "section",
        "text": {"type": "mrkdwn", "text": "*Stream live output to channel*"},
        "accessory": {
          "type": "channels_select",
          "action_id": "stream_channel",
          "placeholder": {"type": "plain_text", "text": "Pick a channel"}
        }
      },
      {
        "type": "actions",
        "elements": [
          {"type": "button", "text": {"type": "plain_text", "text": "Open Plan"}, "url": "https://example.com/plan", "style": "primary"},
          {"type": "button", "text": {"type": "plain_text", "text": "Agent Logs"}, "url": "https://example.com/agent-logs"},
          {"type": "button", "text": {"type": "plain_text", "text": "View File Tree"}, "url": "https://example.com/tree"},
          {
            "type": "overflow",
            "action_id": "agent_more",
            "options": [
              {"text": {"type": "plain_text", "text": "🔁 Re-run agent"}, "value": "rerun"},
              {"text": {"type": "plain_text", "text": "📥 Download artifacts"}, "value": "download"},
              {"text": {"type": "plain_text", "text": "🧪 Open in sandbox"}, "value": "sandbox"},
              {"text": {"type": "plain_text", "text": "❌ Cancel future runs"}, "value": "cancel"}
            ]
          }
        ]
      },
      {
        "type": "context",
        "elements": [
          {"type": "image", "image_url": "https://emoji.slack-edge.com/T0CAF47AT/python/abc.png", "alt_text": "python"},
          {"type": "image", "image_url": "https://emoji.slack-edge.com/T0CAF47AT/sfdx/abc.png", "alt_text": "sfdx"},
          {"type": "mrkdwn", "text": "`SLK-AGENT-001` • run_id `r_8f3a921` • LangGraph + GitHub Models • <https://example.com/agent-logs|full trace>"}
        ]
      }
    ]
  }]
}'

# ============================================================================
# CARD 5 — Cert Engine Scorecard
# Showcase focus: header + section accessory image (certification badge),
# rich_text_list (bulleted with styled spans), checkboxes for quality
# rubric, static_select for action
# ============================================================================
post "Cert Engine Scorecard" '{
  "text": "Cert Engine Scorecard",
  "attachments": [{
    "color": "#611F69",
    "blocks": [
      {
        "type": "header",
        "text": {"type": "plain_text", "text": "📚 Cert Engine Scorecard", "emoji": true}
      },
      {
        "type": "section",
        "text": {"type": "mrkdwn", "text": "*Salesforce Administrator practice exam pack* generated and passed first validation.\n\n_Ready for SME review and publication._"},
        "accessory": {
          "type": "image",
          "image_url": "https://trailhead.salesforce.com/_images/badges/admin-cert.png",
          "alt_text": "Admin Certification"
        }
      },
      {
        "type": "section",
        "fields": [
          {"type": "mrkdwn", "text": "*Exam*\nAdministrator"},
          {"type": "mrkdwn", "text": "*Questions*\n65"},
          {"type": "mrkdwn", "text": "*Schema*\n✅ Valid"},
          {"type": "mrkdwn", "text": "*Answer Keys*\n✅ 65/65"},
          {"type": "mrkdwn", "text": "*Explanations*\n✅ 65/65"},
          {"type": "mrkdwn", "text": "*Similarity*\n🟡 4 near-dupes"}
        ]
      },
      {
        "type": "rich_text",
        "elements": [
          {
            "type": "rich_text_section",
            "elements": [{"type": "text", "text": "Quality rubric coverage", "style": {"bold": true}}]
          },
          {
            "type": "rich_text_list",
            "style": "bullet",
            "elements": [
              {"type": "rich_text_section", "elements": [
                {"type": "text", "text": "✓ ", "style": {"bold": true}},
                {"type": "text", "text": "Scenario-based wording"}
              ]},
              {"type": "rich_text_section", "elements": [
                {"type": "text", "text": "✓ ", "style": {"bold": true}},
                {"type": "text", "text": "Objective alignment ("},
                {"type": "text", "text": "Trailhead study guide", "style": {"italic": true}},
                {"type": "text", "text": ")"}
              ]},
              {"type": "rich_text_section", "elements": [
                {"type": "text", "text": "✓ ", "style": {"bold": true}},
                {"type": "text", "text": "Plausible distractors"}
              ]},
              {"type": "rich_text_section", "elements": [
                {"type": "text", "text": "✓ ", "style": {"bold": true}},
                {"type": "text", "text": "Explanation depth ≥ 2 sentences"}
              ]},
              {"type": "rich_text_section", "elements": [
                {"type": "text", "text": "✓ ", "style": {"bold": true}},
                {"type": "text", "text": "JSON ingestion ready — "},
                {"type": "text", "text": "schema v3", "style": {"code": true}}
              ]}
            ]
          }
        ]
      },
      {"type": "divider"},
      {
        "type": "section",
        "text": {"type": "mrkdwn", "text": "*Mark sections as reviewed*"},
        "accessory": {
          "type": "checkboxes",
          "action_id": "section_review",
          "options": [
            {"text": {"type": "mrkdwn", "text": "*User Setup & Security* (12 q)"}, "value": "security"},
            {"text": {"type": "mrkdwn", "text": "*Standard & Custom Objects* (18 q)"}, "value": "objects"},
            {"text": {"type": "mrkdwn", "text": "*Sales & Marketing Apps* (12 q)"}, "value": "sales"},
            {"text": {"type": "mrkdwn", "text": "*Service & Support* (8 q)"}, "value": "service"},
            {"text": {"type": "mrkdwn", "text": "*Workflow Automation* (15 q)"}, "value": "automation"}
          ]
        }
      },
      {
        "type": "section",
        "text": {"type": "mrkdwn", "text": "*Publication target*"},
        "accessory": {
          "type": "static_select",
          "action_id": "publish_target",
          "placeholder": {"type": "plain_text", "text": "Choose destination"},
          "options": [
            {"text": {"type": "plain_text", "text": "🟢 Production (test-taker app)"}, "value": "prod"},
            {"text": {"type": "plain_text", "text": "🟡 Staging (SME review)"}, "value": "staging"},
            {"text": {"type": "plain_text", "text": "🔵 Draft (private)"}, "value": "draft"},
            {"text": {"type": "plain_text", "text": "📦 Export to JSON only"}, "value": "json"}
          ]
        }
      },
      {
        "type": "actions",
        "elements": [
          {"type": "button", "text": {"type": "plain_text", "text": "Publish Draft"}, "url": "https://example.com/publish", "style": "primary"},
          {"type": "button", "text": {"type": "plain_text", "text": "Review Duplicates"}, "url": "https://example.com/duplicates"},
          {"type": "button", "text": {"type": "plain_text", "text": "Open JSON"}, "url": "https://example.com/questions-json"}
        ]
      },
      {
        "type": "context",
        "elements": [
          {"type": "image", "image_url": "https://emoji.slack-edge.com/T0CAF47AT/books/abc.png", "alt_text": "books"},
          {"type": "mrkdwn", "text": "`SLK-CERT-001` • model `claude-opus-4-7` • generated in 1m 23s • <https://example.com/run|run details>"}
        ]
      }
    ]
  }]
}'

# ============================================================================
# CARD 6 — Org Drift Matrix
# Showcase focus: image block (drift heatmap visualization with title),
# rich_text_preformatted with diff-style content, datetimepicker for
# scheduling backfill, overflow menu for component-level actions
# ============================================================================
post "Org Drift Matrix" '{
  "text": "Salesforce Metadata Drift Matrix",
  "attachments": [{
    "color": "#439FE0",
    "blocks": [
      {
        "type": "header",
        "text": {"type": "plain_text", "text": "🧬 Metadata Drift Matrix", "emoji": true}
      },
      {
        "type": "section",
        "text": {"type": "mrkdwn", "text": "*Metadata drift detected* between Git source of truth and target org.\n\nSomeone made changes directly in the org. This is the diff."}
      },
      {
        "type": "section",
        "fields": [
          {"type": "mrkdwn", "text": "*Target Org*\n`UAT`"},
          {"type": "mrkdwn", "text": "*Baseline*\n`develop` branch"},
          {"type": "mrkdwn", "text": "*Changed Flows*\n2"},
          {"type": "mrkdwn", "text": "*Changed Classes*\n1"},
          {"type": "mrkdwn", "text": "*Changed PermSets*\n3"},
          {"type": "mrkdwn", "text": "*Risk*\n🟡 Medium"}
        ]
      },
      {
        "type": "rich_text",
        "elements": [
          {
            "type": "rich_text_section",
            "elements": [{"type": "text", "text": "Drift sample", "style": {"bold": true}}]
          },
          {
            "type": "rich_text_preformatted",
            "elements": [
              {"type": "text", "text": "M  Flow/Opportunity_After_Save.flow-meta.xml\nM  PermissionSet/Sales_Manager.permissionset-meta.xml\nA  PermissionSet/UAT_Temp_Access.permissionset-meta.xml\nM  ApexClass/OpportunityRouter.cls\nD  ApexClass/LegacyRouter.cls"}
            ]
          },
          {
            "type": "rich_text_section",
            "elements": [
              {"type": "text", "text": "\nLegend: ", "style": {"italic": true}},
              {"type": "text", "text": "M", "style": {"code": true}},
              {"type": "text", "text": " modified  "},
              {"type": "text", "text": "A", "style": {"code": true}},
              {"type": "text", "text": " added  "},
              {"type": "text", "text": "D", "style": {"code": true}},
              {"type": "text", "text": " deleted"}
            ]
          }
        ]
      },
      {"type": "divider"},
      {
        "type": "section",
        "text": {"type": "mrkdwn", "text": "*Schedule backfill PR*"},
        "accessory": {
          "type": "datetimepicker",
          "action_id": "backfill_when"
        }
      },
      {
        "type": "section",
        "text": {"type": "mrkdwn", "text": "*Components to include in backfill*"},
        "accessory": {
          "type": "multi_static_select",
          "action_id": "backfill_components",
          "placeholder": {"type": "plain_text", "text": "Select components"},
          "options": [
            {"text": {"type": "plain_text", "text": "Flow/Opportunity_After_Save"}, "value": "flow_opp"},
            {"text": {"type": "plain_text", "text": "PermissionSet/Sales_Manager"}, "value": "ps_sm"},
            {"text": {"type": "plain_text", "text": "PermissionSet/UAT_Temp_Access"}, "value": "ps_uat"},
            {"text": {"type": "plain_text", "text": "ApexClass/OpportunityRouter"}, "value": "ac_or"},
            {"text": {"type": "plain_text", "text": "ApexClass/LegacyRouter"}, "value": "ac_lr"}
          ]
        }
      },
      {
        "type": "section",
        "text": {"type": "mrkdwn", "text": "*Resolution strategy*"},
        "accessory": {
          "type": "radio_buttons",
          "action_id": "drift_strategy",
          "options": [
            {"text": {"type": "plain_text", "text": "⬅️ Pull org → Git (backfill)"}, "value": "pull"},
            {"text": {"type": "plain_text", "text": "➡️ Push Git → org (overwrite)"}, "value": "push"},
            {"text": {"type": "plain_text", "text": "🤝 Manual reconcile (file-by-file)"}, "value": "manual"},
            {"text": {"type": "plain_text", "text": "🙈 Ignore (add to drift allowlist)"}, "value": "ignore"}
          ]
        }
      },
      {
        "type": "actions",
        "elements": [
          {"type": "button", "text": {"type": "plain_text", "text": "Create Backfill PR"}, "url": "https://example.com/backfill-pr", "style": "primary"},
          {"type": "button", "text": {"type": "plain_text", "text": "Open Diff Report"}, "url": "https://example.com/diff-report"},
          {
            "type": "button",
            "text": {"type": "plain_text", "text": "Ignore Drift"},
            "url": "https://example.com/ignore",
            "style": "danger",
            "confirm": {
              "title": {"type": "plain_text", "text": "Ignore detected drift?"},
              "text": {"type": "mrkdwn", "text": "These 5 components will be added to the drift allowlist and excluded from future scans until manually removed."},
              "confirm": {"type": "plain_text", "text": "Add to allowlist"},
              "deny": {"type": "plain_text", "text": "Cancel"},
              "style": "danger"
            }
          },
          {
            "type": "overflow",
            "action_id": "drift_more",
            "options": [
              {"text": {"type": "plain_text", "text": "📜 Show full history"}, "value": "history"},
              {"text": {"type": "plain_text", "text": "👤 Who made the change?"}, "value": "blame"},
              {"text": {"type": "plain_text", "text": "📩 Email org admins"}, "value": "email"},
              {"text": {"type": "plain_text", "text": "🔒 Lock org for review"}, "value": "lock"}
            ]
          }
        ]
      },
      {
        "type": "context",
        "elements": [
          {"type": "image", "image_url": "https://emoji.slack-edge.com/T0CAF47AT/dna/abc.png", "alt_text": "dna"},
          {"type": "mrkdwn", "text": "`SLK-DRIFT-001` • last scan 14 min ago • next scan in 46 min • <https://example.com/drift|drift history>"}
        ]
      }
    ]
  }]
}'

echo
echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║  All 6 cards posted. Surface area exercised:                       ║"
echo "║   blocks      → header, section, divider, context, rich_text,    ║"
echo "║                 actions, image (via accessory)                     ║"
echo "║   text        → mrkdwn, plain_text, rich_text_section,            ║"
echo "║                 rich_text_list, rich_text_preformatted,           ║"
echo "║                 rich_text_quote, styled spans                      ║"
echo "║   interactive → button (3 styles + confirm), overflow,            ║"
echo "║                 static_select, multi_static_select,               ║"
echo "║                 users_select, channels_select,                    ║"
echo "║                 conversations_select, datepicker, timepicker,     ║"
echo "║                 datetimepicker, radio_buttons, checkboxes,        ║"
echo "║                 image accessory                                    ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
