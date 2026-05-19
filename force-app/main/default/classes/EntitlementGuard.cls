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
        Integer used = usedThisMonth(tenantId, 'Games_Started__c');
        return used < monthlyLimit;
    }

    public static Boolean canGenerateQuestions(Id tenantId, Integer requested) {
        Tenant__c t = readTenant(tenantId);
        if (t == null) return false;
        if (t.Status__c != 'Active' && t.Status__c != 'Trial') return false;
        Integer monthlyLimit = limitFor(t.Plan__c, 'gen_questions_per_month');
        if (monthlyLimit < 0) return true;
        Integer used = usedThisMonth(tenantId, 'Questions_Served__c');
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
        return new TenantReader().byId(tenantId);
    }

    // Guest user sharing is enforced independently of WITH SYSTEM_MODE, so the
    // tenant read must run without sharing or every Slack-driven entitlement
    // check will fail closed with "Daily quota reached".
    private without sharing class TenantReader {
        public Tenant__c byId(Id tenantId) {
            List<Tenant__c> ts = [SELECT Id, Plan__c, Status__c FROM Tenant__c
                                  WHERE Id = :tenantId LIMIT 1];
            return ts.isEmpty() ? null : ts[0];
        }
    }

    private static Integer limitFor(String plan, String key) {
        if (plan == null) plan = 'Free';
        // Defaults; in production read from App_Setting__mdt / Plan_Config__mdt
        if (key == 'games_per_month') {
            if (plan == 'Free') return 100;
            if (plan == 'Pro') return 5000;
            return -1; // Enterprise unlimited
        }
        if (key == 'gen_questions_per_month') {
            if (plan == 'Free') return 0;
            if (plan == 'Pro') return 200;
            return -1;
        }
        return -1;
    }

    private static Integer usedThisMonth(Id tenantId, String fieldApi) {
        String period = currentPeriod();
        String soql = 'SELECT ' + fieldApi + ' FROM Usage_Metric__c '
                    + 'WHERE Tenant__c = :tenantId AND Period__c = :period '
                    + 'WITH SYSTEM_MODE LIMIT 1';
        List<Usage_Metric__c> rs = Database.query(soql);
        if (rs.isEmpty()) return 0;
        Object v = rs[0].get(fieldApi);
        return v == null ? 0 : ((Decimal) v).intValue();
    }

    public static String currentPeriod() {
        Date t = System.today();
        String mm = String.valueOf(t.month()).leftPad(2, '0');
        return t.year() + '-' + mm;
    }
}