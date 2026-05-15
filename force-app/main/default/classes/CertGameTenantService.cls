/**
 * Slack team / workspace identity management. Maps Slack team_id to Tenant__c,
 * and Slack user_id (within tenant) to Player__c.
 */
public with sharing class CertGameTenantService {

    public static Tenant__c getOrCreateTenant(String slackTeamId) {
        Tenant__c t = findTenant(slackTeamId);
        if (t != null) return t;
        t = new Tenant__c(
            Name = slackTeamId,
            Slack_Team_Id__c = slackTeamId,
            Plan__c = 'Free',
            Status__c = 'Active'
        );
        Database.UpsertResult ur = Database.upsert(t, Tenant__c.Slack_Team_Id__c, false);
        return [SELECT Id, Name, Slack_Team_Id__c, Plan__c, Status__c FROM Tenant__c
                WHERE Slack_Team_Id__c = :slackTeamId WITH USER_MODE LIMIT 1];
    }

    public static Tenant__c findTenant(String slackTeamId) {
        List<Tenant__c> ts = [SELECT Id, Name, Slack_Team_Id__c, Plan__c, Status__c
                              FROM Tenant__c WHERE Slack_Team_Id__c = :slackTeamId
                              WITH USER_MODE LIMIT 1];
        return ts.isEmpty() ? null : ts[0];
    }

    public static Player__c getOrCreatePlayer(Id tenantId, String slackUserId) {
        Player__c p = findPlayer(tenantId, slackUserId);
        if (p != null) return p;
        p = new Player__c(
            Tenant__c = tenantId,
            Slack_User_Id__c = slackUserId,
            Display_Name__c = slackUserId
        );
        insert as user p;
        return p;
    }

    public static Player__c findPlayer(Id tenantId, String slackUserId) {
        List<Player__c> ps = [SELECT Id, Tenant__c, Slack_User_Id__c, Display_Name__c
                              FROM Player__c
                              WHERE Tenant__c = :tenantId AND Slack_User_Id__c = :slackUserId
                              WITH USER_MODE LIMIT 1];
        return ps.isEmpty() ? null : ps[0];
    }

    public static String handleUninstall(String slackTeamId) {
        Tenant__c t = findTenant(slackTeamId);
        if (t == null) return '';
        t.Status__c = 'Uninstalled';
        update as user t;
        AuditLogger.log('uninstall', 'Tenant', t.Id, null, slackTeamId, null);
        return '';
    }
}
