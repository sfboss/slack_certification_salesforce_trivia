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
            String body = req.requestBody == null ? '' : req.requestBody.toString();
            String contentType = headers.containsKey('Content-Type') ? headers.get('Content-Type')
                              : headers.containsKey('content-type') ? headers.get('content-type') : '';

            SlackRequestRouter.RouterResult r = SlackRequestRouter.dispatch(headers, body, contentType);
            resp.statusCode = r.statusCode;
            resp.responseBody = Blob.valueOf(r.body == null ? '' : r.body);
        } catch (Exception e) {
            AppLogger.error('SlackEventsRestResource', 'doPost', 'Unhandled Slack endpoint error', e);
            resp.statusCode = 200;
            resp.responseBody = Blob.valueOf('');
        }
    }
}
