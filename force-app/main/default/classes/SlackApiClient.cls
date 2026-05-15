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

    private static Map<String, Object> call(String method, Map<String, Object> body) {
        Integer attempts = 0;
        Map<String, Object> parsed = null;
        while (attempts < 2) {
            attempts++;
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:Slack_Bot/' + method);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json; charset=utf-8');
            req.setBody(JSON.serialize(body));
            req.setTimeout(20000);
            HttpResponse resp;
            try {
                resp = new Http().send(req);
            } catch (Exception e) {
                AppLogger.error('SlackApiClient', method, 'Callout exception', e);
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
                AppLogger.warn('SlackApiClient', method, 'Slack returned not-ok: ' + err);
            }
            return parsed;
        }
        return parsed;
    }
}
