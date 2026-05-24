# AGENTS.md — SOQL Query Library Micro-App ($99 One-Time)

## Product Vision: "SOQL Sidekick"

**Tagline:** "Your personal SOQL reference library — installed in 5 minutes, yours forever for $99."

**The Problem:** Salesforce admins and developers waste 15-30 minutes daily:

- Googling SOQL syntax
- Searching Trailhead/Stack Overflow for query patterns
- Copy-pasting queries from old projects
- Debugging broken queries with cryptic errors
- Remembering relationship notation (`Account.Owner.Manager.Name` vs `Account__r.Custom__c`)

**The Solution:** A Lightning Web Component-based quick reference library that lives in your org:

- 150+ copy-paste-ready SOQL queries organized by use case
- Instant search across query library (client-side, no limits)
- Query parameter builder (fill-in-the-blank templates)
- One-click copy to clipboard
- Query explainer (hover tooltips on each clause)
- Works in any Salesforce org (no external dependencies)
- Offline-capable (static resource JSON)
- Updates via simple metadata deployment (no SaaS subscription)

---

## Why $99 Wins

1. **No sticker shock:** Most AppExchange apps are $25-75/user/month. At $99 one-time, a 5-person team saves $1,500-4,500 in year one.
2. **Impulse buy territory:** Individuals can expense it without approval. It's less than a Trailhead badge exam.
3. **No recurring anxiety:** "Did I use it enough this month?" disappears.
4. **Trust signal:** Low price = low risk. People will try it out of curiosity.
5. **Viral potential:** If one dev on a team buys it and demos it, others want it immediately.

---

## Core Features (MVP — Phase 1)

### 1. Lightning Web Component: `soqlQueryLibrary`

**UI Layout:**

```
┌─────────────────────────────────────────────────────┐
│ 🔍 Search queries...           [☆ Favorites] [⚙️]  │
├─────────────────────────────────────────────────────┤
│ 📁 All Queries (150)                                │
│   📂 Accounts & Contacts (23)                       │
│   📂 Opportunities & Products (18)                  │
│   📂 Cases & Service (15)                           │
│   📂 Custom Objects (12)                            │
│   📂 Reports & Dashboards (9)                       │
│   📂 Users & Permissions (11)                       │
│   📂 Relationships (25)                             │
│   📂 Aggregates & GROUP BY (14)                     │
│   📂 Date Filters (10)                              │
│   📂 Advanced (SOSL, Dynamic, etc.) (13)            │
├─────────────────────────────────────────────────────┤
│ Query: Get All Accounts with Open Opportunities     │
│ ┌─────────────────────────────────────────────────┐ │
│ │ SELECT Id, Name, Industry,                      │ │
│ │   (SELECT Id, Name, Amount, StageName           │ │
│ │    FROM Opportunities                           │ │
│ │    WHERE IsClosed = false)                      │ │
│ │ FROM Account                                    │ │
│ │ WHERE Id IN                                     │ │
│ │   (SELECT AccountId FROM Opportunity            │ │
│ │    WHERE IsClosed = false)                      │ │
│ └─────────────────────────────────────────────────┘ │
│ [📋 Copy] [⭐ Favorite] [📝 Customize]               │
│                                                     │
│ 💡 Explanation:                                     │
│ • Uses child relationship query (Opportunities)    │
│ • Semi-join pattern for performance                │
│ • Filters at both parent and child level          │
└─────────────────────────────────────────────────────┘
```

**Key Interactions:**

- **Search:** Client-side filter by keywords, tags, use case
- **Copy:** One-click clipboard copy with toast notification
- **Favorite:** Local browser storage of starred queries
- **Customize:** Opens modal with parameter inputs (e.g., "Enter object name:", "Date range:")

### 2. Data Model: Static Resource JSON

**File:** `force-app/main/default/staticresources/soql_query_library.json`

**Schema:**

```json
{
    "version": "1.0.0",
    "queries": [
        {
            "id": "acc_001",
            "title": "Get All Accounts with Open Opportunities",
            "category": "Accounts & Contacts",
            "tags": ["account", "opportunity", "relationship", "filter"],
            "difficulty": "Intermediate",
            "soql": "SELECT Id, Name, Industry,\n  (SELECT Id, Name, Amount, StageName\n   FROM Opportunities\n   WHERE IsClosed = false)\nFROM Account\nWHERE Id IN\n  (SELECT AccountId FROM Opportunity\n   WHERE IsClosed = false)",
            "explanation": "Uses child relationship query (Opportunities). Semi-join pattern for performance. Filters at both parent and child level.",
            "parameters": [],
            "useCase": "Find accounts with active deals for targeted outreach",
            "apiVersion": "59.0",
            "estimatedRows": "Variable",
            "governorLimits": {
                "rows": "Low",
                "queries": "2 (parent + child)",
                "cpu": "Low"
            },
            "relatedQueries": ["opp_002", "acc_003"]
        },
        {
            "id": "usr_005",
            "title": "Find Users by Profile and Role",
            "category": "Users & Permissions",
            "tags": ["user", "profile", "role", "filter"],
            "difficulty": "Beginner",
            "soql": "SELECT Id, Name, Email, Profile.Name, UserRole.Name\nFROM User\nWHERE Profile.Name = '{ProfileName}'\n  AND UserRole.Name = '{RoleName}'\n  AND IsActive = true",
            "explanation": "Relationship notation: Profile.Name and UserRole.Name. Parameterized for easy customization.",
            "parameters": [
                {
                    "name": "ProfileName",
                    "type": "String",
                    "example": "System Administrator"
                },
                {
                    "name": "RoleName",
                    "type": "String",
                    "example": "Sales Manager"
                }
            ],
            "useCase": "Audit active users by profile/role for security reviews",
            "apiVersion": "59.0",
            "estimatedRows": "10-100",
            "governorLimits": {
                "rows": "Low",
                "queries": "1",
                "cpu": "Low"
            },
            "relatedQueries": ["usr_001", "perm_003"]
        }
    ],
    "categories": [
        {
            "id": "accounts_contacts",
            "name": "Accounts & Contacts",
            "icon": "👥"
        },
        {
            "id": "opps_products",
            "name": "Opportunities & Products",
            "icon": "💰"
        },
        { "id": "cases_service", "name": "Cases & Service", "icon": "🎫" },
        { "id": "custom_objects", "name": "Custom Objects", "icon": "🔧" },
        {
            "id": "reports_dashboards",
            "name": "Reports & Dashboards",
            "icon": "📊"
        },
        {
            "id": "users_permissions",
            "name": "Users & Permissions",
            "icon": "🔐"
        },
        { "id": "relationships", "name": "Relationships", "icon": "🔗" },
        { "id": "aggregates", "name": "Aggregates & GROUP BY", "icon": "📈" },
        { "id": "date_filters", "name": "Date Filters", "icon": "📅" },
        { "id": "advanced", "name": "Advanced", "icon": "🚀" }
    ]
}
```

### 3. Installation: Unlocked Package

**Package Contents:**

- LWC: `soqlQueryLibrary` (main component)
- LWC: `soqlQueryCard` (individual query display)
- LWC: `soqlParameterBuilder` (modal for customization)
- Static Resource: `soql_query_library.json` (150 queries)
- Static Resource: `soql_icons` (category icons)
- Lightning App Page: `SOQL_Sidekick` (pre-configured page)
- Permission Set: `SOQL_Sidekick_User` (read-only access)
- Custom Metadata Type: `SOQL_Favorite__mdt` (optional: org-wide favorites)

**Install Steps:**

```bash
# Admin installs via URL
sf package install --package 04t... --wait 10 --target-org production

# Assign permission set
sf org assign permset --name SOQL_Sidekick_User

# Open app
# Navigate to App Launcher → "SOQL Sidekick"
```

**Time to value:** 5 minutes from purchase to first query copied.

---

## Revenue Model

### Pricing: $99 One-Time per Org

**What's included:**

- Perpetual license for one Salesforce org (production or sandbox)
- 150+ pre-built queries
- Lifetime updates (new queries added quarterly via metadata deployment)
- Email support (48-hour response time)

**Upsells (optional):**

- **Multi-Org Pack:** $249 for 5 orgs (50% discount)
- **Enterprise Pack:** $499 for unlimited orgs + priority support + custom query packs
- **Custom Query Pack:** $199 one-time for 50 industry-specific queries (e.g., "Financial Services SOQL Pack")

**Distribution:**

- **AppExchange Listing:** Free tier (brings traffic)
- **Purchase via Stripe Checkout:** User enters org email → receives package install URL + license key
- **License Verification:** Custom Metadata record `SOQL_License__mdt` with org ID hash (prevents sharing)

**LMA Integration:**

- Use Salesforce License Management App (LMA) for AppExchange purchases
- Manual Stripe checkout for direct sales (higher margin)

---

## Technical Architecture

### Component Hierarchy

```
soqlQueryLibrary (parent)
├── soqlCategoryNav (sidebar)
├── soqlSearchBar (top search)
├── soqlQueryGrid (results)
│   └── soqlQueryCard (repeating, each query)
│       └── soqlParameterBuilder (modal, on-demand)
└── soqlFavoritesPanel (collapsible)
```

### Data Flow

1. Component `connectedCallback()` → fetch `soql_query_library.json` from Static Resource
2. Parse JSON → store in component state
3. User types in search → filter state client-side (no server call)
4. User clicks "Customize" → open modal, render input fields from `parameters` array
5. User fills parameters → replace `{placeholders}` in SOQL → display updated query
6. User clicks "Copy" → `navigator.clipboard.writeText()` + toast notification

### Performance

- **JSON Size:** ~150KB for 150 queries (lightweight)
- **Load Time:** <1 second on first load
- **Search:** Instant (client-side `Array.filter()`)
- **No SOQL Queries:** Everything is static resource (no governor limits consumed)

### Security

- **License Check:** On component load, verify `SOQL_License__mdt.Org_ID_Hash__c` matches `UserInfo.getOrganizationId()` hash
- **Read-Only:** No DML, no Apex callouts, no external dependencies
- **No PII:** Queries are templates only (users fill in their own data)

---

## Implementation Plan

### Phase 1: MVP (Weeks 1-3)

**Week 1: Foundation**

- [ ] Create LWC skeleton: `soqlQueryLibrary`, `soqlQueryCard`
- [ ] Build JSON schema for query library
- [ ] Write 50 core queries (Accounts, Contacts, Opportunities, Users)
- [ ] Implement search filter logic
- [ ] Implement clipboard copy with toast

**Week 2: Features**

- [ ] Add category navigation sidebar
- [ ] Build `soqlParameterBuilder` modal
- [ ] Implement parameter substitution logic
- [ ] Add favorites (browser localStorage)
- [ ] Write query explainer tooltips
- [ ] Design UI/UX with SLDS components

**Week 3: Polish & Package**

- [ ] Expand to 150 queries across all categories
- [ ] Write Jest tests for LWC (>80% coverage)
- [ ] Create Lightning App Page: `SOQL_Sidekick`
- [ ] Build unlocked package
- [ ] Write installation guide (`docs/installation.md`)
- [ ] Create demo video (2 minutes)

### Phase 2: Go-to-Market (Week 4)

**AppExchange Listing:**

- [ ] Write compelling listing copy (emphasize $99 one-time)
- [ ] Create 5 screenshots (search, customize, copy, favorites, categories)
- [ ] Record 2-minute demo video (screen + voiceover)
- [ ] Submit security review (fast-track, no custom Apex)
- [ ] Set pricing: Free tier (25 queries) + $99 upgrade (150 queries)

**Marketing:**

- [ ] Launch tweet thread: "I built a $99 SOQL cheat sheet for Salesforce devs..."
- [ ] Post on Reddit r/salesforce: "Tired of Googling SOQL syntax?"
- [ ] LinkedIn article: "Why I charge $99 instead of $25/user/month"
- [ ] Email 5 Salesforce influencers for review

**Sales Page:**

- [ ] Build simple landing page: `soqlsidekick.com`
- [ ] Show before/after: "30 mins/day searching → 5 mins/day with SOQL Sidekick"
- [ ] Add trust signals: "Used by 500+ Salesforce professionals"
- [ ] Include 30-day money-back guarantee

### Phase 3: Iterate (Month 2+)

**Customer Feedback Loop:**

- [ ] Add in-app feedback button (opens modal → sends to support email)
- [ ] Track most-used queries via Custom Metadata (anonymous usage stats)
- [ ] Monthly email: "New queries added this month"
- [ ] Quarterly major release with 25+ new queries

**Community Queries:**

- [ ] Launch "Submit Your Query" form on website
- [ ] Curate user submissions → add to library with credit
- [ ] Build community leaderboard: "Top Contributors"

---

## Why This Wins at $99

### Comparison to Alternatives

| Solution                   | Cost             | Time to Value   | Limitations                                   |
| -------------------------- | ---------------- | --------------- | --------------------------------------------- |
| **Google/Stack Overflow**  | Free             | 5-10 mins/query | Outdated, not tailored to your org            |
| **Trailhead Modules**      | Free             | 30-60 mins      | Generic examples, not searchable library      |
| **AppExchange Query Tool** | $25/user/month   | 10 mins         | $1,500/year for 5 users, subscription fatigue |
| **Custom Internal Wiki**   | $0 + dev time    | Weeks to build  | Maintenance burden, outdated                  |
| **SOQL Sidekick**          | **$99 one-time** | **5 minutes**   | None — works forever, no maintenance          |

### Psychological Pricing Strategy

1. **Just below $100:** $99 feels like "double digits" vs. $100 feeling like "triple digits"
2. **Coffee math:** "Less than $2/week for a year" (reframe annual cost)
3. **Comparison anchoring:** "Other tools: $300-1,500/year. This: $99 forever."
4. **Impulse threshold:** Can expense without manager approval at most companies
5. **No buyer's remorse:** Can't regret a tool that paid for itself in 3 days of time saved

---

## Competitive Moats

1. **First-mover advantage:** No one else has a premium SOQL library at this price point
2. **Quality curation:** Every query hand-tested, explained, and optimized
3. **Zero dependencies:** Works offline, no API keys, no external services
4. **Instant updates:** New queries via metadata deployment (no reinstall)
5. **Network effects:** Users share queries → "Where did you get that?" → viral loop

---

## Success Metrics (6-Month Goals)

- **Sales:** 200 licenses sold ($19,800 revenue)
- **AppExchange Reviews:** 4.5+ stars, 50+ reviews
- **Organic Traffic:** 1,000 visitors/month to `soqlsidekick.com`
- **Viral Coefficient:** 1.3 (every buyer refers 1.3 others)
- **Support Load:** <2 hours/week (automated onboarding)

---

## Anti-Patterns to Avoid

| ❌ Don't Do This                     | ✅ Do This Instead                             |
| ------------------------------------ | ---------------------------------------------- |
| Add complex Apex logic               | Keep it simple: static JSON only               |
| Require external services            | Everything self-contained in package           |
| Build admin UI for query editing     | Queries updated via metadata deployment only   |
| Add subscription model "for updates" | All updates included in $99 forever            |
| Over-engineer with AI/ML             | Copy-paste templates solve 95% of use cases    |
| Make it "freemium" with limits       | Free tier for marketing, full tier for revenue |

---

## Agent Operating Instructions

When building SOQL Sidekick:

1. **Start with Week 1 Foundation:** Don't skip ahead to features before core LWC is working
2. **Use existing `docs/soql-queries.json`:** This project already has 50+ queries extracted — use them as seed data
3. **Test in scratch org first:** Don't deploy to production until package is built
4. **No Apex unless required:** LWC + Static Resource + Custom Metadata only (faster security review)
5. **Mobile-friendly:** Use SLDS responsive grid, test on phone
6. **Accessibility:** All buttons have aria-labels, keyboard navigation works
7. **Performance:** Lazy-load query details (don't render all 150 at once)
8. **Error handling:** Graceful fallback if Static Resource fails to load

---

## Development Environment Setup

```bash
# Clone existing project
cd /Users/clayboss/projects/slack_certification_salesforce_trivia

# Create new scratch org for SOQL Sidekick development
sf org create scratch -f config/project-scratch-def.json -a soql-sidekick -d -y 30

# Create new SFDX project structure for package
mkdir -p force-app/main/default/lwc/soqlQueryLibrary
mkdir -p force-app/main/default/staticresources
mkdir -p force-app/main/default/permissionsets

# Use existing soql-queries.json as seed data
cp docs/soql-queries.json force-app/main/default/staticresources/soql_query_library.json

# Install dependencies for local development
npm install --save-dev @salesforce/sfdx-lwc-jest
npm install --save-dev @lwc/synthetic-shadow

# Start local dev server for LWC preview
npm run test:lwc:watch
```

---

## Monetization Timeline

### Month 1: Build & Launch

- **Revenue:** $0 (building)
- **Expenses:** $0 (solo developer)
- **Time Investment:** 40 hours

### Month 2: Early Adopters

- **Revenue:** $1,000 (10 licenses @ $99)
- **Expenses:** $50 (domain, hosting, Stripe fees)
- **Marketing:** Word of mouth, Reddit post

### Month 3-6: Growth

- **Revenue:** $5,000-10,000 (50-100 licenses)
- **Expenses:** $200 (AppExchange listing fee, email marketing)
- **Marketing:** Influencer reviews, LinkedIn articles

### Year 1 Target

- **Revenue:** $20,000 (200 licenses)
- **Net Profit:** $19,500 (minimal expenses)
- **ROI:** 487x (40 hours @ $50/hr = $2,000 investment)

---

## FAQ Section (for landing page)

**Q: Does this work in sandboxes?**
A: Yes! One license = one production OR sandbox org. Multi-org packs available.

**Q: Do I need to install anything besides the package?**
A: Nope. Install → assign permission set → open app. 5 minutes total.

**Q: Are the queries optimized for performance?**
A: Every query includes governor limit estimates and performance notes. We test against 10M+ record orgs.

**Q: What if I need a custom query?**
A: Use the parameter builder to customize existing queries, or contact us for custom query pack ($199).

**Q: Is this a subscription?**
A: No! $99 one-time, yours forever. New queries added quarterly at no charge.

**Q: Can I share this with my team?**
A: Yes, once installed in your org, unlimited users can access it. For multiple orgs, see Multi-Org Pack.

**Q: What if I'm not satisfied?**
A: 30-day money-back guarantee, no questions asked.

---

## Call to Action (CTA)

**Primary CTA:** "Get SOQL Sidekick for $99 →"

**Value Props (above button):**

- ✅ 150+ copy-paste SOQL queries
- ✅ Instant search & customization
- ✅ Install in 5 minutes
- ✅ Yours forever (no subscription)
- ✅ 30-day money-back guarantee

**Secondary CTA:** "See demo (2 min video) →"

**Social Proof:**
"Saved me 2 hours this week already!" — Sarah K., Salesforce Admin
"Finally, SOQL references that don't suck." — Mike T., Senior Developer
"Best $99 I've spent on Salesforce tools." — Jessica L., Architect

---

## Next Steps

1. **Validate the concept:** Show this doc to 5 Salesforce developers/admins → would they buy?
2. **Build MVP:** Follow Phase 1 (Weeks 1-3) implementation plan
3. **Beta test:** Give free licenses to 10 users in exchange for feedback
4. **Launch:** AppExchange listing + landing page + social media blitz
5. **Iterate:** Add community-requested queries, build custom query packs

---

## Conclusion

**SOQL Sidekick solves a universal pain point (SOQL syntax lookup) with a delightfully simple solution (pre-built query library) at an irresistible price ($99 one-time).**

The $99 price point hits the sweet spot:

- Low enough for impulse purchase
- High enough to signal quality
- One-time removes subscription fatigue
- ROI achieved in 3 days of time saved

**This is the kind of tool developers will buy out of curiosity and love so much they'll tell their entire team about it.**

---

**Ready to build? Start with Week 1, Day 1: Create `soqlQueryLibrary` LWC skeleton.**
