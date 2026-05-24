/**
 * Handles `/certgame ...` slash commands.
 * Sub-commands: help, play, leaderboard, stats, plan, billing.
 */
public with sharing class SlackCertGameCommandHandler {
    public static String handle(Map<String, Object> payload) {
        String text = String.valueOf(payload.get('text'));
        String teamId = String.valueOf(payload.get('team_id'));
        String userId = String.valueOf(payload.get('user_id'));
        String channelId = String.valueOf(payload.get('channel_id'));
        String triggerId = String.valueOf(payload.get('trigger_id'));

        if (String.isBlank(text))
            text = 'help';
        List<String> parts = text.trim().split('\\s+');
        String sub = parts[0].toLowerCase();

        // NOTE: Do not do DML (audit/applog inserts) here. Subcommands plan/billing make a
        // Slack callout (views.open), and Apex forbids callouts after DML in the same
        // transaction. Slack_Event_Log__c already captures every slash command (written by
        // SlackRequestRouter AFTER dispatch returns).

        if (sub == 'help')
            return CertGameSlackRenderService.help();
        if (sub == 'play')
            return CertGameSessionService.startQuickGameFromSlack(
                teamId,
                userId,
                channelId,
                parts
            );
        if (sub == 'challenge' || sub == 'duel')
            return CertGameDuelService.openChallengeFromSlack(
                teamId,
                userId,
                channelId,
                parts
            );
        if (sub == 'games')
            return CertGameExamCatalogService.renderForSlack(teamId);
        if (sub == 'leaderboard')
            return CertGameLeaderboardService.renderLeaderboard(
                teamId,
                channelId,
                parts
            );
        if (sub == 'stats')
            return CertGameLeaderboardService.renderStats(teamId, userId);
        if (sub == 'report' || sub == 'studyguide' || sub == 'study')
            return CertGameStudyGuideService.renderReport(teamId, userId);
        if (sub == 'plan')
            return CertGameStudyPlanService.openPlanModal(
                teamId,
                userId,
                triggerId
            );
        if (sub == 'billing')
            return CertGameBillingService.openBillingModal(
                teamId,
                userId,
                triggerId
            );
        if (sub == 'debug')
            return renderDebug();
        if (sub == 'doctor')
            return CertGameDoctorService.run(teamId, userId);
        if (sub == 'whoami' || sub == 'me' || sub == 'google')
            return CertGameWhoamiService.run(teamId, userId);
        if (
            sub == 'notify-test' ||
            sub == 'notify_test' ||
            sub == 'notifytest'
        ) {
            return CertGameNotificationTestService.run(teamId, userId);
        }

        return CertGameSlackRenderService.text(
            CertGameStrings.UNKNOWN_COMMAND,
            true
        );
    }

    private static String renderDebug() {
        DateTime since = System.now().addHours(-1);
        List<App_Log__c> rows = [
            SELECT
                Level__c,
                Class_Name__c,
                Method_Name__c,
                Message__c,
                Correlation_Id__c,
                Occurred_At__c
            FROM App_Log__c
            WHERE Occurred_At__c >= :since
            ORDER BY Occurred_At__c DESC
            LIMIT 5
        ];
        return CertGameSlackRenderService.debugLogBlocks(rows);
    }
}