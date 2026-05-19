/**
 * Handles Slack modal view_submission / view_closed.
 * callback_id format: `domain:resource[:id]`.
 */
public with sharing class SlackCertGameModalHandler {

    public static String handle(Map<String, Object> payload) {
        Map<String, Object> view = (Map<String, Object>) payload.get('view');
        if (view == null) return '';
        String callbackId = (String) view.get('callback_id');
        if (String.isBlank(callbackId)) return '';

        String teamId = extractTeamId(payload);
        String userId = extractUserId(payload);
        AuditLogger.log('view_submission', 'Slack', userId, null, callbackId, userId);

        List<String> parts = callbackId.split(':');
        String domain = parts.size() > 0 ? parts[0] : '';
        String resource = parts.size() > 1 ? parts[1] : '';

        if (domain == 'plan' && resource == 'create') {
            return CertGameStudyPlanService.handlePlanSubmission(teamId, userId, view);
        }
        if (domain == 'billing' && resource == 'upgrade') {
            return CertGameBillingService.handleUpgradeSubmission(teamId, userId, view);
        }
        if (domain == 'tournament' && resource == 'create') {
            return CertGameTournamentService.handleCreateSubmission(teamId, userId, view);
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