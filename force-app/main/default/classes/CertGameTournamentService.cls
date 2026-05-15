/**
 * Tournament service skeleton (full bracket logic in Phase 6).
 * Currently supports: join an existing Tournament__c by Id, and acknowledge create submissions.
 */
public with sharing class CertGameTournamentService {

    @AuraEnabled
    public static Id createTournament(String name, String bracketType, Id examId, DateTime startAt, DateTime endAt) {
        if (String.isBlank(name) || String.isBlank(bracketType)) {
            throw new AuraHandledException('Name and bracket type are required.');
        }
        Tournament__c t = new Tournament__c(
            Name = name,
            Bracket_Type__c = bracketType,
            Certification_Exam__c = examId,
            Start_At__c = startAt,
            End_At__c = endAt,
            Status__c = 'Scheduled'
        );
        insert as user t;
        AuditLogger.log('tournament_create', 'Tournament__c', t.Id, null, JSON.serialize(t), null);
        return t.Id;
    }

    @AuraEnabled
    public static String buildBracket(Id tournamentId, List<Id> playerIds) {
        List<Tournament__c> ts = [SELECT Id, Bracket_Type__c FROM Tournament__c
                                  WHERE Id = :tournamentId WITH USER_MODE LIMIT 1];
        if (ts.isEmpty()) throw new AuraHandledException('Tournament not found.');
        List<String> ids = new List<String>();
        for (Id pid : playerIds) ids.add(String.valueOf(pid));
        List<CertGameBracketGenerator.Pairing> pairings = CertGameBracketGenerator.generate(ts[0].Bracket_Type__c, ids);
        String json = JSON.serialize(pairings);
        ts[0].Bracket_Json__c = json.left(131000);
        update as user ts[0];
        return json;
    }

    public static String joinFromSlack(String slackTeamId, String slackUserId, String tournamentId) {
        if (String.isBlank(tournamentId)) return CertGameSlackRenderService.text(CertGameStrings.GENERIC_ERROR, true);
        Tenant__c t = CertGameTenantService.getOrCreateTenant(slackTeamId);
        Player__c p = CertGameTenantService.getOrCreatePlayer(t.Id, slackUserId);

        List<Tournament__c> ts = [SELECT Id, Status__c, Tenant__c FROM Tournament__c
                                  WHERE Id = :tournamentId AND Tenant__c = :t.Id WITH USER_MODE LIMIT 1];
        if (ts.isEmpty()) return CertGameSlackRenderService.text(CertGameStrings.TOURNAMENT_NOT_FOUND, true);

        AuditLogger.log('tournament_join', 'Tournament__c', ts[0].Id, null, p.Id, slackUserId);
        return CertGameSlackRenderService.text('Joined tournament. Brackets will open at start time.', true);
    }

    public static String handleCreateSubmission(String slackTeamId, String slackUserId, Map<String, Object> view) {
        Tenant__c t = CertGameTenantService.getOrCreateTenant(slackTeamId);
        if (!EntitlementGuard.canCreateTournament(t.Id)) {
            return CertGameSlackRenderService.text(CertGameStrings.LOCKED_PREMIUM, true);
        }
        if (view == null) return '';
        Map<String, Object> stateWrap = (Map<String, Object>) view.get('state');
        if (stateWrap == null) return '';
        Map<String, Object> state = (Map<String, Object>) stateWrap.get('values');
        String examId = readVal(state, 'exam_block', 'exam');
        String name = readVal(state, 'name_block', 'name');
        if (String.isBlank(examId) || String.isBlank(name)) return '';
        Tournament__c tn = new Tournament__c(
            Tenant__c = t.Id,
            Certification_Exam__c = examId,
            Name = name,
            Bracket_Type__c = readVal(state, 'format_block', 'format'),
            Status__c = 'Scheduled'
        );
        insert as user tn;
        AuditLogger.log('tournament_create', 'Tournament__c', tn.Id, null, JSON.serialize(tn), slackUserId);
        return '';
    }

    private static String readVal(Map<String, Object> state, String block, String action) {
        if (state == null || !state.containsKey(block)) return null;
        Map<String, Object> b = (Map<String, Object>) state.get(block);
        if (!b.containsKey(action)) return null;
        Map<String, Object> a = (Map<String, Object>) b.get(action);
        if (a.containsKey('value')) return (String) a.get('value');
        Object sel = a.get('selected_option');
        if (sel instanceof Map<String, Object>) return (String) ((Map<String, Object>) sel).get('value');
        return null;
    }
}
