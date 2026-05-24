/**
 * Slack team / workspace identity management. Maps Slack team_id to Tenant__c,
 * and Slack user_id (within tenant) to Player__c.
 */
public with sharing class CertGameTenantService {
    public static Tenant__c getOrCreateTenant(String slackTeamId) {
        Tenant__c t = findTenant(slackTeamId);
        if (t != null)
            return t;
        t = new Tenant__c(
            Name = slackTeamId,
            Slack_Team_Id__c = slackTeamId,
            Plan__c = 'Free',
            Status__c = 'Active'
        );
        try {
            new TenantLookup().insertTenant(t);
            return t;
        } catch (DmlException e) {
            // Concurrent slash commands can race; whichever transaction inserted second
            // hits DUPLICATE_VALUE. Re-fetch the winner.
            Tenant__c existing = findTenant(slackTeamId);
            if (existing != null)
                return existing;
            throw new TenantException(
                'Failed to create Tenant for team ' +
                    slackTeamId +
                    ' :: ' +
                    e.getMessage()
            );
        }
    }

    public class TenantException extends Exception {
    }

    public static Tenant__c findTenant(String slackTeamId) {
        return new TenantLookup().byTeamId(slackTeamId);
    }

    // Guest user sharing is enforced independently of WITH SYSTEM_MODE, so the
    // tenant lookup must run without sharing or duplicate inserts will be thrown
    // when the slash command arrives from a Slack workspace whose Tenant__c was
    // created by an admin.
    private without sharing class TenantLookup {
        public Tenant__c byTeamId(String slackTeamId) {
            List<Tenant__c> ts = [
                SELECT Id, Name, Slack_Team_Id__c, Plan__c, Status__c
                FROM Tenant__c
                WHERE Slack_Team_Id__c = :slackTeamId
                LIMIT 1
            ];
            return ts.isEmpty() ? null : ts[0];
        }
        public Player__c playerByTenantAndUser(
            Id tenantId,
            String slackUserId
        ) {
            List<Player__c> ps = [
                SELECT Id, Tenant__c, Slack_User_Id__c, Display_Name__c
                FROM Player__c
                WHERE Tenant__c = :tenantId AND Slack_User_Id__c = :slackUserId
                LIMIT 1
            ];
            return ps.isEmpty() ? null : ps[0];
        }
        // The Slack request runs as the Sites guest user. INSERT/UPDATE on a child
        // record validates the Tenant__c lookup against the running user's sharing,
        // independently of WITH SYSTEM_MODE / `as system`. Run cross-tenant DML here.
        public void insertTenant(Tenant__c t) {
            insert t;
        }
        public void insertPlayer(Player__c p) {
            insert p;
        }
        public void cancelTenant(Tenant__c t) {
            update t;
        }
    }

    public static Player__c getOrCreatePlayer(Id tenantId, String slackUserId) {
        Player__c p = findPlayer(tenantId, slackUserId);
        if (p != null)
            return p;
        p = new Player__c(
            Tenant__c = tenantId,
            Slack_User_Id__c = slackUserId,
            Display_Name__c = slackUserId
        );
        new TenantLookup().insertPlayer(p);
        return p;
    }

    public static Player__c findPlayer(Id tenantId, String slackUserId) {
        return new TenantLookup().playerByTenantAndUser(tenantId, slackUserId);
    }

    public static String handleUninstall(String slackTeamId) {
        Tenant__c t = findTenant(slackTeamId);
        if (t == null)
            return '';
        t.Status__c = 'Cancelled';
        new TenantLookup().cancelTenant(t);
        AuditLogger.log('uninstall', 'Tenant', t.Id, null, slackTeamId, null);
        return '';
    }
}