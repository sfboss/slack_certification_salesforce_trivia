/**
 * Evaluates achievement rules whenever a player answers and grants Player_Achievement__c.
 * Called by trigger on QuestionAnswered__e or directly from CertGameSessionService.
 * Bulk-safe: processes List<QuestionAnswered__e>.
 */
public with sharing class CertGameAchievementService {

    public static void evaluate(List<QuestionAnswered__e> events) {
        if (events == null || events.isEmpty()) return;

        Set<String> playerIds = new Set<String>();
        for (QuestionAnswered__e ev : events) {
            if (String.isNotBlank(ev.Player_Id__c)) playerIds.add(ev.Player_Id__c);
        }
        if (playerIds.isEmpty()) return;

        // Load player stats
        Map<Id, AggregateResult> stats = new Map<Id, AggregateResult>();
        for (AggregateResult ar : [
            SELECT Player__c pid,
                   COUNT(Id) total,
                   SUM(CASE WHEN Is_Correct__c = true THEN 1 ELSE 0 END) correctCnt,
                   SUM(Points_Awarded__c) pts
            FROM Player_Answer__c WHERE Player__c IN :playerIds
            WITH USER_MODE GROUP BY Player__c
        ]) {
            stats.put((Id) ar.get('pid'), ar);
        }

        // Load active achievements
        List<Achievement__c> achs = [
            SELECT Id, Code__c, Name, Criteria_Type__c, Threshold__c
            FROM Achievement__c WHERE Active__c = true WITH USER_MODE
        ];
        if (achs.isEmpty()) return;

        // Existing grants
        Map<Id, Set<Id>> playerToAchSet = new Map<Id, Set<Id>>();
        for (Player_Achievement__c pa : [
            SELECT Player__c, Achievement__c FROM Player_Achievement__c
            WHERE Player__c IN :playerIds WITH USER_MODE
        ]) {
            if (!playerToAchSet.containsKey(pa.Player__c)) playerToAchSet.put(pa.Player__c, new Set<Id>());
            playerToAchSet.get(pa.Player__c).add(pa.Achievement__c);
        }

        List<Player_Achievement__c> toInsert = new List<Player_Achievement__c>();
        for (Id pid : stats.keySet()) {
            AggregateResult ar = stats.get(pid);
            Integer total = ar.get('total') == null ? 0 : (Integer) ar.get('total');
            Integer correctCnt = ar.get('correctCnt') == null ? 0 : (Integer) ar.get('correctCnt');
            Integer pts = ar.get('pts') == null ? 0 : ((Decimal) ar.get('pts')).intValue();
            Set<Id> existing = playerToAchSet.containsKey(pid) ? playerToAchSet.get(pid) : new Set<Id>();
            for (Achievement__c a : achs) {
                if (existing.contains(a.Id)) continue;
                Decimal threshold = a.Threshold__c == null ? 0 : a.Threshold__c;
                Boolean qualifies = false;
                if (a.Criteria_Type__c == 'TotalAnswers') qualifies = total >= threshold;
                else if (a.Criteria_Type__c == 'CorrectAnswers') qualifies = correctCnt >= threshold;
                else if (a.Criteria_Type__c == 'TotalPoints') qualifies = pts >= threshold;
                if (qualifies) {
                    toInsert.add(new Player_Achievement__c(
                        Player__c = pid,
                        Achievement__c = a.Id,
                        Awarded_At__c = System.now()
                    ));
                }
            }
        }
        if (!toInsert.isEmpty()) {
            insert as user toInsert;
            for (Player_Achievement__c pa : toInsert) {
                AuditLogger.log('achievement_awarded', 'Player_Achievement__c', pa.Id, null, pa.Achievement__c, null);
            }
        }
    }
}
