/**
 * Visualforce controller for CertGameReadinessReport.page.
 *
 * Reads `?p={playerId}&t={token}` from the URL, verifies the HMAC token via
 * WebSessionToken, then renders the merged HTML via CertGameReadinessReportService.
 *
 * Sharing: without sharing because guest user has no record sharing.
 */
public without sharing class CertGameReadinessReportController {

    public String mergedHtml { get; private set; }
    public String errorMessage { get; private set; }

    public CertGameReadinessReportController() {
        try {
            Map<String, String> params = ApexPages.currentPage().getParameters();
            String pid = params.get('p');
            String examId = params.get('e');
            String token = params.get('t');
            String demo = params.get('demo');
            String theme = params.get('theme');

            Id playerId;
            if (String.isNotBlank(pid)) {
                try { playerId = (Id) pid; } catch (Exception e) { errorMessage = 'Invalid player id.'; return; }
            }

            // Demo mode renders the template with a freshly-found player so a logged-in
            // admin can preview without minting a token. Skip token check.
            if (demo == '1') {
                if (playerId == null) {
                    List<Player__c> ps = [SELECT Id FROM Player__c LIMIT 1];
                    if (!ps.isEmpty()) playerId = ps[0].Id;
                }
                if (playerId == null) { errorMessage = 'No player records exist to preview.'; return; }
            } else {
                WebSessionToken.TokenResult tr = WebSessionToken.verify(token);
                if (!tr.valid || tr.playerId == null) {
                    errorMessage = 'This report link is invalid or expired.';
                    return;
                }
                playerId = tr.playerId;
            }

            Id eId;
            if (String.isNotBlank(examId)) {
                try { eId = (Id) examId; } catch (Exception ignored) { eId = null; }
            }
            mergedHtml = CertGameReadinessReportService.renderHtml(playerId, eId, theme);
        } catch (Exception e) {
            errorMessage = 'Report failed to render: ' + e.getMessage();
            AppLogger.error('CertGameReadinessReportController', 'ctor', e.getMessage(), e);
        }
    }

    /** Public mint helper used by Slack render code to embed a signed report URL. */
    public static String mintReportUrl(Id playerId, Id examId) {
        return mintReportUrl(playerId, examId, null);
    }

    public static String mintReportUrl(Id playerId, Id examId, String themeKey) {
        if (playerId == null) return null;
        String token = WebSessionToken.mint(playerId);
        String base = Site.getBaseSecureUrl();
        if (String.isBlank(base)) {
            // Fallback when invoked outside a site context (tests, dev console).
            base = URL.getOrgDomainUrl().toExternalForm() + '/certgame';
        }
        String url = base + '/CertGameReadinessReport?p=' + playerId + '&t=' + EncodingUtil.urlEncode(token, 'UTF-8');
        if (examId != null) url += '&e=' + examId;
        if (String.isNotBlank(themeKey)) url += '&theme=' + EncodingUtil.urlEncode(themeKey, 'UTF-8');
        return url;
    }
}