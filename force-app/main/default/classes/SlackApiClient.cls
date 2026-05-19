/**
 * Thin wrapper around Slack Web API endpoints we use:
 *  - chat.postMessage
 *  - chat.update
 *  - views.publish
 *  - views.open
 *  - conversations.open
 *
 * All callouts use the Slack_Bot Named Credential (callout:Slack_Bot).
 * Retries 5xx and Slack rate_limited responses up to 2 times with simple backoff.
 */
public with sharing class SlackApiClient {

    public class SlackApiException extends Exception {}

    public static Map<String, Object> postMessage(String channel, String text, List<Object> blocks) {
        Map<String, Object> body = new Map<String, Object>{
            'channel' => channel,
            'text' => text == null ? '' : text
        };
        if (blocks != null) body.put('blocks', blocks);
        return call('chat.postMessage', body);
    }

    public static Map<String, Object> updateMessage(String channel, String ts, String text, List<Object> blocks) {
        Map<String, Object> body = new Map<String, Object>{
            'channel' => channel, 'ts' => ts, 'text' => text == null ? '' : text
        };
        if (blocks != null) body.put('blocks', blocks);
        return call('chat.update', body);
    }

    public static Map<String, Object> publishHome(String userId, Map<String, Object> view) {
        return call('views.publish', new Map<String, Object>{
            'user_id' => userId, 'view' => view
        });
    }

    public static Map<String, Object> openView(String triggerId, Map<String, Object> view) {
        return call('views.open', new Map<String, Object>{
            'trigger_id' => triggerId, 'view' => view
        });
    }

    public static Map<String, Object> openConversation(List<String> userIds) {
        return call('conversations.open', new Map<String, Object>{
            'users' => String.join(userIds, ',')
        });
    }

    /**
     * Async wrappers for use when the caller has already performed DML in the same
     * transaction (Apex forbids callouts after DML). Blocks are passed as JSON because
     * @future cannot accept complex types.
     */
    @future(callout=true)
    public static void updateMessageAsync(String channel, String ts, String text, String blocksJson) {
        List<Object> blocks = null;
        if (String.isNotBlank(blocksJson)) {
            try { blocks = (List<Object>) JSON.deserializeUntyped(blocksJson); } catch (Exception e) {}
        }
        updateMessage(channel, ts, text, blocks);
    }

    @future(callout=true)
    public static void postMessageAsync(String channel, String text, String blocksJson) {
        List<Object> blocks = null;
        if (String.isNotBlank(blocksJson)) {
            try { blocks = (List<Object>) JSON.deserializeUntyped(blocksJson); } catch (Exception e) {}
        }
        postMessage(channel, text, blocks);
    }

    /**
     * POSTs a response envelope to a Slack interactivity response_url. response_url
     * works for any message that triggered an interaction regardless of how it was
     * originally posted, and supports `replace_original` / `delete_original` /
     * `response_type`. Use this to update a question card from a block_actions handler
     * AFTER DML in the same transaction (separate async tx → callouts are legal).
     */
    @future(callout=true)
    public static void postToResponseUrlAsync(String url, String envelopeJson) {
        if (String.isBlank(url) || String.isBlank(envelopeJson)) return;
        HttpRequest req = new HttpRequest();
        req.setEndpoint(url);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json; charset=utf-8');
        req.setBody(envelopeJson);
        req.setTimeout(20000);
        try {
            HttpResponse resp = new Http().send(req);
            Integer sc = resp.getStatusCode();
            if (sc >= 300) {
                AppLogger.writeSafe('WARN', 'SlackApiClient', 'postToResponseUrl',
                    'response_url POST failed: status=' + sc + ' body='
                        + (resp.getBody() == null ? '' : resp.getBody().left(500)),
                    null);
            }
        } catch (Exception e) {
            AppLogger.writeSafe('WARN', 'SlackApiClient', 'postToResponseUrl',
                'response_url POST exception: ' + e.getMessage(), null);
        }
    }

    private static Map<String, Object> call(String method, Map<String, Object> body) {
        Integer attempts = 0;
        Map<String, Object> parsed = null;
        App_Setting__mdt s = AppSettings.get();
        // Guest-user-safe path: if a bot token is configured in App_Setting__mdt,
        // bypass the Slack_Bot Named/External Credential entirely (Site Guest
        // Users cannot read UserExternalCredential, which would block the merge).
        String directToken = s == null ? null : s.Slack_Bot_Token__c;
        Boolean useDirect = String.isNotBlank(directToken);
        while (attempts < 2) {
            attempts++;
            HttpRequest req = new HttpRequest();
            if (useDirect) {
                req.setEndpoint('https://slack.com/api/' + method);
                req.setHeader('Authorization', 'Bearer ' + directToken);
            } else {
                req.setEndpoint('callout:Slack_Bot/' + method);
            }
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json; charset=utf-8');
            req.setBody(JSON.serialize(body));
            req.setTimeout(20000);
            HttpResponse resp;
            try {
                resp = new Http().send(req);
            } catch (Exception e) {
                // Do NOT insert App_Log__c here: a retry would then hit
                // "uncommitted work pending" on the next callout. System.debug
                // captures the failure in the transaction log instead.
                System.debug(LoggingLevel.ERROR, '[SlackApiClient] ' + method + ' attempt ' + attempts
                    + ' callout exception: ' + e.getTypeName() + ': ' + e.getMessage());
                if (attempts >= 2) throw new SlackApiException('Slack callout failed: ' + e.getMessage());
                continue;
            }
            Integer code = resp.getStatusCode();
            String respBody = resp.getBody();
            if (code >= 500 && attempts < 2) continue;
            try { parsed = (Map<String, Object>) JSON.deserializeUntyped(respBody); }
            catch (Exception e) { throw new SlackApiException('Bad Slack response: ' + respBody); }
            Boolean ok = parsed.get('ok') == true;
            if (!ok) {
                String err = String.valueOf(parsed.get('error'));
                if (err == 'rate_limited' && attempts < 2) continue;
                // System.debug for inline trace; @future insert so the failure also lands
                // in App_Log__c without tripping "uncommitted work pending" on follow-up
                // callouts in the same transaction.
                System.debug(LoggingLevel.WARN, '[SlackApiClient] ' + method + ' Slack returned not-ok: ' + err);
                AppLogger.writeSafe('WARN', 'SlackApiClient', method,
                    'Slack ok=false: ' + err + ' :: req=' + JSON.serialize(body).left(2000)
                        + ' :: resp=' + (respBody == null ? '' : respBody.left(2000)),
                    null);
            }
            return parsed;
        }
        return parsed;
    }
}