/**
 * Sends a self-test DM to the invoking Slack user and returns an ephemeral status card.
 * Used by `/certgame notify-test` and the App Home "Test notifications" button.
 *
 * Purpose: prove outbound Slack callouts (chat.postMessage via Bot token) work, independent
 * of any game / scoring / scheduler path. If this fails, the doctor's error log will show
 * the exact Slack callout error (token, scopes, External Credential, etc.).
 */
public with sharing class CertGameNotificationTestService {

    public static String run(String slackTeamId, String slackUserId) {
        if (String.isBlank(slackUserId)) {
            return CertGameSlackRenderService.notifyTestResult(false, 'No Slack user id on the request.');
        }
        try {
            String text = ':bell: *Cert Game notification self-test*\n'
                + 'If you can read this DM, outbound Slack messaging from Salesforce works.\n'
                + 'Triggered at ' + System.now().format() + ' (org local time).';
            List<Object> blocks = new List<Object>();
            blocks.add(CertGameSlackRenderService.section(text));
            Map<String, Object> resp = SlackApiClient.postMessage(slackUserId, 'Cert Game notification self-test', blocks);
            Boolean ok = resp != null && Boolean.valueOf(resp.get('ok'));
            String detail = ok
                ? 'Sent. Check your Cert Game DM.'
                : 'Slack responded `ok=false`: ' + (resp == null ? 'no response' : String.valueOf(resp.get('error')));
            return CertGameSlackRenderService.notifyTestResult(ok, detail);
        } catch (Exception e) {
            return CertGameSlackRenderService.notifyTestResult(false,
                e.getTypeName() + ': ' + (e.getMessage() == null ? '' : e.getMessage()));
        }
    }
}