/**
 * Leaderboards and player stats.
 * Returns Slack Block Kit JSON for /certgame leaderboard and /certgame stats.
 */
public with sharing class CertGameLeaderboardService {
    public static String renderLeaderboard(
        String slackTeamId,
        String slackChannelId,
        List<String> args
    ) {
        Tenant__c tenant = CertGameTenantService.findTenant(slackTeamId);
        if (tenant == null)
            return CertGameSlackRenderService.text(
                CertGameStrings.NOT_INSTALLED,
                true
            );

        String scope = args != null &&
            args.size() > 1
            ? args[1].toLowerCase()
            : 'week';
        DateTime since = scope == 'all'
            ? null
            : scope == 'day'
                  ? System.now().addDays(-1)
                  : scope == 'month'
                        ? System.now().addDays(-30)
                        : System.now().addDays(-7);

        Id tId = tenant.Id;
        Map<Id, Decimal> totals = CertGameLeaderboardReader.tallyPoints(
            tId,
            since
        );

        Map<Id, Player__c> pmap = CertGameLeaderboardReader.playersByIds(
            totals.keySet()
        );

        List<Map<String, Object>> rows = new List<Map<String, Object>>();
        for (Id pid : totals.keySet()) {
            rows.add(
                new Map<String, Object>{
                    'pid' => pid,
                    'name' => pmap.containsKey(pid)
                        ? pmap.get(pid).Display_Name__c
                        : 'Unknown',
                    'points' => totals.get(pid).intValue()
                }
            );
        }
        rows.sort(new ByPointsDesc());
        if (rows.size() > 10) {
            List<Map<String, Object>> top = new List<Map<String, Object>>();
            for (Integer i = 0; i < 10; i++)
                top.add(rows[i]);
            rows = top;
        }

        return CertGameSlackRenderService.leaderboardBlocks(
            'Leaderboard — ' + scope,
            rows
        );
    }

    public static String renderStats(String slackTeamId, String slackUserId) {
        Tenant__c tenant = CertGameTenantService.findTenant(slackTeamId);
        if (tenant == null)
            return CertGameSlackRenderService.text(
                CertGameStrings.NOT_INSTALLED,
                true
            );
        Player__c p = CertGameTenantService.findPlayer(tenant.Id, slackUserId);
        if (p == null)
            return CertGameSlackRenderService.text(
                CertGameStrings.NO_STATS,
                true
            );

        AggregateResult[] ars = CertGameLeaderboardReader.statsTotals(p.Id);
        AggregateResult[] arsCorrect = CertGameLeaderboardReader.statsCorrect(
            p.Id
        );
        Integer total = ars.isEmpty() ? 0 : (Integer) ars[0].get('total');
        Decimal pts = ars.isEmpty()
            ? 0
            : (Decimal) (ars[0].get('pts') == null ? 0 : ars[0].get('pts'));
        Integer correctCnt = arsCorrect.isEmpty()
            ? 0
            : (Integer) (arsCorrect[0].get('c') == null
                  ? 0
                  : arsCorrect[0].get('c'));
        Decimal acc = total == 0 ? 0 : (Decimal) correctCnt * 100 / total;

        String txt =
            '*Your stats*\n' +
            'Answers: ' +
            total +
            '\n' +
            'Correct: ' +
            correctCnt +
            ' (' +
            acc.setScale(1) +
            '%)\n' +
            'Total points: ' +
            pts.intValue();
        return CertGameSlackRenderService.text(txt, true);
    }

    private class ByPointsDesc implements Comparator<Map<String, Object>> {
        public Integer compare(Map<String, Object> a, Map<String, Object> b) {
            Integer ap = (Integer) a.get('points');
            Integer bp = (Integer) b.get('points');
            if (ap == bp)
                return 0;
            return ap < bp ? 1 : -1;
        }
    }
}