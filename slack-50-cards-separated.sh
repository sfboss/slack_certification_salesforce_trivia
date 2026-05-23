#!/usr/bin/env bash
# ============================================================================
#  50 BREATHTAKINGLY COOL SLACK BLOCK KIT CARDS
#  Each is a self-contained curl one-liner.
#  Run individually, or `bash slack-50-cards.sh all` to fire every one.
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
{"blocks":[{"type":"divider"},{"type":"header","text":{"type":"plain_text","text":"━━━━━━━━ Card $n / 50 ━━━━━━━━","emoji":true}},{"type":"section","text":{"type":"mrkdwn","text":"*$title*"}},{"type":"divider"}]}
EOF
)
    post_json "$json"
}

# com
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
#  DISPATCHER — handles `all`, single number, or range
# ============================================================================
case "$1" in
    "")
        echo "Usage:"
        echo "  bash $0 all              # fire all 50"
        echo "  bash $0 N                # fire card N (1-50)"
        echo "  bash $0 N M              # fire cards N through M"
        echo ""
        echo "Available cards:"
        echo "   1. Emoji bar chart            26. Emoji shrine"
        echo "   2. Sparkline row              27. Dual-panel diff"
        echo "   3. Quest progress             28. ASCII pie chart"
        echo "   4. Ranked leaderboard         29. Running scoreboard"
        echo "   5. Status dashboard           30. Waveform"
        echo "   6. Rainbow thread             31. Fortune cookie"
        echo "   7. Weather report             32. Chess board"
        echo "   8. Polaroid stack             33. Thermometer"
        echo "   9. Calendar heatmap           34. Telegram"
        echo "  10. Typewriter announce        35. Multi-avatar row"
        echo "  11. Tarot card                 36. Confetti wall"
        echo "  12. Terminal stream            37. Wanted poster"
        echo "  13. Poll results               38. Barcode"
        echo "  14. Receipt                    39. Skill tree"
        echo "  15. Choose-your-adventure      40. Concert poster"
        echo "  16. Metro sign                 41. Whisper network"
        echo "  17. Pixel art                  42. Progress ring"
        echo "  18. Stock ticker               43. Morse code"
        echo "  19. Invoice                    44. Subway map"
        echo "  20. Escape room                45. Zine page"
        echo "  21. Card game hand             46. QR code"
        echo "  22. Airport board              47. Nested quotes"
        echo "  23. Bingo card                 48. Horizon bar"
        echo "  24. Crime scene                49. Multi-image grid"
        echo "  25. Recipe card                50. Closing credits"
        ;;
    all)
        for i in $(seq 1 50); do
            printf -v n "%02d" "$i"
            echo "→ firing card $i — ${CARD_NAMES[$i]}"
            send_separator "$i"
            card_$n
            echo ""
            sleep 1
        done
        ;;
    *)
        START=$1
        END=${2:-$1}
        for i in $(seq "$START" "$END"); do
            printf -v n "%02d" "$i"
            echo "→ firing card $i — ${CARD_NAMES[$i]}"
            send_separator "$i"
            card_$n
            echo ""
            sleep 1
        done
        ;;
esac
