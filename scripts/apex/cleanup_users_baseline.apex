// Resets the org to a single-user baseline.
//
// Keeps:
//   - Newest Tenant__c (by CreatedDate)
//   - Newest Player__c linked to that Tenant
//   - All question/exam/study-guide content
//
// Wipes everything else: extra Tenants/Players, all game history, all logs,
// usage metrics, license events, tournaments, generation jobs, leaderboard
// snapshots, study plans.
//
// Run:  sf apex run -o certgame -f scripts/apex/cleanup_users_baseline.apex

System.debug('=== BEFORE ===');
System.debug('Tenants:        ' + [SELECT count() FROM Tenant__c]);
System.debug('Players:        ' + [SELECT count() FROM Player__c]);
System.debug('Game_Sessions:  ' + [SELECT count() FROM Game_Session__c]);
System.debug('Player_Answers: ' + [SELECT count() FROM Player_Answer__c]);
System.debug('Slack_Events:   ' + [SELECT count() FROM Slack_Event_Log__c]);

List<Tenant__c> tenants = [SELECT Id, Name, Slack_Team_Id__c, CreatedDate FROM Tenant__c ORDER BY CreatedDate DESC];
if (tenants.isEmpty()) { throw new System.NoAccessException(); }
Id keepTenantId = tenants[0].Id;
System.debug('Keeping Tenant: ' + tenants[0].Name + ' / ' + tenants[0].Slack_Team_Id__c + ' (' + keepTenantId + ')');

List<Player__c> players = [
    SELECT Id, Name, Google_Email__c, Slack_User_Id__c, CreatedDate
    FROM Player__c
    WHERE Tenant__c = :keepTenantId
    ORDER BY CreatedDate DESC
];
Id keepPlayerId = players.isEmpty() ? null : players[0].Id;
if (keepPlayerId != null) {
    System.debug('Keeping Player: ' + players[0].Name + ' / ' + players[0].Google_Email__c + ' (' + keepPlayerId + ')');
} else {
    System.debug('No Player linked to kept Tenant — keeping zero Players.');
}

// Per-player and per-tenant scoped deletes. Order matters: children before parents.

// 1. Game data (all of it — even for kept player, since the user wants a clean baseline)
delete [SELECT Id FROM Player_Answer__c];
delete [SELECT Id FROM Game_Round__c];
delete [SELECT Id FROM Game_Session__c];
delete [SELECT Id FROM Player_Achievement__c];
delete [SELECT Id FROM Player_Topic_Stat__c];

// 2. Tournaments
delete [SELECT Id FROM Tournament_Participant__c];
delete [SELECT Id FROM Tournament__c];

// 3. Study + leaderboard
delete [SELECT Id FROM Study_Plan__c];
delete [SELECT Id FROM Leaderboard_Snapshot__c];

// 4. Generation jobs
delete [SELECT Id FROM Question_Generation_Job__c];

// 5. Logs / events / metrics
delete [SELECT Id FROM Slack_Event_Log__c];
delete [SELECT Id FROM Usage_Metric__c];
delete [SELECT Id FROM License_Event__c];
delete [SELECT Id FROM Audit_Log__c];
delete [SELECT Id FROM App_Log__c];

// 6. Extra Players
List<Player__c> extraPlayers = keepPlayerId == null
    ? [SELECT Id FROM Player__c]
    : [SELECT Id FROM Player__c WHERE Id != :keepPlayerId];
if (!extraPlayers.isEmpty()) {
    System.debug('Deleting ' + extraPlayers.size() + ' extra Player__c rows');
    delete extraPlayers;
}

// 7. Extra Tenants
List<Tenant__c> extraTenants = [SELECT Id FROM Tenant__c WHERE Id != :keepTenantId];
if (!extraTenants.isEmpty()) {
    System.debug('Deleting ' + extraTenants.size() + ' extra Tenant__c rows');
    delete extraTenants;
}

System.debug('=== AFTER ===');
System.debug('Tenants:        ' + [SELECT count() FROM Tenant__c]);
System.debug('Players:        ' + [SELECT count() FROM Player__c]);
System.debug('Game_Sessions:  ' + [SELECT count() FROM Game_Session__c]);
System.debug('Player_Answers: ' + [SELECT count() FROM Player_Answer__c]);
System.debug('Slack_Events:   ' + [SELECT count() FROM Slack_Event_Log__c]);
