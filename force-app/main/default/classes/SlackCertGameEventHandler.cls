/**
 * Handles Slack Events API event_callback events.
 * Currently supported: app_home_opened (render personalized App Home).
 */
public with sharing class SlackCertGameEventHandler {

    public static String handle(Map<String, Object> payload) {
        Map<String, Object> ev = (Map<String, Object>) payload.get('event');
        if (ev == null) return '';
        String type = (String) ev.get('type');
        String teamId = (String) payload.get('team_id');
        String userId = (String) ev.get('user');

        AuditLogger.log('event_callback', 'Slack', userId, null, type, userId);

        if (type == 'app_home_opened') {
            return CertGameAppHomeService.publishHome(teamId, userId);
        }
        if (type == 'app_uninstalled' || type == 'tokens_revoked') {
            return CertGameTenantService.handleUninstall(teamId);
        }
        return '';
    }
}
