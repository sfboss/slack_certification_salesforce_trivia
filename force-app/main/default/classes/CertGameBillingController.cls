/**
 * Billing console for tenants. Surfaces current plan, quotas, period usage,
 * license event history, and Stripe Customer Portal URL when configured.
 *
 * Notes:
 *  - Stripe Customer Portal URL is sourced from App_Setting__mdt.Stripe_Customer_Portal_URL__c
 *    if present; otherwise falls back to a generic Stripe URL stub.
 *  - This controller is read-only. Plan changes happen via Stripe webhooks.
 */
public with sharing class CertGameBillingController {
    public class PlanFeatureDto {
        @AuraEnabled
        public String plan;
        @AuraEnabled
        public Decimal monthlyUsd;
        @AuraEnabled
        public Integer maxPlayers;
        @AuraEnabled
        public Integer maxGamesPerDay;
        @AuraEnabled
        public Integer maxGenerationPerDay;
        @AuraEnabled
        public Boolean tournaments;
        @AuraEnabled
        public Boolean dynamicGeneration;
        @AuraEnabled
        public Boolean prioritySupport;
        @AuraEnabled
        public Boolean ssoSaml;
        @AuraEnabled
        public Boolean sponsorBranding;
    }

    public class UsageDto {
        @AuraEnabled
        public String period;
        @AuraEnabled
        public Integer questionsServed;
        @AuraEnabled
        public Integer gamesStarted;
        @AuraEnabled
        public Integer activePlayers;
        @AuraEnabled
        public Decimal llmCostUsd;
    }

    public class LicenseEventDto {
        @AuraEnabled
        public Id id;
        @AuraEnabled
        public Datetime occurredAt;
        @AuraEnabled
        public String eventType;
        @AuraEnabled
        public String stripeEventId;
    }

    public class BillingDto {
        @AuraEnabled
        public Id tenantId;
        @AuraEnabled
        public String tenantName;
        @AuraEnabled
        public String slackTeamId;
        @AuraEnabled
        public String currentPlan;
        @AuraEnabled
        public String status;
        @AuraEnabled
        public Datetime trialEndsAt;
        @AuraEnabled
        public Integer seatsPurchased;
        @AuraEnabled
        public String stripeCustomerId;
        @AuraEnabled
        public String stripeSubscriptionId;
        @AuraEnabled
        public String stripePortalUrl;
        @AuraEnabled
        public List<PlanFeatureDto> plans;
        @AuraEnabled
        public UsageDto usage;
        @AuraEnabled
        public List<LicenseEventDto> events;
        @AuraEnabled
        public Decimal mrrUsd;
    }

    private static final Map<String, Decimal> PRICE = new Map<String, Decimal>{
        'Free' => 0,
        'Pro' => 99,
        'Enterprise' => 499
    };

    @AuraEnabled(cacheable=true)
    public static BillingDto load(Id tenantId) {
        BillingDto out = new BillingDto();
        out.events = new List<LicenseEventDto>();
        out.usage = new UsageDto();
        out.plans = buildPlans();

        List<Tenant__c> ts = [
            SELECT
                Id,
                Workspace_Name__c,
                Slack_Team_Id__c,
                Plan__c,
                Status__c,
                Trial_Ends_At__c,
                Seats_Purchased__c,
                Stripe_Customer_Id__c,
                Stripe_Subscription_Id__c
            FROM Tenant__c
            WHERE Id = :tenantId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (ts.isEmpty())
            return out;
        Tenant__c t = ts[0];

        out.tenantId = t.Id;
        out.tenantName = t.Workspace_Name__c;
        out.slackTeamId = t.Slack_Team_Id__c;
        out.currentPlan = t.Plan__c;
        out.status = t.Status__c;
        out.trialEndsAt = t.Trial_Ends_At__c;
        out.seatsPurchased = t.Seats_Purchased__c == null
            ? 0
            : t.Seats_Purchased__c.intValue();
        out.stripeCustomerId = t.Stripe_Customer_Id__c;
        out.stripeSubscriptionId = t.Stripe_Subscription_Id__c;
        out.mrrUsd = PRICE.containsKey(t.Plan__c) ? PRICE.get(t.Plan__c) : 0;
        out.stripePortalUrl = buildPortalUrl(t.Stripe_Customer_Id__c);

        String period = currentPeriod();
        out.usage.period = period;
        for (Usage_Metric__c u : [
            SELECT
                Questions_Served__c,
                Games_Started__c,
                Active_Players__c,
                LLM_Cost_USD__c
            FROM Usage_Metric__c
            WHERE Tenant__c = :tenantId AND Period__c = :period
            WITH SYSTEM_MODE
        ]) {
            out.usage.questionsServed = add(
                out.usage.questionsServed,
                intOf(u.Questions_Served__c)
            );
            out.usage.gamesStarted = add(
                out.usage.gamesStarted,
                intOf(u.Games_Started__c)
            );
            out.usage.activePlayers = add(
                out.usage.activePlayers,
                intOf(u.Active_Players__c)
            );
            out.usage.llmCostUsd = addD(
                out.usage.llmCostUsd,
                u.LLM_Cost_USD__c
            );
        }

        for (License_Event__c le : [
            SELECT Id, Occurred_At__c, Event_Type__c, Stripe_Event_Id__c
            FROM License_Event__c
            WHERE Tenant__c = :tenantId
            WITH SYSTEM_MODE
            ORDER BY Occurred_At__c DESC NULLS LAST
            LIMIT 25
        ]) {
            LicenseEventDto d = new LicenseEventDto();
            d.id = le.Id;
            d.occurredAt = le.Occurred_At__c;
            d.eventType = le.Event_Type__c;
            d.stripeEventId = le.Stripe_Event_Id__c;
            out.events.add(d);
        }
        return out;
    }

    private static List<PlanFeatureDto> buildPlans() {
        App_Setting__mdt s = AppSettings.get();
        Integer freeGames = s == null ||
            s.Max_Games_Per_Day_Free__c == null
            ? 5
            : s.Max_Games_Per_Day_Free__c.intValue();
        Integer freeGen = s == null ||
            s.Max_Generation_Per_Day_Free__c == null
            ? 0
            : s.Max_Generation_Per_Day_Free__c.intValue();
        Integer proGen = s == null ||
            s.Max_Generation_Per_Day_Pro__c == null
            ? 100
            : s.Max_Generation_Per_Day_Pro__c.intValue();
        return new List<PlanFeatureDto>{
            plan(
                'Free',
                0,
                25,
                freeGames,
                freeGen,
                false,
                false,
                false,
                false,
                false
            ),
            plan('Pro', 99, 250, 200, proGen, true, true, false, false, true),
            plan(
                'Enterprise',
                499,
                10000,
                9999,
                9999,
                true,
                true,
                true,
                true,
                true
            )
        };
    }

    private static PlanFeatureDto plan(
        String name,
        Decimal usd,
        Integer players,
        Integer games,
        Integer gen,
        Boolean tournaments,
        Boolean dyn,
        Boolean support,
        Boolean sso,
        Boolean sponsor
    ) {
        PlanFeatureDto p = new PlanFeatureDto();
        p.plan = name;
        p.monthlyUsd = usd;
        p.maxPlayers = players;
        p.maxGamesPerDay = games;
        p.maxGenerationPerDay = gen;
        p.tournaments = tournaments;
        p.dynamicGeneration = dyn;
        p.prioritySupport = support;
        p.ssoSaml = sso;
        p.sponsorBranding = sponsor;
        return p;
    }

    private static String buildPortalUrl(String customerId) {
        if (String.isBlank(customerId))
            return null;
        // Stripe Customer Portal is normally generated by a session API call.
        // Here we surface a placeholder admin URL; the Slack /certgame billing
        // command should be used to obtain a one-time portal session URL.
        return 'https://dashboard.stripe.com/customers/' + customerId;
    }

    private static String currentPeriod() {
        Datetime n = System.now();
        Integer y = n.year();
        Integer m = n.month();
        return y + '-' + (m < 10 ? '0' + m : String.valueOf(m));
    }

    private static Integer intOf(Decimal d) {
        return d == null ? 0 : d.intValue();
    }
    private static Integer add(Integer a, Integer b) {
        if (a == null)
            a = 0;
        if (b == null)
            b = 0;
        return a + b;
    }
    private static Decimal addD(Decimal a, Decimal b) {
        if (a == null)
            a = 0;
        if (b == null)
            b = 0;
        return a + b;
    }
}