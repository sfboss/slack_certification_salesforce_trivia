#!/usr/bin/env python3
"""Send a properly signed Slack slash command to the Salesforce Site endpoint."""
import hmac, hashlib, time, sys, urllib.parse, urllib.request

URL = "https://dream-dream-110-dev-ed.scratch.my.salesforce-sites.com/services/apexrest/slack/events"
SIGNING_SECRET = "94fdc2dd39e93280caedc825483c9b8f"

form = {
    "token": "deprecated",
    "team_id": "T01EZ4J1T8F",
    "team_domain": "testworkspace",
    "channel_id": "C0000TEST",
    "channel_name": "general",
    "user_id": "U0000TEST",
    "user_name": "tester",
    "command": "/certgame",
    "text": "help",
    "response_url": "https://hooks.slack.com/commands/T0/0/x",
    "trigger_id": f"trig-{int(time.time())}",
    "api_app_id": "A00000TEST",
}
body = urllib.parse.urlencode(form)
ts = str(int(time.time()))
basestring = f"v0:{ts}:{body}".encode()
sig = "v0=" + hmac.new(SIGNING_SECRET.encode(), basestring, hashlib.sha256).hexdigest()

req = urllib.request.Request(
    URL,
    data=body.encode(),
    method="POST",
    headers={
        "Content-Type": "application/x-www-form-urlencoded",
        "X-Slack-Request-Timestamp": ts,
        "X-Slack-Signature": sig,
    },
)
try:
    with urllib.request.urlopen(req, timeout=15) as r:
        print("HTTP", r.status)
        data = r.read().decode("utf-8", errors="replace")
        print("--- BODY (%d bytes) ---" % len(data))
        print(data[:4000])
except urllib.error.HTTPError as e:
    print("HTTP", e.code)
    print(e.read().decode("utf-8", errors="replace"))
