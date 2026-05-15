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

        if (String.isBlank(text)) text = 'help';
        List<String> parts = text.trim().split('\\s+');
        String sub = parts[0].toLowerCase();

        AuditLogger.log('slash_command', 'Slack', userId, null, text, userId);

        if (sub == 'help') return CertGameSlackRenderService.help();
        if (sub == 'play') return CertGameSessionService.startQuickGameFromSlack(teamId, userId, channelId, parts);
        if (sub == 'leaderboard') return CertGameLeaderboardService.renderLeaderboard(teamId, channelId, parts);
        if (sub == 'stats') return CertGameLeaderboardService.renderStats(teamId, userId);
        if (sub == 'plan') return CertGameStudyPlanService.openPlanModal(teamId, userId, triggerId);
        if (sub == 'billing') return CertGameBillingService.openBillingModal(teamId, userId, triggerId);

        return CertGameSlackRenderService.text(CertGameStrings.UNKNOWN_COMMAND, true);
    }
}
