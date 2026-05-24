/**
 * Renders the "/certgame report" slash subcommand response: an ephemeral card with
 * a theme picker + signed link to the rendered Study Guide.
 *
 * Also exposes the URL-builder used by the App Home Study Guide button.
 *
 * Sharing: with sharing - invoked from SlackCertGameCommandHandler which is itself
 * with sharing. Underlying mintReportUrl + WebSessionToken handle their own context.
 */
public with sharing class CertGameStudyGuideService {

    public static String renderReport(String slackTeamId, String slackUserId) {
        Tenant__c tenant = CertGameTenantService.findTenant(slackTeamId);
        if (tenant == null) {
            return CertGameSlackRenderService.text(CertGameStrings.NOT_INSTALLED, true);
        }
        Player__c p = CertGameTenantService.findPlayer(tenant.Id, slackUserId);
        if (p == null) {
            return CertGameSlackRenderService.text(
                ':information_source: Play a round first - your Study Guide unlocks after at least one answer.',
                true
            );
        }
        Id examId = mostRecentExamForPlayer(p.Id);
        List<CertGameReadinessReportService.ThemeOption> themes = safeListThemes();

        return CertGameSlackRenderService.studyGuideCard(p.Id, examId, themes);
    }

    /** Convenience for App Home / finale: signed URL using the default theme. */
    public static String mintDefaultUrl(Id playerId, Id examId) {
        return CertGameReadinessReportController.mintReportUrl(playerId, examId, null);
    }

    private static Id mostRecentExamForPlayer(Id playerId) {
        if (playerId == null) return null;
        List<Game_Session__c> sessions = [
            SELECT Certification_Exam__c
            FROM Game_Session__c
            WHERE Player__c = :playerId AND Certification_Exam__c != null
            WITH SYSTEM_MODE
            ORDER BY CreatedDate DESC LIMIT 1
        ];
        return sessions.isEmpty() ? null : sessions[0].Certification_Exam__c;
    }

    private static List<CertGameReadinessReportService.ThemeOption> safeListThemes() {
        try {
            return CertGameReadinessReportService.listActiveThemes();
        } catch (Exception e) {
            // Object/permission may not be deployed yet during partial rollouts.
            AppLogger.warn('CertGameStudyGuideService', 'listThemes', e.getMessage());
            return new List<CertGameReadinessReportService.ThemeOption>();
        }
    }
}
