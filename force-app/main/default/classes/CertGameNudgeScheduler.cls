/**
 * Daily nudge scheduler. Schedules itself nightly and sends Slack DMs to players who
 * are behind their daily question goal in their active Study_Plan__c.
 *
 * To schedule:
 *   System.schedule('Cert Game Daily Nudge', '0 0 14 * * ?', new CertGameNudgeScheduler());
 */
public with sharing class CertGameNudgeScheduler implements Schedulable {

    public void execute(SchedulableContext sc) {
        runOnce();
    }

    public static void runOnce() {
        Date today = System.today();
        DateTime startOfDay = DateTime.newInstance(today.year(), today.month(), today.day(), 0, 0, 0);

        List<Study_Plan__c> plans = [
            SELECT Id, Player__c, Player__r.Slack_User_Id__c, Player__r.Tenant__c,
                   Daily_Questions__c, Certification_Exam__c
            FROM Study_Plan__c WHERE Status__c = 'Active' WITH USER_MODE LIMIT 1000
        ];
        if (plans.isEmpty()) return;

        // Count today's answers per player
        Set<Id> playerIds = new Set<Id>();
        for (Study_Plan__c p : plans) playerIds.add(p.Player__c);

        Map<Id, Integer> answeredToday = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Player__c pid, COUNT(Id) cnt FROM Player_Answer__c
            WHERE Player__c IN :playerIds AND Answered_At__c >= :startOfDay
            WITH USER_MODE GROUP BY Player__c
        ]) {
            answeredToday.put((Id) ar.get('pid'), (Integer) ar.get('cnt'));
        }

        for (Study_Plan__c p : plans) {
            Integer answered = answeredToday.containsKey(p.Player__c) ? answeredToday.get(p.Player__c) : 0;
            Integer goal = p.Daily_Questions__c == null ? 5 : p.Daily_Questions__c.intValue();
            if (answered >= goal) continue;
            try {
                Map<String, Object> openResp = SlackApiClient.openConversation(new List<String>{ p.Player__r.Slack_User_Id__c });
                String channel = extractChannel(openResp);
                if (channel == null) continue;
                String msg = ':bell: Daily Cert Game nudge — you have answered ' + answered
                           + ' of ' + goal + ' questions today. Try `/certgame play`!';
                SlackApiClient.postMessage(channel, msg, null);
            } catch (Exception e) {
                AppLogger.warn('Nudge', 'send', 'Player ' + p.Player__c + ': ' + e.getMessage());
            }
        }
    }

    private static String extractChannel(Map<String, Object> resp) {
        if (resp == null) return null;
        Object ch = resp.get('channel');
        if (ch instanceof Map<String, Object>) return (String) ((Map<String, Object>) ch).get('id');
        return null;
    }
}
