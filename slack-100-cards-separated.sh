#!/usr/bin/env bash
# ============================================================================
#  100 BREATHTAKINGLY COOL SLACK BLOCK KIT CARDS
#  Each is a self-contained curl one-liner.
#  Run individually, or `bash slack-100-cards.sh all` to fire every one.
#  Run `bash slack-50-cards.sh N` to fire card #N.
#  Run `bash slack-50-cards.sh N M` to fire a range.
#
#  ⚠️  ROTATE THIS WEBHOOK URL — it has been shared in plaintext.
# ============================================================================

WEBHOOK="${SLACK_WEBHOOK_URL:?Set SLACK_WEBHOOK_URL to your Slack Incoming Webhook URL}"
# Visual separation between cards when firing multiple examples.
# Keep the webhook out of source control; export it before running:
#   export SLACK_WEBHOOK_URL='https://hooks.slack.com/services/...'
CARD_NAMES=(
  ""
  "EMOJI BAR CHART — horizontal bars built from colored squares"
  "SPARKLINE ROW — unicode block sparklines per metric"
  "PROGRESS BAR — quest-style multi-step progress"
  "RANKED LEADERBOARD — medal emojis + tabular alignment"
  "STATUS DASHBOARD — colored dots as service health indicators"
  "RAINBOW THREAD — series of attachments, each a different color, telling a story"
  "WEATHER REPORT — fake meteorological summary for code metrics"
  "POLAROID STACK — image block as a 'photo from the field'"
  "CALENDAR HEATMAP — github-contributions style grid in monospace"
  "TYPEWRITER ANNOUNCEMENT — quoted serif-feeling editorial card"
  "TAROT CARD — fortune-telling for sprint planning"
  "TERMINAL STREAM — fake CI log output with timestamps and colors via emoji"
  "POLL RESULTS — visual horizontal bar poll with percentages"
  "RECEIPT — itemized totals like a grocery slip"
  "CHOOSE-YOUR-OWN-ADVENTURE — branching story prompts"
  "METRO SIGN — colored route badges as project tags"
  "PIXEL ART — emoji mosaic spelling something out"
  "STOCK TICKER — fake exchange row with up/down arrows"
  "INVOICE — formal-looking billing document"
  "ESCAPE ROOM — locked card with cryptic clues"
  "CARD GAME HAND — playing cards as task assignments"
  "AIRPORT BOARD — split-flap-style departure board"
  "BINGO CARD — 5x5 grid of completed tasks"
  "CRIME SCENE — bug investigation noir narrative"
  "RECIPE CARD — bug fix written as a recipe"
  "EMOJI SHRINE — wall of celebratory emojis around a single fact"
  "DUAL-PANEL DIFF — before/after fields side by side"
  "ASCII PIE CHART — quarter pie with emoji wedges"
  "RUNNING SCORE — sports scoreboard with quarter-by-quarter"
  "WAVEFORM — audio-style equalizer bars"
  "FORTUNE COOKIE — single witty line in attachment"
  "CHESS BOARD — game state with unicode chess pieces"
  "THERMOMETER — vertical gauge for any metric"
  "TELEGRAM — old-school short formal message"
  "MULTI-AVATAR ROW — context block with several thumbnail images"
  "CONFETTI WALL — wall of celebration emoji"
  "WANTED POSTER — old-west flavor for tech debt"
  "BARCODE — fake barcode for a release tag"
  "SKILL TREE — RPG-style progression unlocks"
  "CONCERT POSTER — bold typography vibe via emoji"
  "WHISPER NETWORK — series of small attachments, dialog style"
  "PROGRESS RING — circular progress via unicode"
  "MORSE CODE — secret message"
  "SUBWAY MAP — comma-separated journey"
  "ZINE PAGE — handmade pasted-together feel"
  "QR CODE — pixel block representation"
  "NESTED QUOTES — recursive blockquote thought-spiral"
  "HORIZON BAR — single-row terminal-style scrolling status"
  "MULTI-IMAGE GRID — image block grid (each is a separate block)"
  "CLOSING CREDITS — movie-style scrolling acknowledgment"
  "SALESFORCE DEPLOY WAR ROOM — release checklist with approval state"
  "ORG LIMITS RADAR — governor limit watch panel"
  "CERT QUESTION PROMPT — mock exam card with options"
  "CERT ANSWER REVEAL — explanation-first learning card"
  "SPACED REPETITION QUEUE — due cards by confidence"
  "PROMPT CHAIN RUNNER — staged AI workflow status"
  "AGENT LIFECYCLE — observe, plan, act, verify pipeline"
  "FILE TREE AUDIT — messy project folder report"
  "GOOGLE DRIVE ORGANIZER — batch triage plan"
  "GITHUB ACTIONS WALL — CI matrix badge board"
  "RELEASE NOTES DIGEST — product-update briefing"
  "RISK MATRIX — probability and impact grid"
  "ON-CALL HANDOFF — incident ownership card"
  "CUSTOMER INTAKE TRIAGE — lead urgency router"
  "LEGAL MATTER PIPELINE — fractional GC workflow"
  "DNS CUTOVER CHECKLIST — nameserver migration card"
  "SEO SERP WATCH — keyword rank movement"
  "CONTENT CALENDAR — faceless tutorial publishing slate"
  "YOUTUBE PIPELINE — REELFORGE render status"
  "COLAB NOTEBOOK RUN — cell-by-cell execution report"
  "SOQL INTELLIGENCE — org data profiling summary"
  "FLOW ERROR FORENSICS — failed interview analysis"
  "APEX COVERAGE MAP — class-by-class coverage"
  "PERMISSION MODEL SNAPSHOT — access layers explained"
  "SANDBOX REFRESH BOARD — environment readiness"
  "METADATA PACKAGE MANIFEST — package.xml preview"
  "BACKUP SNAPSHOT — nightly org backup result"
  "PR REVIEW RADAR — stuck reviews and blockers"
  "TECH DEBT AUCTION — bid points to remove legacy code"
  "ARCHITECTURE DECISION RECORD — ADR summary card"
  "PRODUCT HUNT LAUNCH ROOM — launch checklist"
  "SALES PIPELINE MINI CRM — opportunity stage card"
  "SUPPORT QUEUE HEAT — tickets by age and severity"
  "TEST DATA FACTORY — generated records summary"
  "LWC COMPONENT GALLERY — UI component inventory"
  "API CONTRACT CARD — endpoint health and schema drift"
  "VENDOR API BENEFITS CHECK — eligibility workflow result"
  "SLACK TRIVIA ROUND — timed certification game card"
  "TRIVIA LEADERBOARD — accuracy plus speed ranking"
  "KNOWLEDGE GAP MAP — learner struggle diagnosis"
  "ROADMAP TRAIN MAP — milestones as stations"
  "BATTLE CARD — competitor comparison layout"
  "EXECUTIVE BRIEF — one-screen decision memo"
  "COST BURN ALERT — cloud spend anomaly card"
  "DATA QUALITY SCORECARD — duplicates, stale records, missing fields"
  "AUTOMATION COLLISION MAP — flows, triggers, rules"
  "MIGRATION COMMAND CENTER — extract, transform, load status"
  "CLIENT WOW DEMO — before/after business impact"
  "DAILY RECAP DIGEST — machine activity timeline"
  "HALL OF FAME — best cards index and next experiments"
)

post_json() {
    curl -sS -X POST -H 'Content-type: application/json' --data "$1" "$WEBHOOK" >/dev/null
}

send_separator() {
    local i="$1"
    local n
    printf -v n "%02d" "$i"
    local title="${CARD_NAMES[$i]}"
    local json
    json=$(cat <<EOF
{"blocks":[{"type":"divider"},{"type":"header","text":{"type":"plain_text","text":"━━━━━━━━ Card $n / 100 ━━━━━━━━","emoji":true}},{"type":"section","text":{"type":"mrkdwn","text":"*$title*"}},{"type":"divider"}]}
EOF
)
    post_json "$json"
}


# ============================================================================
# 1. EMOJI BAR CHART — horizontal bars built from colored squares
# ============================================================================
card_01() {
curl -X POST -H 'Content-type: application/json' --data '{"blocks":[{"type":"header","text":{"type":"plain_text","text":"📊 Weekly deploys by service"}},{"type":"section","text":{"type":"mrkdwn","text":"```\nforcestack-db   🟦🟦🟦🟦🟦🟦🟦🟦🟦🟦🟦🟦  24\nharbor-portal   🟦🟦🟦🟦🟦🟦🟦🟦🟦       18\nrepocaddy       🟦🟦🟦🟦🟦🟦🟦           14\nslideforge      🟦🟦🟦🟦                  8\nbucci-web       🟦🟦                      4\n```"}},{"type":"context","elements":[{"type":"mrkdwn","text":"Week of May 16 · 68 total deploys · ▲ 22% vs prior week"}]}]}' "$WEBHOOK"
}

# ============================================================================
# 2. SPARKLINE ROW — unicode block sparklines per metric
# ============================================================================
card_02() {
curl -X POST -H 'Content-type: application/json' --data '{"blocks":[{"type":"header","text":{"type":"plain_text","text":"Production metrics · last 24h"}},{"type":"section","fields":[{"type":"mrkdwn","text":"*API calls*\n`▁▂▃▅▇▆▅▃▂▁▂▄▆█▇▅` 38.4K"},{"type":"mrkdwn","text":"*Error rate*\n`▁▁▁▁▁▂▁▁▁▁▁▁▂▁▁▁` 0.04%"},{"type":"mrkdwn","text":"*P95 latency*\n`▃▃▄▃▃▃▄▅▄▃▃▃▄▃▃▃` 142ms"},{"type":"mrkdwn","text":"*Active users*\n`▂▃▅▇█▇▆▅▄▃▃▄▆▇█▇` 1,847"}]}]}' "$WEBHOOK"
}

# ============================================================================
# 3. PROGRESS BAR — quest-style multi-step progress
# ============================================================================
card_03() {
curl -X POST -H 'Content-type: application/json' --data '{"blocks":[{"type":"section","text":{"type":"mrkdwn","text":"*🎯 Q2 OKR progress*\n\n`██████████████░░░░░░` *70%* — on track\n\n✅ Ship ForceStack v1\n✅ Land 3 design partners\n✅ Migrate Harbor to new stack\n🟡 Publish 12 MkDocs guides *(7 / 12)*\n⬜ Reach 500 GitHub stars"}}]}' "$WEBHOOK"
}

# ============================================================================
# 4. RANKED LEADERBOARD — medal emojis + tabular alignment
# ============================================================================
card_04() {
curl -X POST -H 'Content-type: application/json' --data '{"blocks":[{"type":"header","text":{"type":"plain_text","text":"🏆 Top contributors this sprint"}},{"type":"section","text":{"type":"mrkdwn","text":"```\n🥇  clayboss          47 PRs   ████████████  \n🥈  jane-codes         31 PRs   ████████      \n🥉  mike-dev           28 PRs   ███████       \n4.  sara-eng           19 PRs   █████         \n5.  tom-ops            14 PRs   ████          \n6.  lisa-arch           9 PRs   ██            \n```"}},{"type":"context","elements":[{"type":"mrkdwn","text":"Sprint 47 · closes Friday · :fire: hot streak: clayboss"}]}]}' "$WEBHOOK"
}

# ============================================================================
# 5. STATUS DASHBOARD — colored dots as service health indicators
# ============================================================================
card_05() {
curl -X POST -H 'Content-type: application/json' --data '{"blocks":[{"type":"header","text":{"type":"plain_text","text":"System status · all regions"}},{"type":"section","fields":[{"type":"mrkdwn","text":"🟢 *API Gateway*\nOperational"},{"type":"mrkdwn","text":"🟢 *Database*\n2ms avg"},{"type":"mrkdwn","text":"🟡 *Search index*\nDegraded · rebuilding"},{"type":"mrkdwn","text":"🟢 *Auth service*\nOperational"},{"type":"mrkdwn","text":"🟢 *File storage*\n99.99% uptime"},{"type":"mrkdwn","text":"🔴 *Email relay*\nDown since 09:14 ET"}]},{"type":"divider"},{"type":"context","elements":[{"type":"mrkdwn","text":"Last check: 10:42 ET · :arrows_counterclockwise: auto-refresh every 60s"}]}]}' "$WEBHOOK"
}

# ============================================================================
# 6. RAINBOW THREAD — series of attachments, each a different color, telling a story
# ============================================================================
card_06() {
curl -X POST -H 'Content-type: application/json' --data '{"attachments":[{"color":"#7C3AED","blocks":[{"type":"section","text":{"type":"mrkdwn","text":"*1. The request*\nClient calls API with malformed payload"}}]},{"color":"#36C5F0","blocks":[{"type":"section","text":{"type":"mrkdwn","text":"*2. The gateway*\nLambda validates and routes"}}]},{"color":"#2EB67D","blocks":[{"type":"section","text":{"type":"mrkdwn","text":"*3. The service*\nValidation fails, returns 400"}}]},{"color":"#ECB22E","blocks":[{"type":"section","text":{"type":"mrkdwn","text":"*4. The retry*\nClient retries with exponential backoff"}}]},{"color":"#E01E5A","blocks":[{"type":"section","text":{"type":"mrkdwn","text":"*5. The escalation*\nThird failure triggers PagerDuty"}}]}]}' "$WEBHOOK"
}

# ============================================================================
# 7. WEATHER REPORT — fake meteorological summary for code metrics
# ============================================================================
card_07() {
curl -X POST -H 'Content-type: application/json' --data '{"blocks":[{"type":"header","text":{"type":"plain_text","text":"⛅ Codebase weather report"}},{"type":"section","text":{"type":"mrkdwn","text":"*Currently:* 72°F and partly cloudy ☁️\n*Forecast:* Scattered tech debt with a chance of refactoring this weekend.\n\nA mild high-pressure system of green CI builds dominates the main branch. Lingering legacy code in the `/legacy` directory may produce isolated storms of `TODO` comments."}},{"type":"section","fields":[{"type":"mrkdwn","text":"*🌡️ Coverage*\n82% (steady)"},{"type":"mrkdwn","text":"*💨 Build winds*\n4m 12s, gusting"},{"type":"mrkdwn","text":"*🌧️ Bug precipitation*\n3 new this week"},{"type":"mrkdwn","text":"*☀️ Morale index*\nSunny ☀️☀️☀️"}]}]}' "$WEBHOOK"
}

# ============================================================================
# 8. POLAROID STACK — image block as a 'photo from the field'
# ============================================================================
card_08() {
curl -X POST -H 'Content-type: application/json' --data '{"blocks":[{"type":"section","text":{"type":"mrkdwn","text":"📸 *Eddie supervises the deploy* — _May 22, 9:42 AM_"}},{"type":"image","image_url":"https://placekitten.com/600/400","alt_text":"black cat watching code"},{"type":"context","elements":[{"type":"mrkdwn","text":"Eddie has given his approval. Shipping it."}]}]}' "$WEBHOOK"
}

# ============================================================================
# 9. CALENDAR HEATMAP — github-contributions style grid in monospace
# ============================================================================
card_09() {
curl -X POST -H 'Content-type: application/json' --data '{"blocks":[{"type":"header","text":{"type":"plain_text","text":"Commit activity · last 12 weeks"}},{"type":"section","text":{"type":"mrkdwn","text":"```\nMon  ⬜🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩\nTue  🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩\nWed  🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩\nThu  🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩\nFri  🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩🟩\nSat  ⬜⬜🟩⬜🟩⬜🟩⬜🟩⬜🟩⬜\nSun  ⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜\n     Feb  Mar  Apr  May\n```"}},{"type":"context","elements":[{"type":"mrkdwn","text":"431 commits · 🔥 7 day current streak · longest: 23 days"}]}]}' "$WEBHOOK"
}

# ============================================================================
# 10. TYPEWRITER ANNOUNCEMENT — quoted serif-feeling editorial card
# ============================================================================
card_10() {
curl -X POST -H 'Content-type: application/json' --data '{"attachments":[{"color":"#1A1D21","blocks":[{"type":"section","text":{"type":"mrkdwn","text":">  *EXTRA, EXTRA*\n>  _Read all about it_\n>\n> ForceStack DB ships its first 1,000 enriched company records this morning, sources confirm. The dataset, painstakingly assembled over six weeks by a solo developer in Washington, Utah, includes Salesforce stack composition data for Fortune 500 firms.\n>\n> _More on page A4._"}}]}]}' "$WEBHOOK"
}

# ============================================================================
# 11. TAROT CARD — fortune-telling for sprint planning
# ============================================================================
card_11() {
curl -X POST -H 'Content-type: application/json' --data '{"attachments":[{"color":"#4A154B","blocks":[{"type":"header","text":{"type":"plain_text","text":"🔮 Your sprint tarot reading"}},{"type":"section","text":{"type":"mrkdwn","text":"*The card drawn:*  🌙 _The Moon, reversed_\n\nThe path ahead is illuminated, but illusions linger. A task that appears straightforward conceals a deeper integration complexity. Trust your senior engineers. Beware Tuesday."}},{"type":"divider"},{"type":"section","fields":[{"type":"mrkdwn","text":"*Lucky service*\n`auth-gateway`"},{"type":"mrkdwn","text":"*Unlucky service*\n`legacy-billing`"},{"type":"mrkdwn","text":"*Velocity outlook*\n34 points"},{"type":"mrkdwn","text":"*Risk*\n🟡 Moderate"}]}]}]}' "$WEBHOOK"
}

# ============================================================================
# 12. TERMINAL STREAM — fake CI log output with timestamps and colors via emoji
# ============================================================================
card_12() {
curl -X POST -H 'Content-type: application/json' --data '{"blocks":[{"type":"header","text":{"type":"plain_text","text":"$ npm test"}},{"type":"section","text":{"type":"mrkdwn","text":"```\n[09:42:01] 🟢 ✓ auth.service.ts             (124ms)\n[09:42:02] 🟢 ✓ user.controller.ts          (89ms)\n[09:42:02] 🟢 ✓ rate-limiter.ts             (203ms)\n[09:42:03] 🔴 ✗ payment.processor.ts        FAIL\n[09:42:03]      Expected: 200  Received: 502\n[09:42:03]      at payment.test.ts:47\n[09:42:04] 🟢 ✓ notification.service.ts     (156ms)\n[09:42:05] 🟢 ✓ search.indexer.ts           (412ms)\n\n  Tests:  1 failed, 5 passed, 6 total\n  Time:   2.847s\n```"}},{"type":"context","elements":[{"type":"mrkdwn","text":"💡 1 test failed — `payment.processor.ts` is calling staging instead of mock"}]}]}' "$WEBHOOK"
}

# ============================================================================
# 13. POLL RESULTS — visual horizontal bar poll with percentages
# ============================================================================
card_13() {
curl -X POST -H 'Content-type: application/json' --data '{"blocks":[{"type":"header","text":{"type":"plain_text","text":"☕ Where should we get coffee?"}},{"type":"section","text":{"type":"mrkdwn","text":"`Blue Bottle      ` ███████████████████░░  *68%* — 17 votes\n`Stumptown        ` ███████░░░░░░░░░░░░░░  *24%* — 6 votes\n`Whatever is closer` █░░░░░░░░░░░░░░░░░░░  *8%* — 2 votes"}},{"type":"context","elements":[{"type":"mrkdwn","text":"25 votes · closed at 11:30 ET · winner declared 🏆"}]}]}' "$WEBHOOK"
}

# ============================================================================
# 14. RECEIPT — itemized totals like a grocery slip
# ============================================================================
card_14() {
curl -X POST -H 'Content-type: application/json' --data '{"blocks":[{"type":"section","text":{"type":"mrkdwn","text":"```\n  BOSS CONSULTING CO.\n  May 2026 AWS BILL\n  -------------------------\n  EC2 compute        $142.18\n  RDS postgres        $89.40\n  S3 storage          $12.07\n  CloudFront          $28.91\n  Lambda                $3.42\n  Data transfer       $17.55\n  -------------------------\n  SUBTOTAL           $293.53\n  Free tier credits  -$15.00\n  -------------------------\n  TOTAL              $278.53\n  \n  *** THANK YOU ***\n  *** COME AGAIN ***\n```"}}]}' "$WEBHOOK"
}

# ============================================================================
# 15. CHOOSE-YOUR-OWN-ADVENTURE — branching story prompts
# ============================================================================
card_15() {
curl -X POST -H 'Content-type: application/json' --data '{"blocks":[{"type":"header","text":{"type":"plain_text","text":"📖 The mystery of the failing flow"}},{"type":"section","text":{"type":"mrkdwn","text":"_You arrive at the org. The flow has been failing for three hours. Logs are sparse. The admin is on PTO. The CEO needs this fixed before her 2pm board meeting._\n\n*What do you do?*"}},{"type":"actions","elements":[{"type":"button","text":{"type":"plain_text","text":"🔍 Examine the debug logs"},"action_id":"path_a"},{"type":"button","text":{"type":"plain_text","text":"☎️ Call the admin"},"action_id":"path_b"},{"type":"button","text":{"type":"plain_text","text":"🔥 Just disable the flow"},"action_id":"path_c"},{"type":"button","text":{"type":"plain_text","text":"☕ Get coffee first"},"action_id":"path_d"}]}]}' "$WEBHOOK"
}

# ============================================================================
# 16. METRO SIGN — colored route badges as project tags
# ============================================================================
card_16() {
curl -X POST -H 'Content-type: application/json' --data '{"attachments":[{"color":"#E01E5A","blocks":[{"type":"section","text":{"type":"mrkdwn","text":"🚇 *Red Line — Production*\nNext deploy: 14 minutes · Service normal"}}]},{"color":"#36C5F0","blocks":[{"type":"section","text":{"type":"mrkdwn","text":"🚇 *Blue Line — Staging*\nNext deploy: 3 minutes · Service normal"}}]},{"color":"#2EB67D","blocks":[{"type":"section","text":{"type":"mrkdwn","text":"🚇 *Green Line — Development*\nContinuous · 47 deploys today"}}]},{"color":"#ECB22E","blocks":[{"type":"section","text":{"type":"mrkdwn","text":"🚇 *Yellow Line — QA*\n⚠️ Delays expected · waiting on test data refresh"}}]}]}' "$WEBHOOK"
}

# ============================================================================
# 17. PIXEL ART — emoji mosaic spelling something out
# ============================================================================
card_17() {
curl -X POST -H 'Content-type: application/json' --data '{"blocks":[{"type":"section","text":{"type":"mrkdwn","text":":white_large_square::large_green_square::large_green_square::large_green_square::white_large_square::white_large_square::large_green_square::white_large_square::white_large_square::large_green_square::white_large_square::white_large_square::large_green_square::large_green_square::large_green_square:\n:large_green_square::white_large_square::white_large_square::white_large_square::white_large_square::white_large_square::large_green_square::white_large_square::white_large_square::large_green_square::white_large_square::white_large_square::large_green_square::white_large_square::white_large_square:\n:large_green_square::white_large_square::large_green_square::large_green_square::white_large_square::white_large_square::large_green_square::large_green_square::large_green_square::large_green_square::white_large_square::white_large_square::large_green_square::large_green_square::white_large_square:\n:large_green_square::white_large_square::white_large_square::large_green_square::white_large_square::white_large_square::large_green_square::white_large_square::white_large_square::large_green_square::white_large_square::white_large_square::large_green_square::white_large_square::white_large_square:\n:white_large_square::large_green_square::large_green_square::large_green_square::white_large_square::white_large_square::large_green_square::white_large_square::white_large_square::large_green_square::white_large_square::white_large_square::large_green_square::large_green_square::large_green_square:"}},{"type":"context","elements":[{"type":"mrkdwn","text":"✅ All tests pass. Ship it."}]}]}' "$WEBHOOK"
}

# ============================================================================
# 18. STOCK TICKER — fake exchange row with up/down arrows
# ============================================================================
card_18() {
curl -X POST -H 'Content-type: application/json' --data '{"blocks":[{"type":"header","text":{"type":"plain_text","text":"📈 Repo Exchange · live"}},{"type":"section","text":{"type":"mrkdwn","text":"```\nSYMBOL          STARS   24H        \nFORCESTACK     142   ▲ +12  +9.2%   🟢\nREPOCADDY       89   ▲  +4  +4.7%   🟢\nSLIDEFORGE      67   ▼  -2  -2.9%   🔴\nORCHARD         41   ─   0   0.0%   ⚪\nHARBOR-CONS     38   ▲  +7 +22.5%   🚀\n```"}},{"type":"context","elements":[{"type":"mrkdwn","text":"Market opens at 09:30 commits ET · After-hours trading available in PR reviews"}]}]}' "$WEBHOOK"
}

# ============================================================================
# 19. INVOICE — formal-looking billing document
# ============================================================================
card_19() {
curl -X POST -H 'Content-type: application/json' --data '{"attachments":[{"color":"#0C447C","blocks":[{"type":"header","text":{"type":"plain_text","text":"INVOICE #2026-0517"}},{"type":"section","fields":[{"type":"mrkdwn","text":"*Bill to*\nHarbor Consumer Law\n_Attn: Accounts Payable_"},{"type":"mrkdwn","text":"*Date*\nMay 22, 2026\n*Due*\nJune 21, 2026"}]},{"type":"divider"},{"type":"section","text":{"type":"mrkdwn","text":"```\nSalesforce architecture review   $2,400\nWordPress migration               $1,800\nDNS/email reconfiguration           $600\nSEO audit & strategy              $1,200\n                              ---------\nSUBTOTAL                         $6,000\nDiscount (returning client)       -$300\n                              ---------\nTOTAL DUE                        $5,700\n```"}},{"type":"context","elements":[{"type":"mrkdwn","text":"Boss Consulting Co. · Washington, UT · Net 30"}]}]}]}' "$WEBHOOK"
}

# ============================================================================
# 20. ESCAPE ROOM — locked card with cryptic clues
# ============================================================================
card_20() {
curl -X POST -H 'Content-type: application/json' --data '{"attachments":[{"color":"#26215C","blocks":[{"type":"header","text":{"type":"plain_text","text":"🔐 You have entered the production org"}},{"type":"section","text":{"type":"mrkdwn","text":"_The change set will not deploy. Three locks remain._\n\n🔒 *Lock 1:* `Validation rule on Account` — _what would Boole do?_\n🔒 *Lock 2:* `Apex test class missing` — _coverage demands a witness_\n🔒 *Lock 3:* `Profile permissions` — _the admin holds the key_\n\nFind the keys. Escape the deployment."}},{"type":"context","elements":[{"type":"mrkdwn","text":"⏱️ 47 minutes remain · Difficulty: ★★★☆☆"}]}]}]}' "$WEBHOOK"
}

# ============================================================================
# 21. CARD GAME HAND — playing cards as task assignments
# ============================================================================
card_21() {
curl -X POST -H 'Content-type: application/json' --data '{"blocks":[{"type":"header","text":{"type":"plain_text","text":"🃏 Your sprint hand"}},{"type":"section","text":{"type":"mrkdwn","text":"```\n┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐\n│ A♠ │ │ K♥ │ │ Q♦ │ │ J♣ │ │ 10♠ │\n│     │ │     │ │     │ │     │ │     │\n│  ♠  │ │  ♥  │ │  ♦  │ │  ♣  │ │  ♠  │\n└─────┘ └─────┘ └─────┘ └─────┘ └─────┘\n```\n\n*♠ Ace —* Ship ForceStack v2 (8 pts)\n*♥ King —* Customer interview week (5 pts)\n*♦ Queen —* Redesign onboarding (3 pts)\n*♣ Jack —* Apex test backfill (3 pts)\n*♠ 10 —* MkDocs theme update (2 pts)\n\n_Total: 21 points · royal flush sprint_"}}]}' "$WEBHOOK"
}

# ============================================================================
# 22. AIRPORT BOARD — split-flap-style departure board
# ============================================================================
card_22() {
curl -X POST -H 'Content-type: application/json' --data '{"blocks":[{"type":"header","text":{"type":"plain_text","text":"✈️ Deploy departures"}},{"type":"section","text":{"type":"mrkdwn","text":"```\nFLIGHT   DESTINATION    GATE   STATUS       TIME\n────────────────────────────────────────────────\nDEV-201  staging-eu     B12    ✅ Boarding   10:45\nDEV-447  prod-na        A03    ⏳ Delayed    11:15\nDEV-512  prod-eu        A07    ✅ On time    11:30\nDEV-688  uat-na         C09    🚫 Cancelled  ----\nDEV-721  sandbox-dev    B04    ✅ Departed   10:12\n```"}}]}' "$WEBHOOK"
}

# ============================================================================
# 23. BINGO CARD — 5x5 grid of completed tasks
# ============================================================================
card_23() {
curl -X POST -H 'Content-type: application/json' --data '{"blocks":[{"type":"header","text":{"type":"plain_text","text":"🎯 Engineering bingo — May edition"}},{"type":"section","text":{"type":"mrkdwn","text":"```\n┌────┬────┬────┬────┬────┐\n│ ✅ │ ✅ │ ⬜ │ ✅ │ ⬜ │\n│PRs │CI  │OKRs│Lint│Docs│\n├────┼────┼────┼────┼────┤\n│ ✅ │ ✅ │ ✅ │ ⬜ │ ✅ │\n│Demo│1:1s│Code│Test│Bug │\n├────┼────┼────┼────┼────┤\n│ ✅ │ ⬜ │ ⭐ │ ✅ │ ✅ │\n│Plan│Spec│FREE│Ship│Pair│\n├────┼────┼────┼────┼────┤\n│ ⬜ │ ✅ │ ✅ │ ✅ │ ⬜ │\n│RFC │Std │Std │Rev │KPI │\n├────┼────┼────┼────┼────┤\n│ ✅ │ ✅ │ ⬜ │ ✅ │ ✅ │\n│Mtg │Hire│Vol │OOO │End │\n└────┴────┴────┴────┴────┘\n```\n\n_Diagonal win! 🏆_"}}]}' "$WEBHOOK"
}

# ============================================================================
# 24. CRIME SCENE — bug investigation noir narrative
# ============================================================================
card_24() {
curl -X POST -H 'Content-type: application/json' --data '{"attachments":[{"color":"#501313","blocks":[{"type":"header","text":{"type":"plain_text","text":"🚨 INCIDENT REPORT · #2026-0511"}},{"type":"section","text":{"type":"mrkdwn","text":">  _The flow was found dead at 03:42 ET. Cause of death: NullPointerException._\n>\n>  Witnesses report a recent merge to `main`. The trigger handler refuses to comment. Apex coverage was last seen at 79%._\n>\n>  We are looking for a developer with motive, opportunity, and access to the `Lead_Intake_Flow`."}},{"type":"section","fields":[{"type":"mrkdwn","text":"*Time of death*\n03:42:17 ET"},{"type":"mrkdwn","text":"*Last commit*\n`a7f3c91` · 03:38 ET"},{"type":"mrkdwn","text":"*Suspect*\nNew Apex trigger"},{"type":"mrkdwn","text":"*Lead detective*\n@clayboss"}]}]}]}' "$WEBHOOK"
}

# ============================================================================
# 25. RECIPE CARD — bug fix written as a recipe
# ============================================================================
card_25() {
curl -X POST -H 'Content-type: application/json' --data '{"blocks":[{"type":"header","text":{"type":"plain_text","text":"🍳 Recipe: Race condition fix"}},{"type":"section","text":{"type":"mrkdwn","text":"_Serves: 1 unblocked customer · Prep: 20m · Cook: 5m CI run_"}},{"type":"section","text":{"type":"mrkdwn","text":"*Ingredients*\n• 1 distributed lock (Redis preferred)\n• 1 idempotency key, freshly generated\n• 1 dash of exponential backoff\n• 2 retry attempts\n• A pinch of structured logging"}},{"type":"section","text":{"type":"mrkdwn","text":"*Instructions*\n1. Wrap the critical section in a lock. Cover and let rest 30 seconds.\n2. Fold in idempotency key, gently. Do not overmix.\n3. Add backoff to taste — start with 100ms.\n4. Let CI bake until golden brown 🟢\n5. Serve to production immediately."}},{"type":"context","elements":[{"type":"mrkdwn","text":"⭐⭐⭐⭐⭐ _Solved my problem!_ — every engineer eventually"}]}]}' "$WEBHOOK"
}

# ============================================================================
# 26. EMOJI SHRINE — wall of celebratory emojis around a single fact
# ============================================================================
card_26() {
curl -X POST -H 'Content-type: application/json' --data '{"blocks":[{"type":"section","text":{"type":"mrkdwn","text":"🎉🎊🎉🎊🎉🎊🎉🎊🎉🎊🎉🎊\n🎊                    🎊\n🎉   *1,000 STARS*    🎉\n🎊                    🎊\n🎉  forcestack-db has 🎉\n🎊  hit 1,000 GitHub  🎊\n🎉      stars! ⭐      🎉\n🎊                    🎊\n🎉🎊🎉🎊🎉🎊🎉🎊🎉🎊🎉🎊"}},{"type":"context","elements":[{"type":"mrkdwn","text":"From 0 to 1K in 47 days · :rocket: thank you to every contributor"}]}]}' "$WEBHOOK"
}

# ============================================================================
# 27. DUAL-PANEL DIFF — before/after fields side by side
# ============================================================================
card_27() {
curl -X POST -H 'Content-type: application/json' --data '{"blocks":[{"type":"header","text":{"type":"plain_text","text":"🔄 Config diff · production"}},{"type":"section","fields":[{"type":"mrkdwn","text":"*BEFORE*\n```\ntimeout: 30s\nretries: 3\npool_size: 10\nlog_level: info\n```"},{"type":"mrkdwn","text":"*AFTER*\n```\ntimeout: 60s\nretries: 5\npool_size: 25\nlog_level: debug\n```"}]},{"type":"context","elements":[{"type":"mrkdwn","text":"Diff applied by @clayboss · CR-2841 · rollback available for 24h"}]}]}' "$WEBHOOK"
}

# ============================================================================
# 28. ASCII PIE CHART — quarter pie with emoji wedges
# ============================================================================
card_28() {
curl -X POST -H 'Content-type: application/json' --data '{"blocks":[{"type":"header","text":{"type":"plain_text","text":"Where the time went · this week"}},{"type":"section","text":{"type":"mrkdwn","text":"🟦🟦🟦🟦🟦🟦🟦🟦  *Meetings* — 42%\n🟩🟩🟩🟩🟩       *Deep work* — 26%\n🟨🟨🟨🟨          *Slack/email* — 18%\n🟥🟥              *Interruptions* — 9%\n🟪                *Coffee runs* — 5%"}},{"type":"context","elements":[{"type":"mrkdwn","text":"40 hours tracked · :sob: deep work down 12% vs last week"}]}]}' "$WEBHOOK"
}

# ============================================================================
# 29. RUNNING SCORE — sports scoreboard with quarter-by-quarter
# ============================================================================
card_29() {
curl -X POST -H 'Content-type: application/json' --data '{"blocks":[{"type":"header","text":{"type":"plain_text","text":"🏈 PRs vs Bugs · sprint scoreboard"}},{"type":"section","text":{"type":"mrkdwn","text":"```\n            Q1    Q2    Q3    Q4   FINAL\nPRs SHIPPED  7    11     9     8     35\nBUGS FILED   3     2     4     1     10\n           ──────────────────────────────\n           PRs WIN BY 25\n```"}},{"type":"context","elements":[{"type":"mrkdwn","text":"🏆 Sprint MVP: @clayboss · 12 PRs · 0 reverts"}]}]}' "$WEBHOOK"
}

# ============================================================================
# 30. WAVEFORM — audio-style equalizer bars
# ============================================================================
card_30() {
curl -X POST -H 'Content-type: application/json' --data '{"blocks":[{"type":"header","text":{"type":"plain_text","text":"🎵 Now playing: production traffic"}},{"type":"section","text":{"type":"mrkdwn","text":"```\n▁▂▃▄▅▆▇█▇▆▅▄▃▂▁▂▃▅▇█▇▅▃▂▁▂▄▆█▇▅▃▂▁▂▃▅▇█\n```\n\n🎚️ *38,412 req/min* · peak in last hour: 51,883 · floor: 24,109"}},{"type":"context","elements":[{"type":"mrkdwn","text":"BPM: 642 · key: prod-na major · :musical_note: in the groove"}]}]}' "$WEBHOOK"
}

# ============================================================================
# 31. FORTUNE COOKIE — single witty line in attachment
# ============================================================================
card_31() {
curl -X POST -H 'Content-type: application/json' --data '{"attachments":[{"color":"#BA7517","blocks":[{"type":"section","text":{"type":"mrkdwn","text":"🥠 _Your fortune:_\n\n*The Apex trigger you have been avoiding will return to you threefold. Refactor while it is small.*\n\n_Lucky numbers: 42, 200, 503_"}}]}]}' "$WEBHOOK"
}

# ============================================================================
# 32. CHESS BOARD — game state with unicode chess pieces
# ============================================================================
card_32() {
curl -X POST -H 'Content-type: application/json' --data '{"blocks":[{"type":"header","text":{"type":"plain_text","text":"♟️ Architecture decision · move 14"}},{"type":"section","text":{"type":"mrkdwn","text":"```\n  a  b  c  d  e  f  g  h\n8 ♜  .  .  ♛  ♚  .  .  ♜  8\n7 ♟  ♟  ♟  .  .  ♟  ♟  ♟  7\n6 .  .  ♞  .  .  ♞  .  .  6\n5 .  .  .  .  ♟  .  .  .  5\n4 .  .  .  .  ♙  .  .  .  4\n3 .  .  ♘  .  .  ♘  .  .  3\n2 ♙  ♙  ♙  ♙  .  ♙  ♙  ♙  2\n1 ♖  .  ♗  ♕  ♔  ♗  .  ♖  1\n  a  b  c  d  e  f  g  h\n```"}},{"type":"section","text":{"type":"mrkdwn","text":"*Position:* Monolith ♔ vs. Microservices ♚ · _equal material, complex middlegame_"}},{"type":"context","elements":[{"type":"mrkdwn","text":"💭 Engine evaluation: +0.2 (slight edge to monolith) · suggests extracting auth service"}]}]}' "$WEBHOOK"
}

# ============================================================================
# 33. THERMOMETER — vertical gauge for any metric
# ============================================================================
card_33() {
curl -X POST -H 'Content-type: application/json' --data '{"blocks":[{"type":"header","text":{"type":"plain_text","text":"🌡️ Tech debt thermometer"}},{"type":"section","text":{"type":"mrkdwn","text":"```\n  🔴  CRITICAL\n  🔴   ╔══╗\n  🟠   ║██║   ◄── you are here (78%)\n  🟠   ║██║\n  🟡   ║██║\n  🟡   ║██║\n  🟢   ║██║\n  🟢   ║██║\n       ║██║\n       ║██║\n       ╚══╝\n       SAFE\n```"}},{"type":"context","elements":[{"type":"mrkdwn","text":"⚠️ Sustained > 70% for 23 days · consider a debt-paydown sprint"}]}]}' "$WEBHOOK"
}

# ============================================================================
# 34. TELEGRAM — old-school short formal message
# ============================================================================
card_34() {
curl -X POST -H 'Content-type: application/json' --data '{"attachments":[{"color":"#5F5E5A","blocks":[{"type":"section","text":{"type":"mrkdwn","text":"```\n═══════════════════════════════\nTELEGRAM       FROM: DEVOPS\n═══════════════════════════════\n\nDEPLOY COMPLETE STOP\nALL TESTS PASS STOP\nCOVERAGE NINETY ONE PERCENT STOP\nNO ROLLBACK REQUIRED STOP\nCELEBRATE ACCORDINGLY STOP\n\n               END OF MESSAGE\n═══════════════════════════════\n```"}}]}]}' "$WEBHOOK"
}

# ============================================================================
# 35. MULTI-AVATAR ROW — context block with several thumbnail images
# ============================================================================
card_35() {
curl -X POST -H 'Content-type: application/json' --data '{"blocks":[{"type":"section","text":{"type":"mrkdwn","text":"*🚢 Ready for code review*\n\nPR #2841: _Add VOB intake routing to Lead conversion flow_"}},{"type":"context","elements":[{"type":"image","image_url":"https://placekitten.com/40/40","alt_text":"reviewer 1"},{"type":"image","image_url":"https://placekitten.com/41/41","alt_text":"reviewer 2"},{"type":"image","image_url":"https://placekitten.com/42/42","alt_text":"reviewer 3"},{"type":"mrkdwn","text":"_3 reviewers assigned · 2 approvals needed · oldest review request: 4h_"}]}]}' "$WEBHOOK"
}

# ============================================================================
# 36. CONFETTI WALL — wall of celebration emoji
# ============================================================================
card_36() {
curl -X POST -H 'Content-type: application/json' --data '{"blocks":[{"type":"section","text":{"type":"mrkdwn","text":":tada::confetti_ball::partying_face::sparkles::tada::confetti_ball::partying_face::sparkles::tada:\n:confetti_ball::partying_face::sparkles::tada::confetti_ball::partying_face::sparkles::tada::confetti_ball:\n:partying_face::sparkles::tada::confetti_ball::partying_face::sparkles::tada::confetti_ball::partying_face:\n\n*🎂 Eddie the cat is 7 today!*\n\n_The official mascot of Boss Consulting Co. has reached middle age with grace, dignity, and an unbroken track record of approving every deployment._"}}]}' "$WEBHOOK"
}

# ============================================================================
# 37. WANTED POSTER — old-west flavor for tech debt
# ============================================================================
card_37() {
curl -X POST -H 'Content-type: application/json' --data '{"attachments":[{"color":"#712B13","blocks":[{"type":"header","text":{"type":"plain_text","text":"🤠 WANTED · DEAD OR DEPRECATED"}},{"type":"section","text":{"type":"mrkdwn","text":">  *`LegacyBillingService.cls`*\n>\n>  Last seen terrorizing the `prod-na` org in *September 2019*. Known accomplices: `BillingHelper.cls`, `BillingUtil.cls`, three triggers, and one rogue scheduled job.\n>\n>  *REWARD: One sprint of clean code · paid on merge.*"}},{"type":"context","elements":[{"type":"mrkdwn","text":"⚖️ If you spot this class, report to @clayboss · do not approach without test coverage"}]}]}]}' "$WEBHOOK"
}

# ============================================================================
# 38. BARCODE — fake barcode for a release tag
# ============================================================================
card_38() {
curl -X POST -H 'Content-type: application/json' --data '{"blocks":[{"type":"section","text":{"type":"mrkdwn","text":"```\n   ███ █  ██  █ ███ █ █ ██  █ ██ █  ███ █\n   ███ █  ██  █ ███ █ █ ██  █ ██ █  ███ █\n   ███ █  ██  █ ███ █ █ ██  █ ██ █  ███ █\n   ███ █  ██  █ ███ █ █ ██  █ ██ █  ███ █\n   ███ █  ██  █ ███ █ █ ██  █ ██ █  ███ █\n   v 2 . 1 4 . 3 - 2 0 2 6 - 0 5 - 2 2\n```\n\n📦 Scanned at the loading dock · routed to *prod-na*"}}]}' "$WEBHOOK"
}

# ============================================================================
# 39. SKILL TREE — RPG-style progression unlocks
# ============================================================================
card_39() {
curl -X POST -H 'Content-type: application/json' --data '{"blocks":[{"type":"header","text":{"type":"plain_text","text":"🌳 Salesforce skill tree · @clayboss"}},{"type":"section","text":{"type":"mrkdwn","text":"```\n         ⭐ ARCHITECT (locked — 2 prereqs left)\n         /  \\\n        /    \\\n   ✅ APEX    ✅ FLOW\n      |         |\n   ✅ SOQL   ✅ PROCESS\n      |         |\n   ✅ DML    ✅ TRIGGER\n      \\        /\n       \\      /\n     ✅ FUNDAMENTALS\n```"}},{"type":"section","fields":[{"type":"mrkdwn","text":"*Skills unlocked*\n8 / 10"},{"type":"mrkdwn","text":"*XP*\n12,847"},{"type":"mrkdwn","text":"*Next unlock*\nLightning Web Components"},{"type":"mrkdwn","text":"*Class*\nFull-stack consultant"}]}]}' "$WEBHOOK"
}

# ============================================================================
# 40. CONCERT POSTER — bold typography vibe via emoji
# ============================================================================
card_40() {
curl -X POST -H 'Content-type: application/json' --data '{"attachments":[{"color":"#A32D2D","blocks":[{"type":"header","text":{"type":"plain_text","text":"🎤 LIVE TONIGHT · ONE NIGHT ONLY"}},{"type":"section","text":{"type":"mrkdwn","text":"*⚡ PROD DEPLOY ⚡*\n_featuring_\n\n🎸 *v2.14.3* on lead vocals\n🥁 *CI/CD pipeline* on drums\n🎹 *feature flags* on synth\n🎺 *rollback plan* on horns\n\n📍 *prod-na · 10:00 PM ET · doors at 9:45*"}},{"type":"context","elements":[{"type":"mrkdwn","text":"🎟️ All-access pass: deploy approval from @clayboss · merch table by the rollback button"}]}]}]}' "$WEBHOOK"
}

# ============================================================================
# 41. WHISPER NETWORK — series of small attachments, dialog style
# ============================================================================
card_41() {
curl -X POST -H 'Content-type: application/json' --data '{"attachments":[{"color":"#888780","blocks":[{"type":"section","text":{"type":"mrkdwn","text":"_psst..._ have you seen the staging logs?"}}]},{"color":"#888780","blocks":[{"type":"section","text":{"type":"mrkdwn","text":"_yeah... 504s every 12 minutes... like clockwork_"}}]},{"color":"#888780","blocks":[{"type":"section","text":{"type":"mrkdwn","text":"_someone deployed a cron job that hits an unresponsive vendor API..._"}}]},{"color":"#E24B4A","blocks":[{"type":"section","text":{"type":"mrkdwn","text":"*💥 found it: `vendor-sync.cron` — disabling now*"}}]}]}' "$WEBHOOK"
}

# ============================================================================
# 42. PROGRESS RING — circular progress via unicode
# ============================================================================
card_42() {
curl -X POST -H 'Content-type: application/json' --data '{"blocks":[{"type":"header","text":{"type":"plain_text","text":"⏱️ Daily standup countdown"}},{"type":"section","text":{"type":"mrkdwn","text":"```\n        ◜◝\n      ◜    ◝\n    ◜  09:42 ◝\n   ◜          ◝\n   ◟          ◞\n    ◟        ◞\n      ◟    ◞\n        ◟◞\n```\n\n*18 minutes until standup* · ☕ time for one more coffee"}}]}' "$WEBHOOK"
}

# ============================================================================
# 43. MORSE CODE — secret message
# ============================================================================
card_43() {
curl -X POST -H 'Content-type: application/json' --data '{"blocks":[{"type":"section","text":{"type":"mrkdwn","text":"📡 *Incoming transmission*\n\n```\n... .... .. .--.    .. -    ─    ─    ─\nS H I P     I T\n```\n\n_Message decoded · forwarded to release manager_"}}]}' "$WEBHOOK"
}

# ============================================================================
# 44. SUBWAY MAP — comma-separated journey
# ============================================================================
card_44() {
curl -X POST -H 'Content-type: application/json' --data '{"blocks":[{"type":"header","text":{"type":"plain_text","text":"🚇 Request lifecycle journey"}},{"type":"section","text":{"type":"mrkdwn","text":"`Client` ───● `CDN` ───● `Gateway` ───● `Auth` ───● `Service` ───● `DB` ───● `Cache` ───● 🏁\n\n*Total transit time:* 47ms · *delayed at:* `Auth` (~12ms longer than usual)"}},{"type":"context","elements":[{"type":"mrkdwn","text":"Stops with congestion: 1 of 7 · :wrench: maintenance scheduled tonight at Auth station"}]}]}' "$WEBHOOK"
}

# ============================================================================
# 45. ZINE PAGE — handmade pasted-together feel
# ============================================================================
card_45() {
curl -X POST -H 'Content-type: application/json' --data '{"attachments":[{"color":"#D4537E","blocks":[{"type":"header","text":{"type":"plain_text","text":"✂️  THE WEEKLY ZINE  ✂️"}},{"type":"section","text":{"type":"mrkdwn","text":"_issue #14 · cut & pasted with love in Washington, Utah_\n\n>  *INSIDE THIS ISSUE*\n>  ─────────────────\n>  📰 _why your Apex trigger hates you_\n>  📰 _flow orchestration: a manifesto_\n>  📰 _eddie the cat reviews IDEs_\n>  📰 _interview: a developer who still uses Workbench_\n>\n>  *plus:* recipes, horoscopes, classifieds"}},{"type":"context","elements":[{"type":"mrkdwn","text":"📬 Subscribe at boss-consulting.zine · paper only · no PDFs"}]}]}]}' "$WEBHOOK"
}

# ============================================================================
# 46. QR CODE — pixel block representation
# ============================================================================
card_46() {
curl -X POST -H 'Content-type: application/json' --data '{"blocks":[{"type":"section","text":{"type":"mrkdwn","text":"```\n█████████ ███ █████████\n█ ▄▄▄▄▄ █ █▄█ █ ▄▄▄▄▄ █\n█ █   █ █▄▀  ▄█ █   █ █\n█ █▄▄▄█ █ █▄█ █ █▄▄▄█ █\n█▄▄▄▄▄▄▄█ ▀▄▀ █▄▄▄▄▄▄▄█\n█▄▄▀▄▄ ▄ ▀█▄█  ▄ █ ▄▀▄█\n█  █▀▀▄▄  ▄▀▄  █▀█ ▀ ▄█\n█▄▄▄▄▄▄▄█▀█▄▄ ▄▄▀█▄ ▄ █\n█ ▄▄▄▄▄ █ █▄▀ █▄▄ ▄▄▄▄█\n█ █   █ █▀█ ▀▀▄  █▀ ▀▄█\n█ █▄▄▄█ █▄▀ ▄▄▄▄ ▄  ▄ █\n█▄▄▄▄▄▄▄█▄█▄█▄█▄█▄█▄▄▄█\n```\n📱 *Scan to join standup* — link expires in 5 minutes"}}]}' "$WEBHOOK"
}

# ============================================================================
# 47. NESTED QUOTES — recursive blockquote thought-spiral
# ============================================================================
card_47() {
curl -X POST -H 'Content-type: application/json' --data '{"blocks":[{"type":"section","text":{"type":"mrkdwn","text":"*🧠 PR review · the customer ticket says:*\n\n>  _and the engineer wrote:_\n>  \n>  >  _and the QA team responded:_\n>  >  \n>  >  >  _and the customer clarified:_\n>  >  >  \n>  >  >  >  _\"actually we wanted the OTHER button to do that\"_\n\n*Resolution:* close ticket, open new ticket, schedule call."}}]}' "$WEBHOOK"
}

# ============================================================================
# 48. HORIZON BAR — single-row terminal-style scrolling status
# ============================================================================
card_48() {
curl -X POST -H 'Content-type: application/json' --data '{"blocks":[{"type":"section","text":{"type":"mrkdwn","text":"`▶ 🟢 PROD: OK · 🟢 STAGING: OK · 🟡 QA: REBUILDING · 🟢 DEV: OK · 🟢 SANDBOX: OK · 🟢 EU: OK · 🟢 NA: OK · 🟢 APAC: OK ◀`"}},{"type":"context","elements":[{"type":"mrkdwn","text":"Marquee updated every 30s · click :arrows_counterclockwise: in thread to refresh"}]}]}' "$WEBHOOK"
}

# ============================================================================
# 49. MULTI-IMAGE GRID — image block grid (each is a separate block)
# ============================================================================
card_49() {
curl -X POST -H 'Content-type: application/json' --data '{"blocks":[{"type":"header","text":{"type":"plain_text","text":"📸 Design review · 4 mockups"}},{"type":"image","title":{"type":"plain_text","text":"Option A — Navy maritime"},"image_url":"https://placekitten.com/400/250","alt_text":"navy maritime mockup"},{"type":"image","title":{"type":"plain_text","text":"Option B — Swiss modernist"},"image_url":"https://placekitten.com/401/250","alt_text":"swiss modernist mockup"},{"type":"image","title":{"type":"plain_text","text":"Option C — Brutalist"},"image_url":"https://placekitten.com/402/250","alt_text":"brutalist mockup"},{"type":"image","title":{"type":"plain_text","text":"Option D — Editorial dark"},"image_url":"https://placekitten.com/403/250","alt_text":"editorial dark mockup"},{"type":"context","elements":[{"type":"mrkdwn","text":"Vote with 🅰️ 🅱️ 🅲 🅳 on this message"}]}]}' "$WEBHOOK"
}

# ============================================================================
# 50. CLOSING CREDITS — movie-style scrolling acknowledgment
# ============================================================================
card_50() {
curl -X POST -H 'Content-type: application/json' --data '{"attachments":[{"color":"#1A1D21","blocks":[{"type":"header","text":{"type":"plain_text","text":"🎬 FORCESTACK DB v1.0"}},{"type":"section","text":{"type":"mrkdwn","text":"_a Boss Consulting Co. production_\n\n```\n        DIRECTED BY\n         clayboss\n\n        WRITTEN BY\n         clayboss\n        & claude (uncredited)\n\n     EXECUTIVE PRODUCER\n         eddie (cat)\n\n     CINEMATOGRAPHY\n         GitHub Actions\n\n        MUSIC BY\n         the sound of\n        a passing CI run\n\n     SPECIAL THANKS\n         every Stack Overflow\n         answer from 2014\n```"}},{"type":"context","elements":[{"type":"mrkdwn","text":"🎞️ No Apex tests were harmed in the making of this release · stay through the credits"}]}]}]}' "$WEBHOOK"
}


# ============================================================================
# 51. SALESFORCE DEPLOY WAR ROOM — release checklist with approval state
# ============================================================================
card_51() {
post_json "{\"attachments\": [{\"color\": \"#00A1E0\", \"blocks\": [{\"type\": \"header\", \"text\": {\"type\": \"plain_text\", \"text\": \"🚀 Salesforce Deploy War Room\", \"emoji\": true}}, {\"type\": \"section\", \"text\": {\"type\": \"mrkdwn\", \"text\": \"*Release:* `VOB Intake Routing v1.4`\\n*Target:* Production · *Window:* 10:00 PM ET\\n\\n✅ Apex tests queued\\n✅ Package validated in UAT\\n🟡 Product owner approval pending\\n⬜ Post-deploy smoke test\"}}, {\"type\": \"section\", \"fields\": [{\"type\": \"mrkdwn\", \"text\": \"*Validation*\\n91% coverage\"}, {\"type\": \"mrkdwn\", \"text\": \"*Rollback*\\nGit tag + destructive manifest\"}, {\"type\": \"mrkdwn\", \"text\": \"*Risk*\\n🟡 Medium\"}, {\"type\": \"mrkdwn\", \"text\": \"*Owner*\\n@clayboss\"}]}, {\"type\": \"context\", \"elements\": [{\"type\": \"mrkdwn\", \"text\": \"Use this as the preflight card before a Salesforce deployment.\"}]}]}]}"
}

# ============================================================================
# 52. ORG LIMITS RADAR — governor limit watch panel
# ============================================================================
card_52() {
post_json "{\"blocks\": [{\"type\": \"header\", \"text\": {\"type\": \"plain_text\", \"text\": \"📡 Org limits radar\", \"emoji\": true}}, {\"type\": \"section\", \"text\": {\"type\": \"mrkdwn\", \"text\": \"```\\nAPI DAILY LIMIT      ███████████░░░░  72%\\nASYNC APEX JOBS      █████░░░░░░░░░░  34%\\nDATA STORAGE         █████████████░░  86%\\nFILE STORAGE         ████░░░░░░░░░░░  28%\\nEMAIL INVOCATIONS    ██░░░░░░░░░░░░░  12%\\n```\"}}, {\"type\": \"context\", \"elements\": [{\"type\": \"mrkdwn\", \"text\": \"⚠️ Data storage is the only watch item. Next check: 60 minutes.\"}]}]}"
}

# ============================================================================
# 53. CERT QUESTION PROMPT — mock exam card with options
# ============================================================================
card_53() {
post_json "{\"blocks\": [{\"type\": \"header\", \"text\": {\"type\": \"plain_text\", \"text\": \"🧪 Salesforce Admin Mock Question\", \"emoji\": true}}, {\"type\": \"section\", \"text\": {\"type\": \"mrkdwn\", \"text\": \"*Topic:* Security & Access\\n\\nA user can see an Account record but cannot see a related custom object child record. OWD for the child object is Private. What should you check first?\"}}, {\"type\": \"actions\", \"elements\": [{\"type\": \"button\", \"text\": {\"type\": \"plain_text\", \"text\": \"A. Profile CRUD\"}, \"action_id\": \"a\"}, {\"type\": \"button\", \"text\": {\"type\": \"plain_text\", \"text\": \"B. Role hierarchy\"}, \"action_id\": \"b\"}, {\"type\": \"button\", \"text\": {\"type\": \"plain_text\", \"text\": \"C. Sharing rules\"}, \"action_id\": \"c\"}, {\"type\": \"button\", \"text\": {\"type\": \"plain_text\", \"text\": \"D. Page layout\"}, \"action_id\": \"d\"}]}, {\"type\": \"context\", \"elements\": [{\"type\": \"mrkdwn\", \"text\": \"Difficulty: Intermediate · Exam lens: diagnose record access before UI assumptions.\"}]}]}"
}

# ============================================================================
# 54. CERT ANSWER REVEAL — explanation-first learning card
# ============================================================================
card_54() {
post_json "{\"attachments\": [{\"color\": \"#2EB67D\", \"blocks\": [{\"type\": \"header\", \"text\": {\"type\": \"plain_text\", \"text\": \"✅ Answer Reveal\", \"emoji\": true}}, {\"type\": \"section\", \"text\": {\"type\": \"mrkdwn\", \"text\": \"*Correct answer:* C. Sharing rules\\n\\nThe user already has visibility to the parent Account. The child object is private, so record-level access for that object must be granted separately unless controlled by parent or otherwise shared.\"}}, {\"type\": \"divider\"}, {\"type\": \"section\", \"text\": {\"type\": \"mrkdwn\", \"text\": \"*Why not the others?*\\n• Profile CRUD decides object access, not a specific child record.\\n• Role hierarchy may help, but only if ownership and hierarchy grant access.\\n• Page layout does not grant record visibility.\"}}, {\"type\": \"context\", \"elements\": [{\"type\": \"mrkdwn\", \"text\": \"This card format is good for Slack-based certification coaching.\"}]}]}]}"
}

# ============================================================================
# 55. SPACED REPETITION QUEUE — due cards by confidence
# ============================================================================
card_55() {
post_json "{\"blocks\": [{\"type\": \"header\", \"text\": {\"type\": \"plain_text\", \"text\": \"🧠 Study queue due now\", \"emoji\": true}}, {\"type\": \"section\", \"fields\": [{\"type\": \"mrkdwn\", \"text\": \"*Security model*\\n12 due · confidence 61%\"}, {\"type\": \"mrkdwn\", \"text\": \"*Flow Builder*\\n7 due · confidence 74%\"}, {\"type\": \"mrkdwn\", \"text\": \"*Reports/Dashboards*\\n4 due · confidence 88%\"}, {\"type\": \"mrkdwn\", \"text\": \"*Data management*\\n9 due · confidence 57%\"}]}, {\"type\": \"section\", \"text\": {\"type\": \"mrkdwn\", \"text\": \"`██████████░░░░░░░░░░` *52% daily review complete*\"}}, {\"type\": \"context\", \"elements\": [{\"type\": \"mrkdwn\", \"text\": \"Recommended next action: hit lowest-confidence cards first.\"}]}]}"
}

# ============================================================================
# 56. PROMPT CHAIN RUNNER — staged AI workflow status
# ============================================================================
card_56() {
post_json "{\"blocks\": [{\"type\": \"header\", \"text\": {\"type\": \"plain_text\", \"text\": \"🔗 Prompt chain runner\", \"emoji\": true}}, {\"type\": \"section\", \"text\": {\"type\": \"mrkdwn\", \"text\": \"```\\n1. Intake context       ✅ complete\\n2. Generate outline     ✅ complete\\n3. Create code plan     ✅ complete\\n4. Write implementation 🟡 running\\n5. Validate output      ⬜ waiting\\n6. Package files        ⬜ waiting\\n```\"}}, {\"type\": \"context\", \"elements\": [{\"type\": \"mrkdwn\", \"text\": \"Agent mode: deterministic · output target: runnable repo scaffold\"}]}]}"
}

# ============================================================================
# 57. AGENT LIFECYCLE — observe, plan, act, verify pipeline
# ============================================================================
card_57() {
post_json "{\"attachments\": [{\"color\": \"#7C3AED\", \"blocks\": [{\"type\": \"header\", \"text\": {\"type\": \"plain_text\", \"text\": \"🤖 Agent lifecycle\", \"emoji\": true}}, {\"type\": \"section\", \"text\": {\"type\": \"mrkdwn\", \"text\": \"`OBSERVE` → `PLAN` → `ACT` → `VERIFY` → `REPORT`\\n\\n*Current phase:* VERIFY\\n*Evidence collected:* 17 files scanned, 4 tests executed, 2 screenshots captured\\n*Confidence:* 87%\"}}, {\"type\": \"context\", \"elements\": [{\"type\": \"mrkdwn\", \"text\": \"Useful for long-running local agents or Codex-style repo tasks.\"}]}]}]}"
}

# ============================================================================
# 58. FILE TREE AUDIT — messy project folder report
# ============================================================================
card_58() {
post_json "{\"blocks\": [{\"type\": \"header\", \"text\": {\"type\": \"plain_text\", \"text\": \"🌲 File tree audit\", \"emoji\": true}}, {\"type\": \"section\", \"text\": {\"type\": \"mrkdwn\", \"text\": \"```\\nprojects/\\n├── salesforce-slack-trivia/ ✅ README + repo\\n├── old-demo-final-v3/       ⚠️ no README\\n├── untitled folder 17/      🔴 loose files\\n├── bucci-demo/              ✅ deployable\\n└── reel-forge-tests/        🟡 missing .env.example\\n```\"}}, {\"type\": \"context\", \"elements\": [{\"type\": \"mrkdwn\", \"text\": \"Rule: one project, one folder, one README, one repo when it matters.\"}]}]}"
}

# ============================================================================
# 59. GOOGLE DRIVE ORGANIZER — batch triage plan
# ============================================================================
card_59() {
post_json "{\"blocks\": [{\"type\": \"header\", \"text\": {\"type\": \"plain_text\", \"text\": \"🗂️ Drive organizer run\", \"emoji\": true}}, {\"type\": \"section\", \"fields\": [{\"type\": \"mrkdwn\", \"text\": \"*Scanned*\\n1,284 files\"}, {\"type\": \"mrkdwn\", \"text\": \"*Likely duplicates*\\n87\"}, {\"type\": \"mrkdwn\", \"text\": \"*No parent project*\\n214\"}, {\"type\": \"mrkdwn\", \"text\": \"*README missing*\\n32 folders\"}]}, {\"type\": \"section\", \"text\": {\"type\": \"mrkdwn\", \"text\": \"*Suggested folders:*\\n`/Salesforce Apps` · `/Colab Notebooks` · `/Client Demos` · `/Prompt Libraries` · `/Archive - Cold Storage`\"}}, {\"type\": \"context\", \"elements\": [{\"type\": \"mrkdwn\", \"text\": \"Next pass: export CSV inventory and create move plan before modifying Drive.\"}]}]}"
}

# ============================================================================
# 60. GITHUB ACTIONS WALL — CI matrix badge board
# ============================================================================
card_60() {
post_json "{\"blocks\": [{\"type\": \"header\", \"text\": {\"type\": \"plain_text\", \"text\": \"🧱 GitHub Actions wall\", \"emoji\": true}}, {\"type\": \"section\", \"text\": {\"type\": \"mrkdwn\", \"text\": \"```\\nrepo              lint   tests  package  deploy\\n──────────────────────────────────────────────\\nslack-trivia       ✅     ✅      ✅       🟡\\nreelforge          ✅     🔴      ⬜       ⬜\\nsoql-workbench     ✅     ✅      ✅       ✅\\nbucci-portal       ✅     ✅      🟡       ⬜\\n```\"}}, {\"type\": \"context\", \"elements\": [{\"type\": \"mrkdwn\", \"text\": \"Failure cluster: REELFORGE media render tests timing out.\"}]}]}"
}

# ============================================================================
# 61. RELEASE NOTES DIGEST — product-update briefing
# ============================================================================
card_61() {
post_json "{\"blocks\": [{\"type\": \"header\", \"text\": {\"type\": \"plain_text\", \"text\": \"📰 Release notes digest\", \"emoji\": true}}, {\"type\": \"section\", \"text\": {\"type\": \"mrkdwn\", \"text\": \"*Spring release watchlist*\\n\\n• Flow Builder: new debug visibility for subflows\\n• Apex: async limits unchanged\\n• Reports: dashboard filters improved\\n• Einstein: new prompt template governance controls\"}}, {\"type\": \"context\", \"elements\": [{\"type\": \"mrkdwn\", \"text\": \"Format idea: post this weekly for admins who do not read 600-page release notes.\"}]}]}"
}

# ============================================================================
# 62. RISK MATRIX — probability and impact grid
# ============================================================================
card_62() {
post_json "{\"blocks\": [{\"type\": \"header\", \"text\": {\"type\": \"plain_text\", \"text\": \"⚠️ Delivery risk matrix\", \"emoji\": true}}, {\"type\": \"section\", \"text\": {\"type\": \"mrkdwn\", \"text\": \"```\\nIMPACT ↑\\nHigh     🟡 Vendor API   🔴 Data migration\\nMedium   🟢 UX polish    🟡 Test coverage\\nLow      🟢 Copy edits   🟢 Icons\\n         Low Prob        High Prob  →\\n```\"}}, {\"type\": \"context\", \"elements\": [{\"type\": \"mrkdwn\", \"text\": \"Top mitigation: de-risk data migration before polishing UI.\"}]}]}"
}

# ============================================================================
# 63. ON-CALL HANDOFF — incident ownership card
# ============================================================================
card_63() {
post_json "{\"attachments\": [{\"color\": \"#ECB22E\", \"blocks\": [{\"type\": \"header\", \"text\": {\"type\": \"plain_text\", \"text\": \"📟 On-call handoff\", \"emoji\": true}}, {\"type\": \"section\", \"fields\": [{\"type\": \"mrkdwn\", \"text\": \"*Primary*\\n@clayboss until 08:00 ET\"}, {\"type\": \"mrkdwn\", \"text\": \"*Secondary*\\n@ops-lead\"}, {\"type\": \"mrkdwn\", \"text\": \"*Open incidents*\\n1 degraded search index\"}, {\"type\": \"mrkdwn\", \"text\": \"*Watch item*\\nEmail relay retries\"}]}, {\"type\": \"section\", \"text\": {\"type\": \"mrkdwn\", \"text\": \"*Notes:* Search rebuild is 68% complete. Do not restart indexer unless queue stalls for 20+ minutes.\"}}, {\"type\": \"context\", \"elements\": [{\"type\": \"mrkdwn\", \"text\": \"Handoff quality: complete · no mystery alarms.\"}]}]}]}"
}

# ============================================================================
# 64. CUSTOMER INTAKE TRIAGE — lead urgency router
# ============================================================================
card_64() {
post_json "{\"blocks\": [{\"type\": \"header\", \"text\": {\"type\": \"plain_text\", \"text\": \"📥 Intake triage\", \"emoji\": true}}, {\"type\": \"section\", \"fields\": [{\"type\": \"mrkdwn\", \"text\": \"*Matter type*\\nSalesforce rescue\"}, {\"type\": \"mrkdwn\", \"text\": \"*Urgency*\\n🔴 Same-day\"}, {\"type\": \"mrkdwn\", \"text\": \"*Budget signal*\\n🟢 Strong\"}, {\"type\": \"mrkdwn\", \"text\": \"*Next step*\\nBook diagnostic call\"}]}, {\"type\": \"section\", \"text\": {\"type\": \"mrkdwn\", \"text\": \"*Auto-summary:* Prospect has a broken Salesforce automation affecting revenue operations. They need a senior developer to stabilize flows, review triggers, and document the fix.\"}}, {\"type\": \"context\", \"elements\": [{\"type\": \"mrkdwn\", \"text\": \"Routing rule: high urgency + high fit → immediate Slack alert.\"}]}]}"
}

# ============================================================================
# 65. LEGAL MATTER PIPELINE — fractional GC workflow
# ============================================================================
card_65() {
post_json "{\"blocks\": [{\"type\": \"header\", \"text\": {\"type\": \"plain_text\", \"text\": \"⚖️ Legal matter pipeline\", \"emoji\": true}}, {\"type\": \"section\", \"text\": {\"type\": \"mrkdwn\", \"text\": \"`Lead` → `Conflict Check` → `Intake` → `Engagement Letter` → `Client Portal` → `Matter Dashboard`\"}}, {\"type\": \"section\", \"fields\": [{\"type\": \"mrkdwn\", \"text\": \"*New leads*\\n4\"}, {\"type\": \"mrkdwn\", \"text\": \"*Awaiting conflicts*\\n2\"}, {\"type\": \"mrkdwn\", \"text\": \"*Letters out*\\n3\"}, {\"type\": \"mrkdwn\", \"text\": \"*Dashboards ready*\\n1\"}]}, {\"type\": \"context\", \"elements\": [{\"type\": \"mrkdwn\", \"text\": \"A simple Salesforce operating system view for a small law firm.\"}]}]}"
}

# ============================================================================
# 66. DNS CUTOVER CHECKLIST — nameserver migration card
# ============================================================================
card_66() {
post_json "{\"blocks\": [{\"type\": \"header\", \"text\": {\"type\": \"plain_text\", \"text\": \"🌐 DNS cutover checklist\", \"emoji\": true}}, {\"type\": \"section\", \"text\": {\"type\": \"mrkdwn\", \"text\": \"✅ Current DNS host identified\\n✅ MX records copied\\n✅ SPF consolidated\\n🟡 DKIM pending provider verification\\n⬜ Lower TTL before final cutover\\n⬜ Confirm autodiscover after propagation\"}}, {\"type\": \"context\", \"elements\": [{\"type\": \"mrkdwn\", \"text\": \"Rule: if nameservers moved, old registrar DNS edits no longer matter.\"}]}]}"
}

# ============================================================================
# 67. SEO SERP WATCH — keyword rank movement
# ============================================================================
card_67() {
post_json "{\"blocks\": [{\"type\": \"header\", \"text\": {\"type\": \"plain_text\", \"text\": \"🔎 SERP watch\", \"emoji\": true}}, {\"type\": \"section\", \"text\": {\"type\": \"mrkdwn\", \"text\": \"```\\nkeyword                         rank   change\\n────────────────────────────────────────────\\nfractional general counsel sd    11     ▲ 4\\nfintech regulatory attorney      18     ▲ 2\\nprivacy lawyer san diego         27     ▼ 3\\noutside general counsel          14     ─ 0\\n```\"}}, {\"type\": \"context\", \"elements\": [{\"type\": \"mrkdwn\", \"text\": \"Opportunity: create one local landing page for the highest-intent cluster.\"}]}]}"
}

# ============================================================================
# 68. CONTENT CALENDAR — faceless tutorial publishing slate
# ============================================================================
card_68() {
post_json "{\"blocks\": [{\"type\": \"header\", \"text\": {\"type\": \"plain_text\", \"text\": \"📅 Tutorial content calendar\", \"emoji\": true}}, {\"type\": \"section\", \"text\": {\"type\": \"mrkdwn\", \"text\": \"*This week*\\nMon — Salesforce CLI auth in Colab\\nTue — SOQL export to Google Sheets\\nWed — Slack Block Kit for org alerts\\nThu — Flow error forensic dashboard\\nFri — GitHub Actions metadata backup\"}}, {\"type\": \"context\", \"elements\": [{\"type\": \"mrkdwn\", \"text\": \"Batch recording target: 5 short videos, one repo, one playlist.\"}]}]}"
}

# ============================================================================
# 69. YOUTUBE PIPELINE — REELFORGE render status
# ============================================================================
card_69() {
post_json "{\"attachments\": [{\"color\": \"#E01E5A\", \"blocks\": [{\"type\": \"header\", \"text\": {\"type\": \"plain_text\", \"text\": \"🎞️ REELFORGE render\", \"emoji\": true}}, {\"type\": \"section\", \"text\": {\"type\": \"mrkdwn\", \"text\": \"```\\nscript.md          ✅ parsed\\nslides.json        ✅ generated\\nterminal.vhs       ✅ recorded\\nvoiceover.wav      ✅ synthesized\\ncomposition.mp4    🟡 rendering 74%\\nthumbnail.png      ⬜ waiting\\n```\"}}, {\"type\": \"context\", \"elements\": [{\"type\": \"mrkdwn\", \"text\": \"Estimated issue: none · current render segment: Colab notebook zoom pan.\"}]}]}]}"
}

# ============================================================================
# 70. COLAB NOTEBOOK RUN — cell-by-cell execution report
# ============================================================================
card_70() {
post_json "{\"blocks\": [{\"type\": \"header\", \"text\": {\"type\": \"plain_text\", \"text\": \"📓 Colab run report\", \"emoji\": true}}, {\"type\": \"section\", \"text\": {\"type\": \"mrkdwn\", \"text\": \"```\\n[01] Install deps              ✅  42s\\n[02] Authenticate Salesforce   ✅  09s\\n[03] Run SOQL extracts         ✅  1m 14s\\n[04] Write Sheets tabs         ✅  22s\\n[05] Generate profile report   🟡  running\\n[06] Export ZIP artifact       ⬜  waiting\\n```\"}}, {\"type\": \"context\", \"elements\": [{\"type\": \"mrkdwn\", \"text\": \"Notebook mode: top-to-bottom reproducible.\"}]}]}"
}

# ============================================================================
# 71. SOQL INTELLIGENCE — org data profiling summary
# ============================================================================
card_71() {
post_json "{\"blocks\": [{\"type\": \"header\", \"text\": {\"type\": \"plain_text\", \"text\": \"🧠 SOQL intelligence summary\", \"emoji\": true}}, {\"type\": \"section\", \"fields\": [{\"type\": \"mrkdwn\", \"text\": \"*Accounts*\\n48,229 records\"}, {\"type\": \"mrkdwn\", \"text\": \"*Stale opps*\\n1,842 > 180 days\"}, {\"type\": \"mrkdwn\", \"text\": \"*Owner skew*\\nTop owner has 31%\"}, {\"type\": \"mrkdwn\", \"text\": \"*Missing industry*\\n42% blank\"}]}, {\"type\": \"section\", \"text\": {\"type\": \"mrkdwn\", \"text\": \"*Narrative finding:* The org is not broken; it is under-instrumented. Ownership skew and stale opportunities are the first two cleanup levers.\"}}, {\"type\": \"context\", \"elements\": [{\"type\": \"mrkdwn\", \"text\": \"Exported tabs: counts, skew, stale records, recommendations.\"}]}]}"
}

# ============================================================================
# 72. FLOW ERROR FORENSICS — failed interview analysis
# ============================================================================
card_72() {
post_json "{\"attachments\": [{\"color\": \"#E01E5A\", \"blocks\": [{\"type\": \"header\", \"text\": {\"type\": \"plain_text\", \"text\": \"🧯 Flow error forensics\", \"emoji\": true}}, {\"type\": \"section\", \"text\": {\"type\": \"mrkdwn\", \"text\": \"*Flow:* `Lead Intake Router`\\n*Failed element:* `Create_Task_For_Owner`\\n*Likely cause:* Owner queue has no active users with task visibility.\\n\\n*Fix path:* add guard decision → fallback owner queue → fault path logging.\"}}, {\"type\": \"context\", \"elements\": [{\"type\": \"mrkdwn\", \"text\": \"Severity: high · customer-facing lead follow-up delayed.\"}]}]}]}"
}

# ============================================================================
# 73. APEX COVERAGE MAP — class-by-class coverage
# ============================================================================
card_73() {
post_json "{\"blocks\": [{\"type\": \"header\", \"text\": {\"type\": \"plain_text\", \"text\": \"🧪 Apex coverage map\", \"emoji\": true}}, {\"type\": \"section\", \"text\": {\"type\": \"mrkdwn\", \"text\": \"```\\nLeadRouter.cls            ████████████░  92%\\nTaskFactory.cls           █████████░░░░  74%\\nBenefitsClient.cls        ██████░░░░░░░  51%\\nLegacyBillingService.cls  ██░░░░░░░░░░░  19%\\n```\"}}, {\"type\": \"context\", \"elements\": [{\"type\": \"mrkdwn\", \"text\": \"Priority: add tests around BenefitsClient error and timeout handling.\"}]}]}"
}

# ============================================================================
# 74. PERMISSION MODEL SNAPSHOT — access layers explained
# ============================================================================
card_74() {
post_json "{\"blocks\": [{\"type\": \"header\", \"text\": {\"type\": \"plain_text\", \"text\": \"🔐 Permission model snapshot\", \"emoji\": true}}, {\"type\": \"section\", \"text\": {\"type\": \"mrkdwn\", \"text\": \"```\\nObject access        Profile + Permission Set ✅\\nField access         FLS                          ✅\\nRecord access        OWD + Role + Sharing         🟡\\nUI visibility        App/Page/Layout              ✅\\nSpecial access       Teams/Territories/Manual     ⬜\\n```\"}}, {\"type\": \"context\", \"elements\": [{\"type\": \"mrkdwn\", \"text\": \"Diagnosis: record access is the likely failure layer.\"}]}]}"
}

# ============================================================================
# 75. SANDBOX REFRESH BOARD — environment readiness
# ============================================================================
card_75() {
post_json "{\"blocks\": [{\"type\": \"header\", \"text\": {\"type\": \"plain_text\", \"text\": \"🏗️ Sandbox readiness\", \"emoji\": true}}, {\"type\": \"section\", \"fields\": [{\"type\": \"mrkdwn\", \"text\": \"*DEV*\\n✅ Ready\"}, {\"type\": \"mrkdwn\", \"text\": \"*QA*\\n🟡 Seeding data\"}, {\"type\": \"mrkdwn\", \"text\": \"*UAT*\\n✅ Ready\"}, {\"type\": \"mrkdwn\", \"text\": \"*FULL*\\n🔴 Refresh locked\"}]}, {\"type\": \"section\", \"text\": {\"type\": \"mrkdwn\", \"text\": \"*Blocker:* Full sandbox refresh cannot start until current UAT signoff finishes.\"}}, {\"type\": \"context\", \"elements\": [{\"type\": \"mrkdwn\", \"text\": \"Suggested action: use partial copy for integration testing.\"}]}]}"
}

# ============================================================================
# 76. METADATA PACKAGE MANIFEST — package.xml preview
# ============================================================================
card_76() {
post_json "{\"blocks\": [{\"type\": \"header\", \"text\": {\"type\": \"plain_text\", \"text\": \"📦 Metadata manifest\", \"emoji\": true}}, {\"type\": \"section\", \"text\": {\"type\": \"mrkdwn\", \"text\": \"```xml\\n<types>\\n  <members>Lead_Intake_Flow</members>\\n  <name>Flow</name>\\n</types>\\n<types>\\n  <members>LeadRouter</members>\\n  <members>LeadRouterTest</members>\\n  <name>ApexClass</name>\\n</types>\\n```\"}}, {\"type\": \"context\", \"elements\": [{\"type\": \"mrkdwn\", \"text\": \"Deploy scope: minimal · destructive changes: none.\"}]}]}"
}

# ============================================================================
# 77. BACKUP SNAPSHOT — nightly org backup result
# ============================================================================
card_77() {
post_json "{\"blocks\": [{\"type\": \"header\", \"text\": {\"type\": \"plain_text\", \"text\": \"💾 Nightly Salesforce backup\", \"emoji\": true}}, {\"type\": \"section\", \"fields\": [{\"type\": \"mrkdwn\", \"text\": \"*Metadata changed*\\n42 files\"}, {\"type\": \"mrkdwn\", \"text\": \"*New custom fields*\\n7\"}, {\"type\": \"mrkdwn\", \"text\": \"*Deleted metadata*\\n0\"}, {\"type\": \"mrkdwn\", \"text\": \"*Commit*\\n`9f84c2a`\"}]}, {\"type\": \"section\", \"text\": {\"type\": \"mrkdwn\", \"text\": \"*Notable diff:* Flow `Lead_Intake_Router` changed without matching test documentation update.\"}}, {\"type\": \"context\", \"elements\": [{\"type\": \"mrkdwn\", \"text\": \"Backup pushed to GitHub · MkDocs diff page regenerated.\"}]}]}"
}

# ============================================================================
# 78. PR REVIEW RADAR — stuck reviews and blockers
# ============================================================================
card_78() {
post_json "{\"blocks\": [{\"type\": \"header\", \"text\": {\"type\": \"plain_text\", \"text\": \"👀 PR review radar\", \"emoji\": true}}, {\"type\": \"section\", \"text\": {\"type\": \"mrkdwn\", \"text\": \"```\\nPR     age    status      blocker\\n#241   2h     ✅ clean     needs 1 approval\\n#244   1d     🟡 waiting   product answer\\n#247   3d     🔴 stale     failing test\\n#248   5h     🟢 ready     none\\n```\"}}, {\"type\": \"context\", \"elements\": [{\"type\": \"mrkdwn\", \"text\": \"Escalate #247 before it becomes invisible work.\"}]}]}"
}

# ============================================================================
# 79. TECH DEBT AUCTION — bid points to remove legacy code
# ============================================================================
card_79() {
post_json "{\"blocks\": [{\"type\": \"header\", \"text\": {\"type\": \"plain_text\", \"text\": \"🔨 Tech debt auction\", \"emoji\": true}}, {\"type\": \"section\", \"text\": {\"type\": \"mrkdwn\", \"text\": \"Going once... going twice...\\n\\n*Item:* `LegacyBillingService.cls`\\n*Opening bid:* 5 story points\\n*Current bid:* 8 points from Platform Team\\n*Reward:* 400 lines deleted, 2 scheduled jobs retired, one future outage avoided\"}}, {\"type\": \"context\", \"elements\": [{\"type\": \"mrkdwn\", \"text\": \"Sold to the team with enough test coverage.\"}]}]}"
}

# ============================================================================
# 80. ARCHITECTURE DECISION RECORD — ADR summary card
# ============================================================================
card_80() {
post_json "{\"attachments\": [{\"color\": \"#0C447C\", \"blocks\": [{\"type\": \"header\", \"text\": {\"type\": \"plain_text\", \"text\": \"🏛️ ADR-014: Slack Trivia Identity\", \"emoji\": true}}, {\"type\": \"section\", \"text\": {\"type\": \"mrkdwn\", \"text\": \"*Decision:* Store Slack user mapping in Salesforce custom object.\\n\\n*Context:* Trivia scores, attempts, streaks, and certification tracks need persistence beyond Slack messages.\\n\\n*Consequence:* Salesforce becomes system of record; Slack remains interaction layer.\"}}, {\"type\": \"context\", \"elements\": [{\"type\": \"mrkdwn\", \"text\": \"Status: accepted · review date: next sprint\"}]}]}]}"
}

# ============================================================================
# 81. PRODUCT HUNT LAUNCH ROOM — launch checklist
# ============================================================================
card_81() {
post_json "{\"blocks\": [{\"type\": \"header\", \"text\": {\"type\": \"plain_text\", \"text\": \"🚀 Launch room\", \"emoji\": true}}, {\"type\": \"section\", \"text\": {\"type\": \"mrkdwn\", \"text\": \"✅ Landing page\\n✅ Demo video\\n✅ First comment\\n✅ Screenshot gallery\\n🟡 20 supporter DMs\\n⬜ Pricing page QA\\n⬜ Post-launch recap\"}}, {\"type\": \"context\", \"elements\": [{\"type\": \"mrkdwn\", \"text\": \"Launch asset: Salesforce DevOps mini-toolkit\"}]}]}"
}

# ============================================================================
# 82. SALES PIPELINE MINI CRM — opportunity stage card
# ============================================================================
card_82() {
post_json "{\"blocks\": [{\"type\": \"header\", \"text\": {\"type\": \"plain_text\", \"text\": \"💼 Pipeline snapshot\", \"emoji\": true}}, {\"type\": \"section\", \"fields\": [{\"type\": \"mrkdwn\", \"text\": \"*Prospecting*\\n12 opps · $18K\"}, {\"type\": \"mrkdwn\", \"text\": \"*Discovery*\\n5 opps · $11K\"}, {\"type\": \"mrkdwn\", \"text\": \"*Proposal*\\n3 opps · $9K\"}, {\"type\": \"mrkdwn\", \"text\": \"*Closed won*\\n2 opps · $4K\"}]}, {\"type\": \"section\", \"text\": {\"type\": \"mrkdwn\", \"text\": \"*Best next move:* follow up with the 3 proposal-stage leads before creating more top-of-funnel noise.\"}}, {\"type\": \"context\", \"elements\": [{\"type\": \"mrkdwn\", \"text\": \"Tiny CRM card for Slack-native consulting operations.\"}]}]}"
}

# ============================================================================
# 83. SUPPORT QUEUE HEAT — tickets by age and severity
# ============================================================================
card_83() {
post_json "{\"blocks\": [{\"type\": \"header\", \"text\": {\"type\": \"plain_text\", \"text\": \"🔥 Support queue heat\", \"emoji\": true}}, {\"type\": \"section\", \"text\": {\"type\": \"mrkdwn\", \"text\": \"```\\nSeverity   <4h   4-24h   1-3d   >3d\\nP1          0      1       0      0\\nP2          3      4       2      1\\nP3          8      6       5      7\\nP4         12      9       4      2\\n```\"}}, {\"type\": \"context\", \"elements\": [{\"type\": \"mrkdwn\", \"text\": \"Heat source: P2 ticket older than 3 days needs owner today.\"}]}]}"
}

# ============================================================================
# 84. TEST DATA FACTORY — generated records summary
# ============================================================================
card_84() {
post_json "{\"blocks\": [{\"type\": \"header\", \"text\": {\"type\": \"plain_text\", \"text\": \"🏭 Test data factory\", \"emoji\": true}}, {\"type\": \"section\", \"fields\": [{\"type\": \"mrkdwn\", \"text\": \"*Accounts*\\n200 generated\"}, {\"type\": \"mrkdwn\", \"text\": \"*Contacts*\\n600 generated\"}, {\"type\": \"mrkdwn\", \"text\": \"*Opportunities*\\n350 generated\"}, {\"type\": \"mrkdwn\", \"text\": \"*Cases*\\n500 generated\"}]}, {\"type\": \"section\", \"text\": {\"type\": \"mrkdwn\", \"text\": \"*Scenario packs:* enterprise, SMB, nonprofit, messy legacy import, duplicate-heavy org.\"}}, {\"type\": \"context\", \"elements\": [{\"type\": \"mrkdwn\", \"text\": \"Seed completed in scratch org: `boss-dev-042`.\"}]}]}"
}

# ============================================================================
# 85. LWC COMPONENT GALLERY — UI component inventory
# ============================================================================
card_85() {
post_json "{\"blocks\": [{\"type\": \"header\", \"text\": {\"type\": \"plain_text\", \"text\": \"🧩 LWC component gallery\", \"emoji\": true}}, {\"type\": \"section\", \"text\": {\"type\": \"mrkdwn\", \"text\": \"```\\nc-lead-intake-wizard        ✅ documented\\nc-cert-question-card        ✅ tested\\nc-org-health-dashboard      🟡 needs stories\\nc-slack-config-panel        🔴 missing Jest\\nc-file-tree-viewer          ✅ demo ready\\n```\"}}, {\"type\": \"context\", \"elements\": [{\"type\": \"mrkdwn\", \"text\": \"Best demo candidate: `c-cert-question-card` with Slack game integration.\"}]}]}"
}

# ============================================================================
# 86. API CONTRACT CARD — endpoint health and schema drift
# ============================================================================
card_86() {
post_json "{\"blocks\": [{\"type\": \"header\", \"text\": {\"type\": \"plain_text\", \"text\": \"🔌 API contract check\", \"emoji\": true}}, {\"type\": \"section\", \"fields\": [{\"type\": \"mrkdwn\", \"text\": \"*Endpoint*\\n`/v1/benefits/check`\"}, {\"type\": \"mrkdwn\", \"text\": \"*Status*\\n🟢 200 OK\"}, {\"type\": \"mrkdwn\", \"text\": \"*Schema drift*\\n🟡 2 new fields\"}, {\"type\": \"mrkdwn\", \"text\": \"*Latency*\\n418ms p95\"}]}, {\"type\": \"section\", \"text\": {\"type\": \"mrkdwn\", \"text\": \"*Detected drift:* `memberPlanType`, `deductibleRemaining` appeared in response but are not mapped to Salesforce yet.\"}}, {\"type\": \"context\", \"elements\": [{\"type\": \"mrkdwn\", \"text\": \"Action: update DTO + field mapping before relying on downstream automation.\"}]}]}"
}

# ============================================================================
# 87. VENDOR API BENEFITS CHECK — eligibility workflow result
# ============================================================================
card_87() {
post_json "{\"blocks\": [{\"type\": \"header\", \"text\": {\"type\": \"plain_text\", \"text\": \"🏥 Benefits verification result\", \"emoji\": true}}, {\"type\": \"section\", \"fields\": [{\"type\": \"mrkdwn\", \"text\": \"*Patient match*\\n✅ Confirmed\"}, {\"type\": \"mrkdwn\", \"text\": \"*Coverage active*\\n✅ Yes\"}, {\"type\": \"mrkdwn\", \"text\": \"*Deductible*\\n$1,250 remaining\"}, {\"type\": \"mrkdwn\", \"text\": \"*Auth required*\\n🟡 Maybe\"}]}, {\"type\": \"section\", \"text\": {\"type\": \"mrkdwn\", \"text\": \"*Routing:* create Salesforce case, attach raw vendor response, notify admissions coordinator.\"}}, {\"type\": \"context\", \"elements\": [{\"type\": \"mrkdwn\", \"text\": \"Human review recommended because auth requirement returned ambiguous text.\"}]}]}"
}

# ============================================================================
# 88. SLACK TRIVIA ROUND — timed certification game card
# ============================================================================
card_88() {
post_json "{\"blocks\": [{\"type\": \"header\", \"text\": {\"type\": \"plain_text\", \"text\": \"⏲️ Trivia Round 7\", \"emoji\": true}}, {\"type\": \"section\", \"text\": {\"type\": \"mrkdwn\", \"text\": \"*Certification:* Platform Developer I\\n*Timer:* `00:15`\\n\\nWhich Apex collection type guarantees uniqueness?\"}}, {\"type\": \"actions\", \"elements\": [{\"type\": \"button\", \"text\": {\"type\": \"plain_text\", \"text\": \"List\"}, \"action_id\": \"list\"}, {\"type\": \"button\", \"text\": {\"type\": \"plain_text\", \"text\": \"Set\"}, \"action_id\": \"set\"}, {\"type\": \"button\", \"text\": {\"type\": \"plain_text\", \"text\": \"Map\"}, \"action_id\": \"map\"}, {\"type\": \"button\", \"text\": {\"type\": \"plain_text\", \"text\": \"Queue\"}, \"action_id\": \"queue\"}]}, {\"type\": \"context\", \"elements\": [{\"type\": \"mrkdwn\", \"text\": \"Scoring: +10 correct · +5 speed bonus under 8 seconds\"}]}]}"
}

# ============================================================================
# 89. TRIVIA LEADERBOARD — accuracy plus speed ranking
# ============================================================================
card_89() {
post_json "{\"blocks\": [{\"type\": \"header\", \"text\": {\"type\": \"plain_text\", \"text\": \"🏆 Trivia leaderboard\", \"emoji\": true}}, {\"type\": \"section\", \"text\": {\"type\": \"mrkdwn\", \"text\": \"```\\nrank  player       accuracy   avg speed   score\\n1     clayboss       94%        6.2s       1840\\n2     flowqueen      91%        7.1s       1725\\n3     apexwolf       88%        5.9s       1690\\n4     adminhero      82%        8.4s       1410\\n```\"}}, {\"type\": \"context\", \"elements\": [{\"type\": \"mrkdwn\", \"text\": \"Tie-breaker: explanation quality on missed questions.\"}]}]}"
}

# ============================================================================
# 90. KNOWLEDGE GAP MAP — learner struggle diagnosis
# ============================================================================
card_90() {
post_json "{\"blocks\": [{\"type\": \"header\", \"text\": {\"type\": \"plain_text\", \"text\": \"🧭 Knowledge gap map\", \"emoji\": true}}, {\"type\": \"section\", \"text\": {\"type\": \"mrkdwn\", \"text\": \"```\\nSecurity model       ███████████░  weak\\nAutomation order     ███████░░░░░  mixed\\nSOQL relationships   ████░░░░░░░░  strong\\nReports              ██████░░░░░░  moderate\\nDeployment model     █████████░░░  needs review\\n```\"}}, {\"type\": \"context\", \"elements\": [{\"type\": \"mrkdwn\", \"text\": \"Recommendation: stop giving random questions; branch into record access scenarios.\"}]}]}"
}

# ============================================================================
# 91. ROADMAP TRAIN MAP — milestones as stations
# ============================================================================
card_91() {
post_json "{\"blocks\": [{\"type\": \"header\", \"text\": {\"type\": \"plain_text\", \"text\": \"🚆 Product roadmap line\", \"emoji\": true}}, {\"type\": \"section\", \"text\": {\"type\": \"mrkdwn\", \"text\": \"`Prototype` ──● `Slack OAuth` ──● `Question Bank` ──● `Scoring Engine` ──● `Salesforce Sync` ──○ `Paid Cohorts` ──○ `Analytics`\\n\\n*Current station:* Salesforce Sync\\n*Next transfer:* Stripe billing integration\"}}, {\"type\": \"context\", \"elements\": [{\"type\": \"mrkdwn\", \"text\": \"Arrival estimate depends on identity model finishing cleanly.\"}]}]}"
}

# ============================================================================
# 92. BATTLE CARD — competitor comparison layout
# ============================================================================
card_92() {
post_json "{\"blocks\": [{\"type\": \"header\", \"text\": {\"type\": \"plain_text\", \"text\": \"⚔️ Battle card\", \"emoji\": true}}, {\"type\": \"section\", \"fields\": [{\"type\": \"mrkdwn\", \"text\": \"*Them*\\nStatic quizzes\\nGeneric explanations\\nNo org context\"}, {\"type\": \"mrkdwn\", \"text\": \"*Us*\\nAdaptive questions\\nCited explanations\\nSalesforce-backed progress\"}]}, {\"type\": \"section\", \"text\": {\"type\": \"mrkdwn\", \"text\": \"*Positioning line:* Not another quiz bank — a diagnostic coach that finds the exact Salesforce concept you keep missing.\"}}, {\"type\": \"context\", \"elements\": [{\"type\": \"mrkdwn\", \"text\": \"Use in landing page or sales DM follow-up.\"}]}]}"
}

# ============================================================================
# 93. EXECUTIVE BRIEF — one-screen decision memo
# ============================================================================
card_93() {
post_json "{\"attachments\": [{\"color\": \"#1A1D21\", \"blocks\": [{\"type\": \"header\", \"text\": {\"type\": \"plain_text\", \"text\": \"📌 Executive brief\", \"emoji\": true}}, {\"type\": \"section\", \"text\": {\"type\": \"mrkdwn\", \"text\": \"*Decision needed:* Approve 2-day Salesforce stabilization sprint.\\n\\n*Why now:* lead routing failures are delaying response time and creating invisible revenue leakage.\\n\\n*Cost of waiting:* more manual triage, more duplicate work, less trust in Salesforce.\"}}, {\"type\": \"section\", \"fields\": [{\"type\": \"mrkdwn\", \"text\": \"*Effort*\\n2 days\"}, {\"type\": \"mrkdwn\", \"text\": \"*Risk*\\nLow\"}, {\"type\": \"mrkdwn\", \"text\": \"*Impact*\\nHigh\"}, {\"type\": \"mrkdwn\", \"text\": \"*Owner*\\n@clayboss\"}]}]}]}"
}

# ============================================================================
# 94. COST BURN ALERT — cloud spend anomaly card
# ============================================================================
card_94() {
post_json "{\"blocks\": [{\"type\": \"header\", \"text\": {\"type\": \"plain_text\", \"text\": \"💸 Cost burn alert\", \"emoji\": true}}, {\"type\": \"section\", \"text\": {\"type\": \"mrkdwn\", \"text\": \"```\\nservice        expected   actual    delta\\nRender jobs      $18       $61      +239%\\nStorage          $12       $14       +17%\\nDB               $40       $41        +2%\\nBandwidth        $21       $29       +38%\\n```\"}}, {\"type\": \"context\", \"elements\": [{\"type\": \"mrkdwn\", \"text\": \"Likely cause: duplicate video render loop after failed webhook retry.\"}]}]}"
}

# ============================================================================
# 95. DATA QUALITY SCORECARD — duplicates, stale records, missing fields
# ============================================================================
card_95() {
post_json "{\"blocks\": [{\"type\": \"header\", \"text\": {\"type\": \"plain_text\", \"text\": \"🧼 Data quality scorecard\", \"emoji\": true}}, {\"type\": \"section\", \"fields\": [{\"type\": \"mrkdwn\", \"text\": \"*Duplicate leads*\\n312\"}, {\"type\": \"mrkdwn\", \"text\": \"*Missing phone*\\n18%\"}, {\"type\": \"mrkdwn\", \"text\": \"*Stale accounts*\\n2,104\"}, {\"type\": \"mrkdwn\", \"text\": \"*Invalid emails*\\n487\"}]}, {\"type\": \"section\", \"text\": {\"type\": \"mrkdwn\", \"text\": \"`███████░░░` *Data quality score: 68 / 100*\"}}, {\"type\": \"context\", \"elements\": [{\"type\": \"mrkdwn\", \"text\": \"Best first cleanup: duplicate lead merge rules + required intake fields.\"}]}]}"
}

# ============================================================================
# 96. AUTOMATION COLLISION MAP — flows, triggers, rules
# ============================================================================
card_96() {
post_json "{\"blocks\": [{\"type\": \"header\", \"text\": {\"type\": \"plain_text\", \"text\": \"💥 Automation collision map\", \"emoji\": true}}, {\"type\": \"section\", \"text\": {\"type\": \"mrkdwn\", \"text\": \"```\\nObject: Lead\\nBefore-save Flow       ✅ normalize fields\\nBefore Trigger         🟡 assigns region\\nAfter-save Flow        🔴 creates duplicate task\\nAfter Trigger          ✅ enrichment queue\\nProcess Builder        🔴 still active\\nWorkflow Rule          🟡 legacy email alert\\n```\"}}, {\"type\": \"context\", \"elements\": [{\"type\": \"mrkdwn\", \"text\": \"Collision found: task creation exists in both after-save Flow and Process Builder.\"}]}]}"
}

# ============================================================================
# 97. MIGRATION COMMAND CENTER — extract, transform, load status
# ============================================================================
card_97() {
post_json "{\"blocks\": [{\"type\": \"header\", \"text\": {\"type\": \"plain_text\", \"text\": \"🚚 Migration command center\", \"emoji\": true}}, {\"type\": \"section\", \"text\": {\"type\": \"mrkdwn\", \"text\": \"```\\nEXTRACT   Accounts       ✅ 48,229 rows\\nEXTRACT   Contacts       ✅ 93,104 rows\\nTRANSFORM Emails         🟡 81% cleaned\\nLOAD      Accounts       ⬜ waiting\\nLOAD      Contacts       ⬜ waiting\\nVERIFY    Relationships  ⬜ waiting\\n```\"}}, {\"type\": \"context\", \"elements\": [{\"type\": \"mrkdwn\", \"text\": \"Do not load until email normalization and external IDs are locked.\"}]}]}"
}

# ============================================================================
# 98. CLIENT WOW DEMO — before/after business impact
# ============================================================================
card_98() {
post_json "{\"attachments\": [{\"color\": \"#2EB67D\", \"blocks\": [{\"type\": \"header\", \"text\": {\"type\": \"plain_text\", \"text\": \"✨ Client wow demo\", \"emoji\": true}}, {\"type\": \"section\", \"fields\": [{\"type\": \"mrkdwn\", \"text\": \"*Before*\\nLead arrives by vague email\\nManual follow-up\\nNo urgency signal\"}, {\"type\": \"mrkdwn\", \"text\": \"*After*\\nGuided intake\\nAuto-triage\\nSame-day scheduling\\nSalesforce dashboard\"}]}, {\"type\": \"section\", \"text\": {\"type\": \"mrkdwn\", \"text\": \"*Punchline:* the firm does not need more effort; it needs a visible operating system.\"}}, {\"type\": \"context\", \"elements\": [{\"type\": \"mrkdwn\", \"text\": \"Best used as a live demo opener.\"}]}]}]}"
}

# ============================================================================
# 99. DAILY RECAP DIGEST — machine activity timeline
# ============================================================================
card_99() {
post_json "{\"blocks\": [{\"type\": \"header\", \"text\": {\"type\": \"plain_text\", \"text\": \"🕰️ Daily activity recap\", \"emoji\": true}}, {\"type\": \"section\", \"text\": {\"type\": \"mrkdwn\", \"text\": \"```\\n09:12  edited slack trivia repo\\n10:03  searched OAuth identity examples\\n11:27  created Block Kit card variants\\n13:44  opened Salesforce metadata backup\\n15:02  drafted REELFORGE improvements\\n```\"}}, {\"type\": \"section\", \"text\": {\"type\": \"mrkdwn\", \"text\": \"*Recovered thread:* Slack certification game + Salesforce identity mapping kept reappearing across tasks.\"}}, {\"type\": \"context\", \"elements\": [{\"type\": \"mrkdwn\", \"text\": \"Purpose: capture side-track ideas before they disappear.\"}]}]}"
}

# ============================================================================
# 100. HALL OF FAME — best cards index and next experiments
# ============================================================================
card_100() {
post_json "{\"blocks\": [{\"type\": \"header\", \"text\": {\"type\": \"plain_text\", \"text\": \"🏛️ Slack card hall of fame\", \"emoji\": true}}, {\"type\": \"section\", \"text\": {\"type\": \"mrkdwn\", \"text\": \"*Best reusable patterns from this pack:*\\n1. War room checklist\\n2. Certification question + reveal\\n3. Data quality scorecard\\n4. Agent lifecycle status\\n5. Executive decision memo\\n6. File tree audit\\n7. Flow error forensics\"}}, {\"type\": \"divider\"}, {\"type\": \"section\", \"text\": {\"type\": \"mrkdwn\", \"text\": \"*Next experiments:* interactive modals, Home tab dashboard, persistent Salesforce score records, scheduled daily digest.\"}}, {\"type\": \"context\", \"elements\": [{\"type\": \"mrkdwn\", \"text\": \"100 cards loaded. Now pick the 10 that should become real app templates.\"}]}]}"
}

# ============================================================================
#  DISPATCHER — handles `all`, single number, or range
# ============================================================================
case "${1:-}" in
    "")
        echo "Usage:"
        echo "  bash $0 all              # fire all 100"
        echo "  bash $0 N                # fire card N (1-100)"
        echo "  bash $0 N M              # fire cards N through M"
        echo ""
        echo "Available cards:"
        printf "  %3d. %s\n" 1 "EMOJI BAR CHART"
        printf "  %3d. %s\n" 2 "SPARKLINE ROW"
        printf "  %3d. %s\n" 3 "PROGRESS BAR"
        printf "  %3d. %s\n" 4 "RANKED LEADERBOARD"
        printf "  %3d. %s\n" 5 "STATUS DASHBOARD"
        printf "  %3d. %s\n" 6 "RAINBOW THREAD"
        printf "  %3d. %s\n" 7 "WEATHER REPORT"
        printf "  %3d. %s\n" 8 "POLAROID STACK"
        printf "  %3d. %s\n" 9 "CALENDAR HEATMAP"
        printf "  %3d. %s\n" 10 "TYPEWRITER ANNOUNCEMENT"
        printf "  %3d. %s\n" 11 "TAROT CARD"
        printf "  %3d. %s\n" 12 "TERMINAL STREAM"
        printf "  %3d. %s\n" 13 "POLL RESULTS"
        printf "  %3d. %s\n" 14 "RECEIPT"
        printf "  %3d. %s\n" 15 "CHOOSE-YOUR-OWN-ADVENTURE"
        printf "  %3d. %s\n" 16 "METRO SIGN"
        printf "  %3d. %s\n" 17 "PIXEL ART"
        printf "  %3d. %s\n" 18 "STOCK TICKER"
        printf "  %3d. %s\n" 19 "INVOICE"
        printf "  %3d. %s\n" 20 "ESCAPE ROOM"
        printf "  %3d. %s\n" 21 "CARD GAME HAND"
        printf "  %3d. %s\n" 22 "AIRPORT BOARD"
        printf "  %3d. %s\n" 23 "BINGO CARD"
        printf "  %3d. %s\n" 24 "CRIME SCENE"
        printf "  %3d. %s\n" 25 "RECIPE CARD"
        printf "  %3d. %s\n" 26 "EMOJI SHRINE"
        printf "  %3d. %s\n" 27 "DUAL-PANEL DIFF"
        printf "  %3d. %s\n" 28 "ASCII PIE CHART"
        printf "  %3d. %s\n" 29 "RUNNING SCORE"
        printf "  %3d. %s\n" 30 "WAVEFORM"
        printf "  %3d. %s\n" 31 "FORTUNE COOKIE"
        printf "  %3d. %s\n" 32 "CHESS BOARD"
        printf "  %3d. %s\n" 33 "THERMOMETER"
        printf "  %3d. %s\n" 34 "TELEGRAM"
        printf "  %3d. %s\n" 35 "MULTI-AVATAR ROW"
        printf "  %3d. %s\n" 36 "CONFETTI WALL"
        printf "  %3d. %s\n" 37 "WANTED POSTER"
        printf "  %3d. %s\n" 38 "BARCODE"
        printf "  %3d. %s\n" 39 "SKILL TREE"
        printf "  %3d. %s\n" 40 "CONCERT POSTER"
        printf "  %3d. %s\n" 41 "WHISPER NETWORK"
        printf "  %3d. %s\n" 42 "PROGRESS RING"
        printf "  %3d. %s\n" 43 "MORSE CODE"
        printf "  %3d. %s\n" 44 "SUBWAY MAP"
        printf "  %3d. %s\n" 45 "ZINE PAGE"
        printf "  %3d. %s\n" 46 "QR CODE"
        printf "  %3d. %s\n" 47 "NESTED QUOTES"
        printf "  %3d. %s\n" 48 "HORIZON BAR"
        printf "  %3d. %s\n" 49 "MULTI-IMAGE GRID"
        printf "  %3d. %s\n" 50 "CLOSING CREDITS"
        printf "  %3d. %s\n" 51 "SALESFORCE DEPLOY WAR ROOM"
        printf "  %3d. %s\n" 52 "ORG LIMITS RADAR"
        printf "  %3d. %s\n" 53 "CERT QUESTION PROMPT"
        printf "  %3d. %s\n" 54 "CERT ANSWER REVEAL"
        printf "  %3d. %s\n" 55 "SPACED REPETITION QUEUE"
        printf "  %3d. %s\n" 56 "PROMPT CHAIN RUNNER"
        printf "  %3d. %s\n" 57 "AGENT LIFECYCLE"
        printf "  %3d. %s\n" 58 "FILE TREE AUDIT"
        printf "  %3d. %s\n" 59 "GOOGLE DRIVE ORGANIZER"
        printf "  %3d. %s\n" 60 "GITHUB ACTIONS WALL"
        printf "  %3d. %s\n" 61 "RELEASE NOTES DIGEST"
        printf "  %3d. %s\n" 62 "RISK MATRIX"
        printf "  %3d. %s\n" 63 "ON-CALL HANDOFF"
        printf "  %3d. %s\n" 64 "CUSTOMER INTAKE TRIAGE"
        printf "  %3d. %s\n" 65 "LEGAL MATTER PIPELINE"
        printf "  %3d. %s\n" 66 "DNS CUTOVER CHECKLIST"
        printf "  %3d. %s\n" 67 "SEO SERP WATCH"
        printf "  %3d. %s\n" 68 "CONTENT CALENDAR"
        printf "  %3d. %s\n" 69 "YOUTUBE PIPELINE"
        printf "  %3d. %s\n" 70 "COLAB NOTEBOOK RUN"
        printf "  %3d. %s\n" 71 "SOQL INTELLIGENCE"
        printf "  %3d. %s\n" 72 "FLOW ERROR FORENSICS"
        printf "  %3d. %s\n" 73 "APEX COVERAGE MAP"
        printf "  %3d. %s\n" 74 "PERMISSION MODEL SNAPSHOT"
        printf "  %3d. %s\n" 75 "SANDBOX REFRESH BOARD"
        printf "  %3d. %s\n" 76 "METADATA PACKAGE MANIFEST"
        printf "  %3d. %s\n" 77 "BACKUP SNAPSHOT"
        printf "  %3d. %s\n" 78 "PR REVIEW RADAR"
        printf "  %3d. %s\n" 79 "TECH DEBT AUCTION"
        printf "  %3d. %s\n" 80 "ARCHITECTURE DECISION RECORD"
        printf "  %3d. %s\n" 81 "PRODUCT HUNT LAUNCH ROOM"
        printf "  %3d. %s\n" 82 "SALES PIPELINE MINI CRM"
        printf "  %3d. %s\n" 83 "SUPPORT QUEUE HEAT"
        printf "  %3d. %s\n" 84 "TEST DATA FACTORY"
        printf "  %3d. %s\n" 85 "LWC COMPONENT GALLERY"
        printf "  %3d. %s\n" 86 "API CONTRACT CARD"
        printf "  %3d. %s\n" 87 "VENDOR API BENEFITS CHECK"
        printf "  %3d. %s\n" 88 "SLACK TRIVIA ROUND"
        printf "  %3d. %s\n" 89 "TRIVIA LEADERBOARD"
        printf "  %3d. %s\n" 90 "KNOWLEDGE GAP MAP"
        printf "  %3d. %s\n" 91 "ROADMAP TRAIN MAP"
        printf "  %3d. %s\n" 92 "BATTLE CARD"
        printf "  %3d. %s\n" 93 "EXECUTIVE BRIEF"
        printf "  %3d. %s\n" 94 "COST BURN ALERT"
        printf "  %3d. %s\n" 95 "DATA QUALITY SCORECARD"
        printf "  %3d. %s\n" 96 "AUTOMATION COLLISION MAP"
        printf "  %3d. %s\n" 97 "MIGRATION COMMAND CENTER"
        printf "  %3d. %s\n" 98 "CLIENT WOW DEMO"
        printf "  %3d. %s\n" 99 "DAILY RECAP DIGEST"
        printf "  %3d. %s\n" 100 "HALL OF FAME"
        ;;
    all)
        for i in $(seq 1 100); do
            printf -v n "%02d" "$i"
            echo "→ firing card $i — ${CARD_NAMES[$i]}"
            send_separator "$i"
            card_$n
            echo ""
            sleep "${SLACK_CARD_SLEEP_SECONDS:-1}"
        done
        ;;
    *)
        START=$1
        END=${2:-$1}
        if ! [[ "$START" =~ ^[0-9]+$ && "$END" =~ ^[0-9]+$ ]]; then
            echo "Expected numeric card number or range." >&2
            exit 1
        fi
        if (( START < 1 || END > 100 || START > END )); then
            echo "Card range must be between 1 and 100." >&2
            exit 1
        fi
        for i in $(seq "$START" "$END"); do
            printf -v n "%02d" "$i"
            echo "→ firing card $i — ${CARD_NAMES[$i]}"
            send_separator "$i"
            card_$n
            echo ""
            sleep "${SLACK_CARD_SLEEP_SECONDS:-1}"
        done
        ;;
esac
