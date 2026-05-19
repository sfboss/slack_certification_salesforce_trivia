@IsTest
private class CertGameLeaderboardService_Test {

    @TestSetup static void setup() {
        Tenant__c t = new Tenant__c(Slack_Team_Id__c='T_LB', Workspace_Name__c='W', Plan__c='Pro', Status__c='Active', Installed_At__c=System.now());
        insert t;
        Player__c p = new Player__c(Tenant__c=t.Id, Slack_User_Id__c='U_LB', Display_Name__c='Tester');
        insert p;
    }

    @IsTest static void leaderboardWeekNoData() {
        String s = CertGameLeaderboardService.renderLeaderboard('T_LB', 'C', new List<String>{'leaderboard','week'});
        System.assert(s.contains('Leaderboard'));
    }

    @IsTest static void leaderboardUnknownTenant() {
        String s = CertGameLeaderboardService.renderLeaderboard('TX', 'C', new List<String>{'leaderboard'});
        System.assert(s.contains('ephemeral'));
    }

    @IsTest static void statsForKnownPlayer() {
        String s = CertGameLeaderboardService.renderStats('T_LB', 'U_LB');
        System.assert(s.contains('Your stats'));
    }

    @IsTest static void statsForUnknownPlayer() {
        String s = CertGameLeaderboardService.renderStats('T_LB', 'U_MISSING');
        System.assert(s.contains('ephemeral'));
    }
}