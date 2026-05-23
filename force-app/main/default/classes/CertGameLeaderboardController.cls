/**
 * Leaderboard data feed for the certGameLeaderboard LWC.
 * Supports tenant + exam scoping, time-window filtering (all/today/7d/30d),
 * top-N limits, and returns summary KPIs alongside per-player rows.
 *
 * When windowKey == 'all' AND examId == null we read the Player__c rollup fields
 * (fast path). Otherwise we aggregate Player_Answer__c on the fly.
 */
public with sharing class CertGameLeaderboardController {

    public class RowDto {
        @AuraEnabled public Integer rank;
        @AuraEnabled public Id playerId;
        @AuraEnabled public String displayName;
        @AuraEnabled public String avatarUrl;
        @AuraEnabled public Decimal points;
        @AuraEnabled public Integer games;
        @AuraEnabled public Integer answerCount;
        @AuraEnabled public Integer correctCount;
        @AuraEnabled public Decimal accuracy;
        @AuraEnabled public Integer currentStreak;
        @AuraEnabled public Integer longestStreak;
        @AuraEnabled public Integer achievementCount;
        @AuraEnabled public DateTime lastPlayedAt;
        @AuraEnabled public String medal;
    }

    public class ExamOptionDto {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
    }

    public class SummaryDto {
        @AuraEnabled public Integer totalPlayers;
        @AuraEnabled public Integer activePlayers;
        @AuraEnabled public Integer totalGames;
        @AuraEnabled public Integer totalAnswers;
        @AuraEnabled public Decimal totalPoints;
        @AuraEnabled public Decimal avgAccuracy;
        @AuraEnabled public Integer topStreak;
        @AuraEnabled public String windowLabel;
        @AuraEnabled public DateTime generatedAt;
    }

    public class ResponseDto {
        @AuraEnabled public List<RowDto> rows;
        @AuraEnabled public List<ExamOptionDto> exams;
        @AuraEnabled public SummaryDto summary;
    }

    @AuraEnabled(cacheable=true)
    public static ResponseDto load(Id tenantId, Id examId, String windowKey, Integer limitRows) {
        Integer lim = (limitRows == null || limitRows <= 0 || limitRows > 200) ? 25 : limitRows;
        String wk = String.isBlank(windowKey) ? 'all' : windowKey.toLowerCase();
        DateTime since = windowStart(wk);

        ResponseDto out = new ResponseDto();
        out.rows = new List<RowDto>();
        out.exams = loadExams();

        Boolean useRollup = (since == null && examId == null);
        if (useRollup) {
            populateRowsFromRollup(out.rows, tenantId, lim);
        } else {
            populateRowsFromAnswers(out.rows, tenantId, examId, since, lim);
        }

        decorate(out.rows);
        out.summary = buildSummary(tenantId, examId, since, wk);
        return out;
    }

    private static List<ExamOptionDto> loadExams() {
        List<ExamOptionDto> exams = new List<ExamOptionDto>();
        for (Certification_Exam__c e : [
            SELECT Id, Name FROM Certification_Exam__c WHERE Active__c = true WITH SYSTEM_MODE ORDER BY Name LIMIT 50
        ]) {
            ExamOptionDto o = new ExamOptionDto();
            o.id = e.Id; o.name = e.Name;
            exams.add(o);
        }
        return exams;
    }

    private static void populateRowsFromRollup(List<RowDto> rows, Id tenantId, Integer lim) {
        List<Player__c> players = tenantId == null
            ? [SELECT Id, Display_Name__c, Google_Picture_URL__c, Total_Points__c, Total_Games__c,
                      Accuracy__c, Current_Streak_Days__c, Longest_Streak_Days__c, Last_Played_At__c
               FROM Player__c WITH SYSTEM_MODE
               ORDER BY Total_Points__c DESC NULLS LAST LIMIT :lim]
            : [SELECT Id, Display_Name__c, Google_Picture_URL__c, Total_Points__c, Total_Games__c,
                      Accuracy__c, Current_Streak_Days__c, Longest_Streak_Days__c, Last_Played_At__c
               FROM Player__c WHERE Tenant__c = :tenantId WITH SYSTEM_MODE
               ORDER BY Total_Points__c DESC NULLS LAST LIMIT :lim];
        Integer r = 1;
        for (Player__c p : players) {
            RowDto row = new RowDto();
            row.rank = r++;
            row.playerId = p.Id;
            row.displayName = p.Display_Name__c;
            row.avatarUrl = p.Google_Picture_URL__c;
            row.points = p.Total_Points__c == null ? 0 : p.Total_Points__c;
            row.games = p.Total_Games__c == null ? 0 : p.Total_Games__c.intValue();
            row.accuracy = p.Accuracy__c == null ? 0 : p.Accuracy__c;
            row.currentStreak = p.Current_Streak_Days__c == null ? 0 : p.Current_Streak_Days__c.intValue();
            row.longestStreak = p.Longest_Streak_Days__c == null ? 0 : p.Longest_Streak_Days__c.intValue();
            row.lastPlayedAt = p.Last_Played_At__c;
            rows.add(row);
        }
    }

    private static void populateRowsFromAnswers(List<RowDto> rows, Id tenantId, Id examId, DateTime since, Integer lim) {
        String w = ' WHERE Player__c != NULL';
        if (tenantId != null) w += ' AND Player__r.Tenant__c = :tenantId';
        if (examId != null) w += ' AND Trivia_Question__r.Certification_Exam__c = :examId';
        if (since != null) w += ' AND Answered_At__c >= :since';

        String soql = 'SELECT Player__c p, SUM(Points_Awarded__c) pts, COUNT(Id) n '
                    + 'FROM Player_Answer__c' + w
                    + ' WITH SYSTEM_MODE GROUP BY Player__c '
                    + 'ORDER BY SUM(Points_Awarded__c) DESC NULLS LAST LIMIT :lim';
        List<AggregateResult> ars = Database.query(soql);

        List<Id> ordered = new List<Id>();
        Map<Id, Decimal> pts = new Map<Id, Decimal>();
        Map<Id, Integer> ans = new Map<Id, Integer>();
        for (AggregateResult ar : ars) {
            Id pid = (Id) ar.get('p');
            ordered.add(pid);
            pts.put(pid, (Decimal) ar.get('pts'));
            ans.put(pid, (Integer) ar.get('n'));
        }
        if (ordered.isEmpty()) return;

        Map<Id, Integer> correct = new Map<Id, Integer>();
        String cw = ' WHERE Player__c IN :ordered AND Is_Correct__c = true';
        if (examId != null) cw += ' AND Trivia_Question__r.Certification_Exam__c = :examId';
        if (tenantId != null) cw += ' AND Player__r.Tenant__c = :tenantId';
        if (since != null) cw += ' AND Answered_At__c >= :since';
        for (AggregateResult ar : Database.query(
            'SELECT Player__c p, COUNT(Id) c FROM Player_Answer__c' + cw
            + ' WITH SYSTEM_MODE GROUP BY Player__c'
        )) {
            correct.put((Id) ar.get('p'), (Integer) ar.get('c'));
        }

        Map<Id, Integer> sessionsByPlayer = new Map<Id, Integer>();
        String sw = ' WHERE Player__c IN :ordered';
        if (examId != null) sw += ' AND Trivia_Question__r.Certification_Exam__c = :examId';
        if (tenantId != null) sw += ' AND Player__r.Tenant__c = :tenantId';
        if (since != null) sw += ' AND Answered_At__c >= :since';
        for (AggregateResult ar : Database.query(
            'SELECT Player__c p, COUNT_DISTINCT(Game_Session__c) g FROM Player_Answer__c'
            + sw + ' WITH SYSTEM_MODE GROUP BY Player__c'
        )) {
            sessionsByPlayer.put((Id) ar.get('p'), (Integer) ar.get('g'));
        }

        Map<Id, Player__c> pmap = new Map<Id, Player__c>([
            SELECT Id, Display_Name__c, Google_Picture_URL__c,
                   Current_Streak_Days__c, Longest_Streak_Days__c, Last_Played_At__c
            FROM Player__c WHERE Id IN :ordered WITH SYSTEM_MODE
        ]);
        Integer rank = 1;
        for (Id pid : ordered) {
            Player__c p = pmap.get(pid);
            if (p == null) continue;
            RowDto row = new RowDto();
            row.rank = rank++;
            row.playerId = pid;
            row.displayName = p.Display_Name__c;
            row.avatarUrl = p.Google_Picture_URL__c;
            row.points = pts.get(pid) == null ? 0 : pts.get(pid);
            row.answerCount = ans.get(pid);
            row.correctCount = correct.get(pid) == null ? 0 : correct.get(pid);
            Integer a = row.answerCount == null ? 0 : row.answerCount;
            row.accuracy = a == 0 ? 0 : (Decimal.valueOf(row.correctCount) * 100 / a).setScale(1);
            row.games = sessionsByPlayer.get(pid) == null ? 0 : sessionsByPlayer.get(pid);
            row.currentStreak = p.Current_Streak_Days__c == null ? 0 : p.Current_Streak_Days__c.intValue();
            row.longestStreak = p.Longest_Streak_Days__c == null ? 0 : p.Longest_Streak_Days__c.intValue();
            row.lastPlayedAt = p.Last_Played_At__c;
            rows.add(row);
        }
    }

    private static void decorate(List<RowDto> rows) {
        if (rows.isEmpty()) return;
        for (Integer i = 0; i < rows.size(); i++) {
            if (rows[i].rank == 1) rows[i].medal = 'gold';
            else if (rows[i].rank == 2) rows[i].medal = 'silver';
            else if (rows[i].rank == 3) rows[i].medal = 'bronze';
        }
        Set<Id> ids = new Set<Id>();
        for (RowDto r : rows) ids.add(r.playerId);
        Map<Id, Integer> counts = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Player__c p, COUNT(Id) c FROM Player_Achievement__c
            WHERE Player__c IN :ids WITH SYSTEM_MODE GROUP BY Player__c
        ]) {
            counts.put((Id) ar.get('p'), (Integer) ar.get('c'));
        }
        for (RowDto r : rows) {
            r.achievementCount = counts.get(r.playerId) == null ? 0 : counts.get(r.playerId);
        }
    }

    private static SummaryDto buildSummary(Id tenantId, Id examId, DateTime since, String wk) {
        SummaryDto s = new SummaryDto();
        s.windowLabel = windowLabel(wk);
        s.generatedAt = System.now();

        String w = ' WHERE Player__c != NULL';
        if (tenantId != null) w += ' AND Player__r.Tenant__c = :tenantId';
        if (examId != null) w += ' AND Trivia_Question__r.Certification_Exam__c = :examId';
        if (since != null) w += ' AND Answered_At__c >= :since';

        List<AggregateResult> tArs = Database.query(
            'SELECT COUNT(Id) n, COUNT_DISTINCT(Player__c) pl, '
            + 'COUNT_DISTINCT(Game_Session__c) g, SUM(Points_Awarded__c) pts '
            + 'FROM Player_Answer__c' + w + ' WITH SYSTEM_MODE'
        );
        if (!tArs.isEmpty()) {
            AggregateResult ar = tArs[0];
            s.totalAnswers = (Integer) ar.get('n');
            s.activePlayers = (Integer) ar.get('pl');
            s.totalGames = (Integer) ar.get('g');
            s.totalPoints = (Decimal) ar.get('pts');
        }
        if (s.totalPoints == null) s.totalPoints = 0;
        if (s.totalAnswers == null) s.totalAnswers = 0;
        if (s.totalGames == null) s.totalGames = 0;
        if (s.activePlayers == null) s.activePlayers = 0;

        Integer correct = 0;
        for (AggregateResult ar2 : (List<AggregateResult>) Database.query(
            'SELECT COUNT(Id) c FROM Player_Answer__c' + w + ' AND Is_Correct__c = true WITH SYSTEM_MODE'
        )) {
            correct = (Integer) ar2.get('c');
        }
        s.avgAccuracy = s.totalAnswers == 0 ? 0 : (Decimal.valueOf(correct) * 100 / s.totalAnswers).setScale(1);

        s.totalPlayers = tenantId == null
            ? [SELECT COUNT() FROM Player__c WITH SYSTEM_MODE]
            : [SELECT COUNT() FROM Player__c WHERE Tenant__c = :tenantId WITH SYSTEM_MODE];

        List<Player__c> topStreakRows = tenantId == null
            ? [SELECT Longest_Streak_Days__c FROM Player__c
               WITH SYSTEM_MODE ORDER BY Longest_Streak_Days__c DESC NULLS LAST LIMIT 1]
            : [SELECT Longest_Streak_Days__c FROM Player__c WHERE Tenant__c = :tenantId
               WITH SYSTEM_MODE ORDER BY Longest_Streak_Days__c DESC NULLS LAST LIMIT 1];
        s.topStreak = (topStreakRows.isEmpty() || topStreakRows[0].Longest_Streak_Days__c == null)
            ? 0 : topStreakRows[0].Longest_Streak_Days__c.intValue();
        return s;
    }

    private static DateTime windowStart(String wk) {
        if (wk == null) return null;
        if (wk == 'today') {
            Date d = Date.today();
            return DateTime.newInstanceGmt(d.year(), d.month(), d.day(), 0, 0, 0);
        }
        if (wk == '7d' || wk == 'week') return System.now().addDays(-7);
        if (wk == '30d' || wk == 'month') return System.now().addDays(-30);
        return null;
    }

    private static String windowLabel(String wk) {
        if (wk == 'today') return 'Today';
        if (wk == '7d' || wk == 'week') return 'Last 7 days';
        if (wk == '30d' || wk == 'month') return 'Last 30 days';
        return 'All time';
    }
}