/**
 * Leaderboards and player stats.
 * Returns Slack Block Kit JSON for /certgame leaderboard and /certgame stats.
 */
public with sharing class CertGameLeaderboardService {

    public static String renderLeaderboard(String slackTeamId, String slackChannelId, List<String> args) {
        Tenant__c tenant = CertGameTenantService.findTenant(slackTeamId);
        if (tenant == null) return CertGameSlackRenderService.text(CertGameStrings.NOT_INSTALLED, true);

        String scope = args != null && args.size() > 1 ? args[1].toLowerCase() : 'week';
        DateTime since = scope == 'all' ? null
                       : scope == 'day'  ? System.now().addDays(-1)
                       : scope == 'month' ? System.now().addDays(-30)
                       : System.now().addDays(-7);

        Map<Id, Decimal> totals = new Map<Id, Decimal>();
        String soql = 'SELECT Player__c, Points_Awarded__c FROM Player_Answer__c '
                    + 'WHERE Player__r.Tenant__c = :tId';
        Id tId = tenant.Id;
        if (since != null) soql += ' AND Answered_At__c >= :since';
        soql += ' WITH USER_MODE LIMIT 10000';
        for (Player_Answer__c pa : Database.query(soql)) {
            if (pa.Points_Awarded__c == null) continue;
            Decimal cur = totals.containsKey(pa.Player__c) ? totals.get(pa.Player__c) : 0;
            totals.put(pa.Player__c, cur + pa.Points_Awarded__c);
        }

        Map<Id, Player__c> pmap = new Map<Id, Player__c>([
            SELECT Id, Display_Name__c FROM Player__c WHERE Id IN :totals.keySet() WITH USER_MODE
        ]);

        List<Map<String, Object>> rows = new List<Map<String, Object>>();
        for (Id pid : totals.keySet()) {
            rows.add(new Map<String, Object>{
                'pid' => pid,
                'name' => pmap.containsKey(pid) ? pmap.get(pid).Display_Name__c : 'Unknown',
                'points' => totals.get(pid).intValue()
            });
        }
        rows.sort(new ByPointsDesc());
        if (rows.size() > 10) {
            List<Map<String, Object>> top = new List<Map<String, Object>>();
            for (Integer i = 0; i < 10; i++) top.add(rows[i]);
            rows = top;
        }

        return CertGameSlackRenderService.leaderboardBlocks(
            'Leaderboard — ' + scope,
            rows
        );
    }

    public static String renderStats(String slackTeamId, String slackUserId) {
        Tenant__c tenant = CertGameTenantService.findTenant(slackTeamId);
        if (tenant == null) return CertGameSlackRenderService.text(CertGameStrings.NOT_INSTALLED, true);
        Player__c p = CertGameTenantService.findPlayer(tenant.Id, slackUserId);
        if (p == null) return CertGameSlackRenderService.text(CertGameStrings.NO_STATS, true);

        AggregateResult[] ars = [
            SELECT COUNT(Id) total, SUM(Points_Awarded__c) pts,
                   SUM(CASE WHEN Is_Correct__c = true THEN 1 ELSE 0 END) correctCnt
            FROM Player_Answer__c WHERE Player__c = :p.Id WITH USER_MODE
        ];
        Integer total = ars.isEmpty() ? 0 : (Integer) ars[0].get('total');
        Decimal pts = ars.isEmpty() ? 0 : (Decimal)(ars[0].get('pts') == null ? 0 : ars[0].get('pts'));
        Integer correctCnt = ars.isEmpty() ? 0 : (Integer)(ars[0].get('correctCnt') == null ? 0 : ars[0].get('correctCnt'));
        Decimal acc = total == 0 ? 0 : (Decimal) correctCnt * 100 / total;

        String txt = '*Your stats*\n'
                   + 'Answers: ' + total + '\n'
                   + 'Correct: ' + correctCnt + ' (' + acc.setScale(1) + '%)\n'
                   + 'Total points: ' + pts.intValue();
        return CertGameSlackRenderService.text(txt, true);
    }

    private class ByPointsDesc implements Comparator<Map<String, Object>> {
        public Integer compare(Map<String, Object> a, Map<String, Object> b) {
            Integer ap = (Integer) a.get('points');
            Integer bp = (Integer) b.get('points');
            if (ap == bp) return 0;
            return ap < bp ? 1 : -1;
        }
    }
}
