#!/usr/bin/env bash
set -euo pipefail
SECRET="${SLACK_SIGNING_SECRET:-94fdc2dd39e93280caedc825483c9b8f}"
URL="${SLACK_TEST_URL:-https://dream-dream-110-dev-ed.scratch.my.salesforce-sites.com/services/apexrest/slack/events}"
TEXT="${1:-help}"
TS=$(date +%s)
BODY="token=deprecated&team_id=T01EZ4J1T8F&team_domain=testworkspace&channel_id=C0000TEST&channel_name=general&user_id=U0000TEST&user_name=tester&command=%2Fcertgame&text=${TEXT}&api_app_id=A00000TEST&response_url=https%3A%2F%2Fhooks.slack.com%2Fcommands%2FT0%2F0%2Fx&trigger_id=trig-${TS}"
BASE="v0:${TS}:${BODY}"
SIG="v0=$(printf '%s' "$BASE" | openssl dgst -sha256 -hmac "$SECRET" | sed -E 's/^.* //')"
echo "URL=$URL"
echo "TS=$TS"
echo "SIG=$SIG"
echo "--- response ---"
curl -sS -w "\nHTTP %{http_code}\n" -X POST "$URL" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -H "X-Slack-Request-Timestamp: ${TS}" \
  -H "X-Slack-Signature: ${SIG}" \
  --data "${BODY}"
