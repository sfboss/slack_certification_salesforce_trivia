/**
 * Stub services to be expanded in later phases. Centralized here so handlers compile.
 */
public with sharing class CertGameAppHomeService {
    public static String publishHome(String slackTeamId, String slackUserId) {
        Tenant__c t = CertGameTenantService.getOrCreateTenant(slackTeamId);
        Player__c p = CertGameTenantService.getOrCreatePlayer(
            t.Id,
            slackUserId
        );
        Map<String, Object> view = (Map<String, Object>) JSON.deserializeUntyped(
            CertGameSlackRenderService.appHomeView(
                new Map<String, Object>{ 'tenant' => t.Id, 'player' => p.Id }
            )
        );
        try {
            SlackApiClient.publishHome(slackUserId, view);
        } catch (Exception e) {
            AppLogger.warn('AppHome', 'publish', e.getMessage());
        }
        return '';
    }
}