/**
 * Apex REST endpoint exposed publicly via a Salesforce Site for Slack to call.
 * URL: /services/apexrest/slack/events
 *
 * Returns 200 immediately on success (Slack requires < 3s ack).
 * Heavy work is delegated by handlers to async Queueables.
 */
@RestResource(urlMapping='/slack/events')
global without sharing class SlackEventsRestResource {
    // without sharing: this endpoint is hit by Slack via a Site guest user; we must be able to
    // upsert Slack_Event_Log__c regardless of guest user sharing. All downstream business logic
    // re-establishes sharing via with-sharing service classes.

    @HttpPost
    global static void doPost() {
        RestRequest req = RestContext.request;
        RestResponse resp = RestContext.response;
        try {
            Map<String, String> headers = req.headers == null ? new Map<String, String>() : req.headers;
            Blob rawBlob = req.requestBody;
            String body = rawBlob == null ? '' : rawBlob.toString();
            String contentType = headers.containsKey('Content-Type') ? headers.get('Content-Type')
                              : headers.containsKey('content-type') ? headers.get('content-type') : '';

            // Salesforce Sites consumes application/x-www-form-urlencoded bodies
            // into RestRequest.params before Apex REST sees the raw bytes. Rebuild
            // the body in Slack's canonical slash-command/interaction key order so
            // HMAC signature verification can succeed.
            if (String.isBlank(body) && req.params != null && !req.params.isEmpty()
                    && contentType != null && contentType.startsWithIgnoreCase('application/x-www-form-urlencoded')) {
                body = reconstructFormBody(req.params);
            }

            SlackRequestRouter.RouterResult r = SlackRequestRouter.dispatch(headers, body, contentType);
            resp.statusCode = r.statusCode;
            resp.addHeader('Content-Type', 'application/json; charset=utf-8');
            resp.responseBody = Blob.valueOf(r.body == null ? '' : r.body);
        } catch (Exception e) {
            AppLogger.error('SlackEventsRestResource', 'doPost', 'Unhandled Slack endpoint error', e);
            resp.statusCode = 200;
            resp.responseBody = Blob.valueOf('');
        }
    }

    // Slack sends slash-command params in a stable order. We rebuild the
    // x-www-form-urlencoded body in that order so HMAC verification matches.
    // Any keys not in the canonical list are appended sorted alphabetically.
    private static final List<String> SLACK_CANONICAL_ORDER = new List<String>{
        'token','team_id','team_domain','enterprise_id','enterprise_name',
        'is_enterprise_install','channel_id','channel_name','user_id','user_name',
        'command','text','api_app_id','response_url','trigger_id','payload'
    };

    @TestVisible
    private static String reconstructFormBody(Map<String, String> params) {
        Set<String> seen = new Set<String>();
        List<String> parts = new List<String>();
        for (String k : SLACK_CANONICAL_ORDER) {
            if (params.containsKey(k)) {
                parts.add(encodePair(k, params.get(k)));
                seen.add(k);
            }
        }
        List<String> remaining = new List<String>();
        for (String k : params.keySet()) {
            if (!seen.contains(k)) remaining.add(k);
        }
        remaining.sort();
        for (String k : remaining) parts.add(encodePair(k, params.get(k)));
        return String.join(parts, '&');
    }

    private static String encodePair(String k, String v) {
        return EncodingUtil.urlEncode(k, 'UTF-8') + '=' + EncodingUtil.urlEncode(v == null ? '' : v, 'UTF-8');
    }
}