/**
 * without-sharing reader for leaderboard/stats queries.
 * Player_Answer__c / Player__c are owned by whichever user processed the originating
 * Slack callback, but queries can be invoked from any Slack context (incl. Site Guest),
 * so the running user's sharing would otherwise hide rows. Tenant scoping in the
 * WHERE clause is the trust boundary.
 */
public without sharing class CertGameLeaderboardReader {

    public static Map<Id, Decimal> tallyPoints(Id tId, DateTime since) {
        Map<Id, Decimal> totals = new Map<Id, Decimal>();
        String soql = 'SELECT Player__c, Points_Awarded__c FROM Player_Answer__c '
                    + 'WHERE Player__r.Tenant__c = :tId';
        if (since != null) soql += ' AND Answered_At__c >= :since';
        soql += ' WITH SYSTEM_MODE LIMIT 10000';
        for (Player_Answer__c pa : Database.query(soql)) {
            if (pa.Points_Awarded__c == null) continue;
            Decimal cur = totals.containsKey(pa.Player__c) ? totals.get(pa.Player__c) : 0;
            totals.put(pa.Player__c, cur + pa.Points_Awarded__c);
        }
        return totals;
    }

    public static Map<Id, Player__c> playersByIds(Set<Id> ids) {
        return new Map<Id, Player__c>([
            SELECT Id, Display_Name__c FROM Player__c WHERE Id IN :ids WITH SYSTEM_MODE
        ]);
    }

    public static AggregateResult[] statsTotals(Id playerId) {
        return [
            SELECT COUNT(Id) total, SUM(Points_Awarded__c) pts
            FROM Player_Answer__c WHERE Player__c = :playerId WITH SYSTEM_MODE
        ];
    }

    public static AggregateResult[] statsCorrect(Id playerId) {
        return [
            SELECT COUNT(Id) c FROM Player_Answer__c
            WHERE Player__c = :playerId AND Is_Correct__c = true WITH SYSTEM_MODE
        ];
    }
}