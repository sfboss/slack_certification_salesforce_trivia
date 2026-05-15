/**
 * Centralized entitlement / quota / feature checks. ≥95% test coverage required.
 * Reads Tenant__c.Plan__c and Usage_Metric__c rolling counters.
 */
public with sharing class EntitlementGuard {

    public class EntitlementException extends Exception {}

    public static Boolean canStartGame(Id tenantId) {
        Tenant__c t = readTenant(tenantId);
        if (t == null) return false;
        if (t.Status__c != 'Active' && t.Status__c != 'Trial') return false;
        Integer monthlyLimit = limitFor(t.Plan__c, 'games_per_month');
        if (monthlyLimit < 0) return true; // unlimited
        Integer used = usedThisMonth(tenantId, 'games_started');
        return used < monthlyLimit;
    }

    public static Boolean canGenerateQuestions(Id tenantId, Integer requested) {
        Tenant__c t = readTenant(tenantId);
        if (t == null) return false;
        if (t.Status__c != 'Active' && t.Status__c != 'Trial') return false;
        Integer monthlyLimit = limitFor(t.Plan__c, 'gen_questions_per_month');
        if (monthlyLimit < 0) return true;
        Integer used = usedThisMonth(tenantId, 'questions_generated');
        return (used + (requested == null ? 1 : requested)) <= monthlyLimit;
    }

    public static Boolean canCreateTournament(Id tenantId) {
        Tenant__c t = readTenant(tenantId);
        if (t == null) return false;
        return t.Plan__c != 'Free';
    }

    public static void requireCanStartGame(Id tenantId) {
        if (!canStartGame(tenantId)) throw new EntitlementException(CertGameStrings.QUOTA_REACHED);
    }

    private static Tenant__c readTenant(Id tenantId) {
        if (tenantId == null) return null;
        List<Tenant__c> ts = [SELECT Id, Plan__c, Status__c FROM Tenant__c
                              WHERE Id = :tenantId WITH USER_MODE LIMIT 1];
        return ts.isEmpty() ? null : ts[0];
    }

    private static Integer limitFor(String plan, String key) {
        if (plan == null) plan = 'Free';
        // Defaults; in production read from App_Setting__mdt / Plan_Config__mdt
        if (key == 'games_per_month') {
            if (plan == 'Free') return 100;
            if (plan == 'Team') return 5000;
            return -1; // Enterprise unlimited
        }
        if (key == 'gen_questions_per_month') {
            if (plan == 'Free') return 0;
            if (plan == 'Team') return 200;
            return -1;
        }
        return -1;
    }

    private static Integer usedThisMonth(Id tenantId, String metric) {
        DateTime start = DateTime.newInstance(System.today().year(), System.today().month(), 1, 0, 0, 0);
        AggregateResult[] ars = [
            SELECT SUM(Value__c) total FROM Usage_Metric__c
            WHERE Tenant__c = :tenantId AND Metric__c = :metric AND Period_Start__c >= :start
            WITH USER_MODE
        ];
        if (ars.isEmpty() || ars[0].get('total') == null) return 0;
        return ((Decimal) ars[0].get('total')).intValue();
    }
}
