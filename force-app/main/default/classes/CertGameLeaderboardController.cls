/**
 * Leaderboard data feed. Returns top players (by points) optionally scoped to a
 * tenant and/or an exam. Exam scoping is computed by aggregating Player_Answer__c
 * points per player whose Trivia_Question__c belongs to the given exam.
 */
public with sharing class CertGameLeaderboardController {

    public class RowDto {
        @AuraEnabled public Integer rank;
        @AuraEnabled public Id playerId;
        @AuraEnabled public String displayName;
        @AuraEnabled public Decimal points;
        @AuraEnabled public Integer games;
        @AuraEnabled public Decimal accuracy;
        @AuraEnabled public Integer currentStreak;
    }

    public class ExamOptionDto {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
    }

    public class ResponseDto {
        @AuraEnabled public List<RowDto> rows;
        @AuraEnabled public List<ExamOptionDto> exams;
    }

    @AuraEnabled(cacheable=true)
    public static ResponseDto load(Id tenantId, Id examId, Integer limitRows) {
        Integer lim = (limitRows == null || limitRows <= 0 || limitRows > 100) ? 25 : limitRows;
        ResponseDto out = new ResponseDto();
        out.rows = new List<RowDto>();
        out.exams = new List<ExamOptionDto>();

        for (Certification_Exam__c e : [
            SELECT Id, Name FROM Certification_Exam__c WHERE Active__c = true WITH SYSTEM_MODE ORDER BY Name LIMIT 50
        ]) {
            ExamOptionDto o = new ExamOptionDto();
            o.id = e.Id; o.name = e.Name; out.exams.add(o);
        }

        if (examId == null) {
            // Use Player__c.Total_Points__c rollup
            List<Player__c> players = tenantId == null
                ? [SELECT Id, Display_Name__c, Total_Points__c, Total_Games__c, Accuracy__c, Current_Streak_Days__c
                   FROM Player__c WITH SYSTEM_MODE
                   ORDER BY Total_Points__c DESC NULLS LAST LIMIT :lim]
                : [SELECT Id, Display_Name__c, Total_Points__c, Total_Games__c, Accuracy__c, Current_Streak_Days__c
                   FROM Player__c WHERE Tenant__c = :tenantId WITH SYSTEM_MODE
                   ORDER BY Total_Points__c DESC NULLS LAST LIMIT :lim];
            Integer r = 1;
            for (Player__c p : players) {
                RowDto row = new RowDto();
                row.rank = r++;
                row.playerId = p.Id;
                row.displayName = p.Display_Name__c;
                row.points = p.Total_Points__c == null ? 0 : p.Total_Points__c;
                row.games = p.Total_Games__c == null ? 0 : p.Total_Games__c.intValue();
                row.accuracy = p.Accuracy__c == null ? 0 : p.Accuracy__c;
                row.currentStreak = p.Current_Streak_Days__c == null ? 0 : p.Current_Streak_Days__c.intValue();
                out.rows.add(row);
            }
            return out;
        }

        // Exam-scoped: sum points from Player_Answer__c (no CASE in SOQL — split queries)
        Map<Id, Decimal> ptsByPlayer = new Map<Id, Decimal>();
        Map<Id, Integer> answersByPlayer = new Map<Id, Integer>();
        Map<Id, Integer> correctByPlayer = new Map<Id, Integer>();
        List<AggregateResult> ars = tenantId == null
            ? [SELECT Player__c p, SUM(Points_Awarded__c) pts, COUNT(Id) n
               FROM Player_Answer__c
               WHERE Trivia_Question__r.Certification_Exam__c = :examId
               WITH SYSTEM_MODE
               GROUP BY Player__c
               ORDER BY SUM(Points_Awarded__c) DESC NULLS LAST
               LIMIT :lim]
            : [SELECT Player__c p, SUM(Points_Awarded__c) pts, COUNT(Id) n
               FROM Player_Answer__c
               WHERE Trivia_Question__r.Certification_Exam__c = :examId
                 AND Player__r.Tenant__c = :tenantId
               WITH SYSTEM_MODE
               GROUP BY Player__c
               ORDER BY SUM(Points_Awarded__c) DESC NULLS LAST
               LIMIT :lim];

        List<Id> orderedIds = new List<Id>();
        for (AggregateResult ar : ars) {
            Id pid = (Id) ar.get('p');
            orderedIds.add(pid);
            ptsByPlayer.put(pid, (Decimal) ar.get('pts'));
            answersByPlayer.put(pid, (Integer) ar.get('n'));
            correctByPlayer.put(pid, 0);
        }
        if (!orderedIds.isEmpty()) {
            List<AggregateResult> cAr = tenantId == null
                ? [SELECT Player__c p, COUNT(Id) c FROM Player_Answer__c
                   WHERE Player__c IN :orderedIds
                     AND Is_Correct__c = true
                     AND Trivia_Question__r.Certification_Exam__c = :examId
                   WITH SYSTEM_MODE GROUP BY Player__c]
                : [SELECT Player__c p, COUNT(Id) c FROM Player_Answer__c
                   WHERE Player__c IN :orderedIds
                     AND Is_Correct__c = true
                     AND Trivia_Question__r.Certification_Exam__c = :examId
                     AND Player__r.Tenant__c = :tenantId
                   WITH SYSTEM_MODE GROUP BY Player__c];
            for (AggregateResult ar : cAr) {
                correctByPlayer.put((Id) ar.get('p'), (Integer) ar.get('c'));
            }
        }
        if (orderedIds.isEmpty()) return out;

        Map<Id, Player__c> pmap = new Map<Id, Player__c>([
            SELECT Id, Display_Name__c, Current_Streak_Days__c
            FROM Player__c WHERE Id IN :orderedIds WITH SYSTEM_MODE
        ]);
        Integer rank = 1;
        for (Id pid : orderedIds) {
            Player__c p = pmap.get(pid);
            if (p == null) continue;
            RowDto row = new RowDto();
            row.rank = rank++;
            row.playerId = pid;
            row.displayName = p.Display_Name__c;
            row.points = ptsByPlayer.get(pid) == null ? 0 : ptsByPlayer.get(pid);
            row.games = answersByPlayer.get(pid);
            Integer ans = answersByPlayer.get(pid);
            Integer cor = correctByPlayer.get(pid);
            row.accuracy = (ans == null || ans == 0) ? 0 : (Decimal.valueOf(cor) * 100 / ans).setScale(1);
            row.currentStreak = p.Current_Streak_Days__c == null ? 0 : p.Current_Streak_Days__c.intValue();
            out.rows.add(row);
        }
        return out;
    }

    private static Integer intOf(Decimal d) { return d == null ? 0 : d.intValue(); }
}