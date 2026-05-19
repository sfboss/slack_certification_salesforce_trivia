/**
 * Aggregator for the Cert Game admin dashboard LWC. Returns a single DTO so the
 * page renders in one round trip.
 *
 * Visibility model: returns a tenant-scoped slice when `tenantId` is supplied,
 * otherwise an org-wide aggregate. `with sharing` so tenant admins only see
 * data they have access to.
 */
public with sharing class CertGameAdminDashboardController {

    public class DashboardDto {
        @AuraEnabled public TenantSummaryDto tenant;
        @AuraEnabled public KpiDto kpis;
        @AuraEnabled public List<TopExamDto> topExams;
        @AuraEnabled public QuestionHealthDto questionHealth;
        @AuraEnabled public List<RecentLicenseDto> recentLicense;
        @AuraEnabled public List<RecentErrorDto> recentErrors;
        @AuraEnabled public UsageDto usage;
        @AuraEnabled public List<TenantSummaryDto> tenants;
        @AuraEnabled public List<RecentGenerationDto> recentGenerations;
    }

    public class TenantSummaryDto {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String slackTeamId;
        @AuraEnabled public String plan;
        @AuraEnabled public String status;
        @AuraEnabled public Datetime trialEndsAt;
        @AuraEnabled public Integer seatsPurchased;
        @AuraEnabled public Integer playerCount;
        @AuraEnabled public Integer activeStudyPlans;
        @AuraEnabled public Integer questionsThisPeriod;
        @AuraEnabled public Decimal mrrUsd;
        @AuraEnabled public String stripeCustomerId;
    }

    public class KpiDto {
        @AuraEnabled public Integer totalPlayers;
        @AuraEnabled public Integer activePlayers7d;
        @AuraEnabled public Integer gamesStarted7d;
        @AuraEnabled public Integer questionsAnswered7d;
        @AuraEnabled public Integer questionsAnswered30d;
        @AuraEnabled public Decimal accuracy7d;
        @AuraEnabled public Integer publishedQuestions;
        @AuraEnabled public Integer draftQuestions;
    }

    public class TopExamDto {
        @AuraEnabled public Id examId;
        @AuraEnabled public String examName;
        @AuraEnabled public Integer games;
        @AuraEnabled public Integer answers;
    }

    public class QuestionHealthDto {
        @AuraEnabled public Integer draft;
        @AuraEnabled public Integer reviewed;
        @AuraEnabled public Integer published;
        @AuraEnabled public Integer retired;
        @AuraEnabled public Integer brokenCitations;
        @AuraEnabled public Integer lowQuality;
    }

    public class RecentLicenseDto {
        @AuraEnabled public Id id;
        @AuraEnabled public Datetime occurredAt;
        @AuraEnabled public String tenantName;
        @AuraEnabled public String eventType;
    }

    public class RecentErrorDto {
        @AuraEnabled public Id id;
        @AuraEnabled public Datetime occurredAt;
        @AuraEnabled public String level;
        @AuraEnabled public String className;
        @AuraEnabled public String methodName;
        @AuraEnabled public String message;
    }

    public class UsageDto {
        @AuraEnabled public String period;
        @AuraEnabled public Integer questionsServed;
        @AuraEnabled public Integer questionsServedQuota;
        @AuraEnabled public Integer gamesStarted;
        @AuraEnabled public Integer gamesQuota;
        @AuraEnabled public Integer activePlayers;
        @AuraEnabled public Decimal llmCostUsd;
        @AuraEnabled public Decimal llmTokensIn;
        @AuraEnabled public Decimal llmTokensOut;
    }

    public class RecentGenerationDto {
        @AuraEnabled public Id id;
        @AuraEnabled public Datetime createdAt;
        @AuraEnabled public String provider;
        @AuraEnabled public String status;
        @AuraEnabled public Integer requested;
        @AuraEnabled public Integer generated;
        @AuraEnabled public Decimal costUsd;
    }

    private static final Map<String, Decimal> PLAN_PRICE_USD = new Map<String, Decimal>{
        'Free' => 0,
        'Pro' => 99,
        'Enterprise' => 499
    };

    @AuraEnabled(cacheable=true)
    public static DashboardDto load(Id tenantId) {
        DashboardDto out = new DashboardDto();
        out.kpis = new KpiDto();
        out.questionHealth = new QuestionHealthDto();
        out.usage = new UsageDto();
        out.topExams = new List<TopExamDto>();
        out.recentLicense = new List<RecentLicenseDto>();
        out.recentErrors = new List<RecentErrorDto>();
        out.tenants = new List<TenantSummaryDto>();
        out.recentGenerations = new List<RecentGenerationDto>();

        Datetime weekAgo = System.now().addDays(-7);
        Datetime monthAgo = System.now().addDays(-30);
        String period = currentPeriod();
        out.usage.period = period;

        // -------- Tenant summary + tenants list --------
        if (tenantId != null) {
            out.tenant = buildTenantSummary(tenantId, period);
        } else {
            for (Tenant__c t : [
                SELECT Id, Workspace_Name__c, Slack_Team_Id__c, Plan__c, Status__c,
                       Trial_Ends_At__c, Seats_Purchased__c, Stripe_Customer_Id__c
                FROM Tenant__c WITH SYSTEM_MODE
                ORDER BY Installed_At__c DESC
                LIMIT 50
            ]) {
                out.tenants.add(buildTenantSummaryFromRecord(t, period));
            }
        }

        // -------- KPI rollups --------
        String tenantFilter = tenantId == null ? '' : ' AND Tenant__c = :tenantId ';

        out.kpis.totalPlayers = countPlayers(tenantId);
        out.kpis.activePlayers7d = countActivePlayers(tenantId, weekAgo);
        out.kpis.gamesStarted7d = countGames(tenantId, weekAgo);
        Map<String, Object> ans7 = answerStats(tenantId, weekAgo);
        out.kpis.questionsAnswered7d = (Integer) ans7.get('count');
        out.kpis.accuracy7d = (Decimal) ans7.get('accuracy');
        Map<String, Object> ans30 = answerStats(tenantId, monthAgo);
        out.kpis.questionsAnswered30d = (Integer) ans30.get('count');

        // -------- Question health --------
        for (AggregateResult ar : [
            SELECT Status__c s, COUNT(Id) c
            FROM Trivia_Question__c WITH SYSTEM_MODE
            GROUP BY Status__c
        ]) {
            String st = String.valueOf(ar.get('s'));
            Integer c = (Integer) ar.get('c');
            if (st == 'Draft') out.questionHealth.draft = c;
            else if (st == 'Reviewed') out.questionHealth.reviewed = c;
            else if (st == 'Published') out.questionHealth.published = c;
            else if (st == 'Retired') out.questionHealth.retired = c;
        }
        out.questionHealth.brokenCitations = [
            SELECT COUNT() FROM Question_Citation__c WHERE Broken_Link__c = true WITH SYSTEM_MODE
        ];
        out.questionHealth.lowQuality = [
            SELECT COUNT() FROM Trivia_Question__c
            WHERE Quality_Score__c != null AND Quality_Score__c < 0.5 WITH SYSTEM_MODE
        ];

        // -------- Top exams (7d) --------
        Map<Id, TopExamDto> exMap = new Map<Id, TopExamDto>();
        List<AggregateResult> topRows = tenantId == null
            ? [
                SELECT Certification_Exam__c ex, Certification_Exam__r.Name n, COUNT(Id) c
                FROM Game_Session__c
                WHERE Started_At__c >= :weekAgo AND Certification_Exam__c != null
                WITH SYSTEM_MODE
                GROUP BY Certification_Exam__c, Certification_Exam__r.Name
                ORDER BY COUNT(Id) DESC LIMIT 5]
            : [
                SELECT Certification_Exam__c ex, Certification_Exam__r.Name n, COUNT(Id) c
                FROM Game_Session__c
                WHERE Started_At__c >= :weekAgo AND Certification_Exam__c != null
                  AND Tenant__c = :tenantId
                WITH SYSTEM_MODE
                GROUP BY Certification_Exam__c, Certification_Exam__r.Name
                ORDER BY COUNT(Id) DESC LIMIT 5];
        for (AggregateResult ar : topRows) {
            TopExamDto t = new TopExamDto();
            t.examId = (Id) ar.get('ex');
            t.examName = String.valueOf(ar.get('n'));
            t.games = (Integer) ar.get('c');
            exMap.put(t.examId, t);
        }
        if (!exMap.isEmpty()) {
            for (AggregateResult ar : [
                SELECT Trivia_Question__r.Certification_Exam__c ex, COUNT(Id) c
                FROM Player_Answer__c
                WHERE Answered_At__c >= :weekAgo
                  AND Trivia_Question__r.Certification_Exam__c IN :exMap.keySet()
                WITH SYSTEM_MODE
                GROUP BY Trivia_Question__r.Certification_Exam__c
            ]) {
                Id ex = (Id) ar.get('ex');
                if (exMap.containsKey(ex)) exMap.get(ex).answers = (Integer) ar.get('c');
            }
        }
        out.topExams = exMap.values();

        // -------- Recent license events --------
        List<License_Event__c> licRows = tenantId == null
            ? [SELECT Id, Occurred_At__c, Event_Type__c, Tenant__r.Workspace_Name__c
               FROM License_Event__c WITH SYSTEM_MODE
               ORDER BY Occurred_At__c DESC NULLS LAST LIMIT 10]
            : [SELECT Id, Occurred_At__c, Event_Type__c, Tenant__r.Workspace_Name__c
               FROM License_Event__c WHERE Tenant__c = :tenantId WITH SYSTEM_MODE
               ORDER BY Occurred_At__c DESC NULLS LAST LIMIT 10];
        for (License_Event__c le : licRows) {
            RecentLicenseDto r = new RecentLicenseDto();
            r.id = le.Id;
            r.occurredAt = le.Occurred_At__c;
            r.tenantName = le.Tenant__r == null ? '' : le.Tenant__r.Workspace_Name__c;
            r.eventType = le.Event_Type__c;
            out.recentLicense.add(r);
        }

        // -------- Recent errors --------
        Datetime errSince = System.now().addDays(-2);
        for (App_Log__c log : [
            SELECT Id, Occurred_At__c, Level__c, Class_Name__c, Method_Name__c, Message__c
            FROM App_Log__c
            WHERE Level__c IN ('ERROR','WARN')
              AND Occurred_At__c >= :errSince
            WITH SYSTEM_MODE
            ORDER BY Occurred_At__c DESC
            LIMIT 15
        ]) {
            RecentErrorDto r = new RecentErrorDto();
            r.id = log.Id;
            r.occurredAt = log.Occurred_At__c;
            r.level = log.Level__c;
            r.className = log.Class_Name__c;
            r.methodName = log.Method_Name__c;
            r.message = log.Message__c == null ? '' : log.Message__c.left(300);
            out.recentErrors.add(r);
        }

        // -------- Usage current period --------
        List<Usage_Metric__c> usages = tenantId == null
            ? [SELECT Period__c, Questions_Served__c, Games_Started__c, Active_Players__c,
                      LLM_Cost_USD__c, LLM_Tokens_In__c, LLM_Tokens_Out__c
               FROM Usage_Metric__c WHERE Period__c = :period WITH SYSTEM_MODE]
            : [SELECT Period__c, Questions_Served__c, Games_Started__c, Active_Players__c,
                      LLM_Cost_USD__c, LLM_Tokens_In__c, LLM_Tokens_Out__c
               FROM Usage_Metric__c WHERE Period__c = :period AND Tenant__c = :tenantId WITH SYSTEM_MODE];
        for (Usage_Metric__c u : usages) {
            out.usage.questionsServed = nullSafeAdd(out.usage.questionsServed, intOf(u.Questions_Served__c));
            out.usage.gamesStarted = nullSafeAdd(out.usage.gamesStarted, intOf(u.Games_Started__c));
            out.usage.activePlayers = nullSafeAdd(out.usage.activePlayers, intOf(u.Active_Players__c));
            out.usage.llmCostUsd = nullSafeAddDec(out.usage.llmCostUsd, u.LLM_Cost_USD__c);
            out.usage.llmTokensIn = nullSafeAddDec(out.usage.llmTokensIn, u.LLM_Tokens_In__c);
            out.usage.llmTokensOut = nullSafeAddDec(out.usage.llmTokensOut, u.LLM_Tokens_Out__c);
        }
        App_Setting__mdt s = AppSettings.get();
        if (s != null) {
            String plan = out.tenant == null ? 'Free' : out.tenant.plan;
            out.usage.gamesQuota = intOf(plan == 'Free' ? s.Max_Games_Per_Day_Free__c : null);
            out.usage.questionsServedQuota = intOf(plan == 'Free' ? s.Max_Generation_Per_Day_Free__c : s.Max_Generation_Per_Day_Pro__c);
        }

        // -------- Recent generation jobs --------
        List<Question_Generation_Job__c> genRows = tenantId == null
            ? [SELECT Id, CreatedDate, Provider__c, Status__c,
                      Requested_Question_Count__c, Generated_Question_Count__c, Token_Cost_USD__c
               FROM Question_Generation_Job__c WITH SYSTEM_MODE
               ORDER BY CreatedDate DESC LIMIT 10]
            : [SELECT Id, CreatedDate, Provider__c, Status__c,
                      Requested_Question_Count__c, Generated_Question_Count__c, Token_Cost_USD__c
               FROM Question_Generation_Job__c WHERE Tenant__c = :tenantId WITH SYSTEM_MODE
               ORDER BY CreatedDate DESC LIMIT 10];
        for (Question_Generation_Job__c j : genRows) {
            RecentGenerationDto r = new RecentGenerationDto();
            r.id = j.Id;
            r.createdAt = j.CreatedDate;
            r.provider = j.Provider__c;
            r.status = j.Status__c;
            r.requested = intOf(j.Requested_Question_Count__c);
            r.generated = intOf(j.Generated_Question_Count__c);
            r.costUsd = j.Token_Cost_USD__c;
            out.recentGenerations.add(r);
        }
        return out;
    }

    private static TenantSummaryDto buildTenantSummary(Id tenantId, String period) {
        List<Tenant__c> t = [
            SELECT Id, Workspace_Name__c, Slack_Team_Id__c, Plan__c, Status__c,
                   Trial_Ends_At__c, Seats_Purchased__c, Stripe_Customer_Id__c
            FROM Tenant__c WHERE Id = :tenantId WITH SYSTEM_MODE LIMIT 1
        ];
        if (t.isEmpty()) return null;
        return buildTenantSummaryFromRecord(t[0], period);
    }

    private static TenantSummaryDto buildTenantSummaryFromRecord(Tenant__c t, String period) {
        TenantSummaryDto d = new TenantSummaryDto();
        d.id = t.Id;
        d.name = t.Workspace_Name__c;
        d.slackTeamId = t.Slack_Team_Id__c;
        d.plan = t.Plan__c;
        d.status = t.Status__c;
        d.trialEndsAt = t.Trial_Ends_At__c;
        d.seatsPurchased = intOf(t.Seats_Purchased__c);
        d.stripeCustomerId = t.Stripe_Customer_Id__c;
        d.mrrUsd = PLAN_PRICE_USD.containsKey(t.Plan__c) ? PLAN_PRICE_USD.get(t.Plan__c) : 0;
        d.playerCount = [SELECT COUNT() FROM Player__c WHERE Tenant__c = :t.Id WITH SYSTEM_MODE];
        d.activeStudyPlans = [SELECT COUNT() FROM Study_Plan__c WHERE Active__c = true AND Player__r.Tenant__c = :t.Id WITH SYSTEM_MODE];
        Integer qServed = 0;
        for (Usage_Metric__c u : [
            SELECT Questions_Served__c FROM Usage_Metric__c
            WHERE Tenant__c = :t.Id AND Period__c = :period WITH SYSTEM_MODE
        ]) {
            qServed += intOf(u.Questions_Served__c);
        }
        d.questionsThisPeriod = qServed;
        return d;
    }

    private static Integer countPlayers(Id tenantId) {
        return tenantId == null
            ? [SELECT COUNT() FROM Player__c WITH SYSTEM_MODE]
            : [SELECT COUNT() FROM Player__c WHERE Tenant__c = :tenantId WITH SYSTEM_MODE];
    }

    private static Integer countActivePlayers(Id tenantId, Datetime since) {
        return tenantId == null
            ? [SELECT COUNT() FROM Player__c WHERE Last_Played_At__c >= :since WITH SYSTEM_MODE]
            : [SELECT COUNT() FROM Player__c WHERE Last_Played_At__c >= :since AND Tenant__c = :tenantId WITH SYSTEM_MODE];
    }

    private static Integer countGames(Id tenantId, Datetime since) {
        return tenantId == null
            ? [SELECT COUNT() FROM Game_Session__c WHERE Started_At__c >= :since WITH SYSTEM_MODE]
            : [SELECT COUNT() FROM Game_Session__c WHERE Started_At__c >= :since AND Tenant__c = :tenantId WITH SYSTEM_MODE];
    }

    private static Map<String, Object> answerStats(Id tenantId, Datetime since) {
        Map<String, Object> out = new Map<String, Object>{'count'=>0, 'accuracy'=>0};
        Integer total = 0;
        Integer correct = 0;
        List<AggregateResult> rows = tenantId == null
            ? [SELECT Is_Correct__c c, COUNT(Id) n FROM Player_Answer__c
               WHERE Answered_At__c >= :since WITH SYSTEM_MODE GROUP BY Is_Correct__c]
            : [SELECT Is_Correct__c c, COUNT(Id) n FROM Player_Answer__c
               WHERE Answered_At__c >= :since AND Game_Session__r.Tenant__c = :tenantId
               WITH SYSTEM_MODE GROUP BY Is_Correct__c];
        for (AggregateResult ar : rows) {
            Integer n = (Integer) ar.get('n');
            total += n;
            if (ar.get('c') == true) correct += n;
        }
        out.put('count', total);
        out.put('accuracy', total == 0 ? 0 : (Decimal.valueOf(correct) * 100 / total).setScale(1));
        return out;
    }

    private static String currentPeriod() {
        Datetime n = System.now();
        Integer y = n.year();
        Integer m = n.month();
        return y + '-' + (m < 10 ? '0' + m : String.valueOf(m));
    }

    private static Integer intOf(Decimal d) { return d == null ? 0 : d.intValue(); }
    private static Integer nullSafeAdd(Integer a, Integer b) {
        if (a == null) a = 0; if (b == null) b = 0; return a + b;
    }
    private static Decimal nullSafeAddDec(Decimal a, Decimal b) {
        if (a == null) a = 0; if (b == null) b = 0; return a + b;
    }
}