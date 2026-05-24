/**
 * Read-only listing of all Player__c records for the admin Users tab.
 * Surfaces Google OAuth linkage, Slack identity, tenant assignment, and
 * activity rollups so admins can see who has signed in across surfaces.
 */
public with sharing class UserAdminController {

    public class UserRow {
        @AuraEnabled public Id playerId;
        @AuraEnabled public String displayName;
        @AuraEnabled public String googleEmail;
        @AuraEnabled public String googleName;
        @AuraEnabled public String googlePictureUrl;
        @AuraEnabled public Boolean googleLinked;
        @AuraEnabled public String slackUserId;
        @AuraEnabled public String slackTeamId;
        @AuraEnabled public String tenantName;
        @AuraEnabled public Id tenantId;
        @AuraEnabled public DateTime webLastLoginAt;
        @AuraEnabled public DateTime lastPlayedAt;
        @AuraEnabled public Integer totalGames;
        @AuraEnabled public Integer totalPoints;
        @AuraEnabled public Decimal accuracy;
    }

    @AuraEnabled(cacheable=true)
    public static List<UserRow> listUsers() {
        List<UserRow> out = new List<UserRow>();
        for (Player__c p : [
            SELECT Id, Display_Name__c,
                   Google_Email__c, Google_Name__c, Google_Picture_URL__c, Google_Sub__c,
                   Slack_User_Id__c, Slack_Team_Id__c,
                   Tenant__c, Tenant__r.Name,
                   Web_Last_Login_At__c, Last_Played_At__c,
                   Total_Games__c, Total_Points__c, Accuracy__c
            FROM Player__c
            WITH SYSTEM_MODE
            ORDER BY Web_Last_Login_At__c DESC NULLS LAST, CreatedDate DESC
            LIMIT 500
        ]) {
            UserRow r = new UserRow();
            r.playerId = p.Id;
            r.displayName = p.Display_Name__c;
            r.googleEmail = p.Google_Email__c;
            r.googleName = p.Google_Name__c;
            r.googlePictureUrl = p.Google_Picture_URL__c;
            r.googleLinked = String.isNotBlank(p.Google_Sub__c);
            r.slackUserId = p.Slack_User_Id__c;
            r.slackTeamId = p.Slack_Team_Id__c;
            r.tenantId = p.Tenant__c;
            r.tenantName = p.Tenant__c == null ? null : p.Tenant__r.Name;
            r.webLastLoginAt = p.Web_Last_Login_At__c;
            r.lastPlayedAt = p.Last_Played_At__c;
            r.totalGames = p.Total_Games__c == null ? 0 : p.Total_Games__c.intValue();
            r.totalPoints = p.Total_Points__c == null ? 0 : p.Total_Points__c.intValue();
            r.accuracy = p.Accuracy__c;
            out.add(r);
        }
        return out;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Integer> summary() {
        Integer total = [SELECT COUNT() FROM Player__c WITH SYSTEM_MODE];
        Integer googleLinked = [SELECT COUNT() FROM Player__c WHERE Google_Sub__c != null WITH SYSTEM_MODE];
        Integer slackLinked = [SELECT COUNT() FROM Player__c WHERE Slack_User_Id__c != null WITH SYSTEM_MODE];
        Integer tenants = [SELECT COUNT() FROM Tenant__c WITH SYSTEM_MODE];
        return new Map<String, Integer>{
            'players' => total,
            'googleLinked' => googleLinked,
            'slackLinked' => slackLinked,
            'tenants' => tenants
        };
    }
}
