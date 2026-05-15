@IsTest
private class EntitlementGuard_Test {

    @TestSetup static void setup() {
        Tenant__c free = new Tenant__c(
            Slack_Team_Id__c = 'T_FREE', Workspace_Name__c = 'Free WS', Plan__c = 'Free',
            Status__c = 'Active', Installed_At__c = System.now()
        );
        Tenant__c team = new Tenant__c(
            Slack_Team_Id__c = 'T_TEAM', Workspace_Name__c = 'Team WS', Plan__c = 'Team',
            Status__c = 'Active', Installed_At__c = System.now()
        );
        Tenant__c ent = new Tenant__c(
            Slack_Team_Id__c = 'T_ENT', Workspace_Name__c = 'Ent WS', Plan__c = 'Enterprise',
            Status__c = 'Active', Installed_At__c = System.now()
        );
        Tenant__c suspended = new Tenant__c(
            Slack_Team_Id__c = 'T_SUS', Workspace_Name__c = 'Sus WS', Plan__c = 'Free',
            Status__c = 'Suspended', Installed_At__c = System.now()
        );
        insert new List<Tenant__c>{free, team, ent, suspended};
    }

    private static Tenant__c byTeam(String t) {
        return [SELECT Id, Plan__c, Status__c FROM Tenant__c WHERE Slack_Team_Id__c = :t LIMIT 1];
    }

    @IsTest static void freeCanStartGameUnderLimit() {
        Tenant__c free = byTeam('T_FREE');
        System.assert(EntitlementGuard.canStartGame(free.Id));
    }

    @IsTest static void freeCannotStartGameOverLimit() {
        Tenant__c free = byTeam('T_FREE');
        insert new Usage_Metric__c(
            Tenant__c = free.Id, Period__c = EntitlementGuard.currentPeriod(),
            Games_Started__c = 100, Unique_Key__c = free.Id + ':' + EntitlementGuard.currentPeriod()
        );
        System.assert(!EntitlementGuard.canStartGame(free.Id));
    }

    @IsTest static void enterpriseUnlimited() {
        Tenant__c ent = byTeam('T_ENT');
        insert new Usage_Metric__c(
            Tenant__c = ent.Id, Period__c = EntitlementGuard.currentPeriod(),
            Games_Started__c = 999999, Unique_Key__c = ent.Id + ':' + EntitlementGuard.currentPeriod()
        );
        System.assert(EntitlementGuard.canStartGame(ent.Id));
    }

    @IsTest static void suspendedDenied() {
        Tenant__c s = byTeam('T_SUS');
        System.assert(!EntitlementGuard.canStartGame(s.Id));
    }

    @IsTest static void nullTenantDenied() {
        System.assert(!EntitlementGuard.canStartGame(null));
        System.assert(!EntitlementGuard.canGenerateQuestions(null, 1));
        System.assert(!EntitlementGuard.canCreateTournament(null));
    }

    @IsTest static void freeCannotGenerate() {
        Tenant__c free = byTeam('T_FREE');
        System.assert(!EntitlementGuard.canGenerateQuestions(free.Id, 1));
    }

    @IsTest static void teamCanGenerateBelowQuota() {
        Tenant__c team = byTeam('T_TEAM');
        System.assert(EntitlementGuard.canGenerateQuestions(team.Id, 10));
    }

    @IsTest static void teamCannotGenerateOverQuota() {
        Tenant__c team = byTeam('T_TEAM');
        insert new Usage_Metric__c(
            Tenant__c = team.Id, Period__c = EntitlementGuard.currentPeriod(),
            Questions_Served__c = 200, Unique_Key__c = team.Id + ':' + EntitlementGuard.currentPeriod()
        );
        System.assert(!EntitlementGuard.canGenerateQuestions(team.Id, 1));
    }

    @IsTest static void tournamentRequiresPaid() {
        System.assert(!EntitlementGuard.canCreateTournament(byTeam('T_FREE').Id));
        System.assert(EntitlementGuard.canCreateTournament(byTeam('T_TEAM').Id));
    }

    @IsTest static void requireCanStartThrowsOnDenied() {
        Tenant__c s = byTeam('T_SUS');
        try {
            EntitlementGuard.requireCanStartGame(s.Id);
            System.assert(false, 'expected exception');
        } catch (EntitlementGuard.EntitlementException e) {
            System.assert(true);
        }
    }
}
