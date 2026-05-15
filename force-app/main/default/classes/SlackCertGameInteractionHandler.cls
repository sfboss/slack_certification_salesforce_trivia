/**
 * Handles Slack block_actions interactivity.
 * action_id format: `domain:verb:resourceId[:extra]`.
 */
public with sharing class SlackCertGameInteractionHandler {

    public static String handle(Map<String, Object> payload) {
        List<Object> actions = (List<Object>) payload.get('actions');
        if (actions == null || actions.isEmpty()) return '';
        Map<String, Object> act = (Map<String, Object>) actions[0];
        String actionId = (String) act.get('action_id');
        if (String.isBlank(actionId)) return '';

        List<String> parts = actionId.split(':');
        String domain = parts.size() > 0 ? parts[0] : '';
        String verb   = parts.size() > 1 ? parts[1] : '';

        String teamId = extractTeamId(payload);
        String userId = extractUserId(payload);

        AuditLogger.log('block_action', 'Slack', userId, null, actionId, userId);

        if (domain == 'game' && verb == 'answer') {
            String roundId = parts.size() > 2 ? parts[2] : null;
            String choiceId = parts.size() > 3 ? parts[3] : null;
            return CertGameSessionService.recordAnswerFromSlack(teamId, userId, roundId, choiceId);
        }
        if (domain == 'plan' && verb == 'open') {
            String triggerId = (String) payload.get('trigger_id');
            return CertGameStudyPlanService.openPlanModal(teamId, userId, triggerId);
        }
        if (domain == 'tournament' && verb == 'join') {
            String tournamentId = parts.size() > 2 ? parts[2] : null;
            return CertGameTournamentService.joinFromSlack(teamId, userId, tournamentId);
        }
        return '';
    }

    private static String extractTeamId(Map<String, Object> payload) {
        Object t = payload.get('team');
        if (t instanceof Map<String, Object>) return (String) ((Map<String, Object>) t).get('id');
        return (String) payload.get('team_id');
    }
    private static String extractUserId(Map<String, Object> payload) {
        Object u = payload.get('user');
        if (u instanceof Map<String, Object>) return (String) ((Map<String, Object>) u).get('id');
        return (String) payload.get('user_id');
    }
}
