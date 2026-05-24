/**
 * Routes verified Slack payloads to the right handler.
 * Enforces idempotency via Slack_Event_Log__c keyed on the synthesized event id.
 */
public with sharing class SlackRequestRouter {
    public class RouterResult {
        public Integer statusCode = 200;
        public String body = '';
        public Boolean alreadyProcessed = false;
    }

    /**
     * @param headers Request headers (signature, timestamp).
     * @param rawBody Raw request body. Can be x-www-form-urlencoded (slash command, interactivity)
     *                or JSON (event_callback).
     * @param contentType MIME type.
     */
    public static RouterResult dispatch(
        Map<String, String> headers,
        String rawBody,
        String contentType
    ) {
        RouterResult res = new RouterResult();
        try {
            // Slack URL verification handshake. Slack signs this request, but at first install
            // the signing secret may not yet be configured in the org. Echo the challenge
            // before signature verification so the endpoint can be registered. Body is the
            // small Slack-controlled JSON {type, challenge, token} — no security impact.
            if (rawBody != null && rawBody.contains('"url_verification"')) {
                try {
                    Map<String, Object> probe = (Map<String, Object>) JSON.deserializeUntyped(
                        rawBody
                    );
                    if (
                        probe != null &&
                        'url_verification'.equals(probe.get('type'))
                    ) {
                        res.body = (String) probe.get('challenge');
                        return res;
                    }
                } catch (Exception ignored) {
                    /* fall through to normal flow */
                }
            }

            Map<String, Object> payload = parseBody(rawBody, contentType);
            Boolean ok = SlackSignatureVerifier.verify(headers, rawBody);
            if (!ok) {
                // Sites strips raw bytes for form-urlencoded POSTs, so HMAC can never match
                // on slash commands / interactivity. Fall back to Slack's Verification Token
                // for those payloads only. JSON event callbacks still require HMAC.
                Boolean isForm =
                    contentType != null &&
                    contentType.startsWithIgnoreCase(
                        'application/x-www-form-urlencoded'
                    );
                if (isForm) {
                    String submitted = (String) payload.get('token');
                    if (
                        submitted == null &&
                        payload.get('payload') instanceof String
                    ) {
                        try {
                            Map<String, Object> innerPayload = (Map<String, Object>) JSON.deserializeUntyped(
                                (String) payload.get('payload')
                            );
                            if (innerPayload != null)
                                submitted = (String) innerPayload.get('token');
                        } catch (Exception ignored) {
                            /* leave null */
                        }
                    }
                    ok = SlackSignatureVerifier.verifyByToken(
                        headers,
                        submitted
                    );
                }
                if (!ok) {
                    AppLogger.warn(
                        'SlackRequestRouter',
                        'dispatch',
                        'invalid signature'
                    );
                    res.statusCode = 401;
                    res.body = 'invalid signature';
                    return res;
                }
            }
            String synthId = synthesizeEventId(payload, rawBody);

            // (legacy) url_verification — already short-circuited above; keep as safety net.
            if (payload.get('type') == 'url_verification') {
                res.body = (String) payload.get('challenge');
                return res;
            }

            // Idempotency: short-circuit if already processed. We defer the insert until
            // AFTER dispatch because handlers (e.g. views.open for /certgame plan|billing)
            // make Slack callouts — and Apex forbids callouts after DML in the same
            // transaction ("uncommitted work pending").
            List<Slack_Event_Log__c> existing = [
                SELECT Id, Processed__c
                FROM Slack_Event_Log__c
                WHERE Slack_Event_Id__c = :synthId
                WITH SYSTEM_MODE
                LIMIT 1
            ];
            if (!existing.isEmpty() && existing[0].Processed__c == true) {
                res.alreadyProcessed = true;
                return res;
            }

            // Dispatch first (may make callouts), then log.
            String t = inferType(payload);
            try {
                if (t == 'slash_command') {
                    res.body = SlackCertGameCommandHandler.handle(payload);
                } else if (t == 'block_actions') {
                    res.body = SlackCertGameInteractionHandler.handle(payload);
                } else if (t == 'view_submission' || t == 'view_closed') {
                    res.body = SlackCertGameModalHandler.handle(payload);
                } else if (t == 'event_callback') {
                    res.body = SlackCertGameEventHandler.handle(payload);
                } else {
                    res.body = '';
                }
            } catch (Exception dispatchEx) {
                AppLogger.error(
                    'SlackRequestRouter',
                    'dispatch',
                    'Handler error for type=' + t,
                    dispatchEx
                );
                if (t == 'slash_command') {
                    String sub = null;
                    Object txt = payload.get('text');
                    if (
                        txt instanceof String && String.isNotBlank((String) txt)
                    ) {
                        sub = ((String) txt).trim().split('\\s+')[0];
                    }
                    res.body = CertGameSlackRenderService.errorEnvelope(
                        sub,
                        AppLogger.currentCorrelationId(),
                        dispatchEx
                    );
                } else {
                    res.body = '';
                }
            }

            if (existing.isEmpty()) {
                try {
                    Slack_Event_Log__c current = new Slack_Event_Log__c(
                        Slack_Event_Id__c = synthId,
                        Slack_Team_Id__c = (String) extractTeamId(payload),
                        Event_Type__c = t,
                        Payload_Hash__c = sha256(rawBody),
                        Received_At__c = System.now(),
                        Processed__c = true
                    );
                    insert as system current;
                } catch (Exception logEx) {
                    AppLogger.error(
                        'SlackRequestRouter',
                        'dispatch',
                        'Failed to write Slack_Event_Log__c (continuing)',
                        logEx
                    );
                }
            }
        } catch (Exception e) {
            AppLogger.error(
                'SlackRequestRouter',
                'dispatch',
                'Slack dispatch failure',
                e
            );
            res.statusCode = 200; // still ack so Slack does not infinite-retry; error captured in log
            res.body = '';
        }
        return res;
    }

    private static Map<String, Object> parseBody(
        String rawBody,
        String contentType
    ) {
        if (rawBody == null)
            return new Map<String, Object>();
        String ct = contentType == null ? '' : contentType.toLowerCase();
        if (ct.contains('application/json')) {
            Object o = JSON.deserializeUntyped(rawBody);
            return (Map<String, Object>) o;
        }
        // form-encoded — either a slash command body or a payload= for interactivity
        Map<String, String> form = parseForm(rawBody);
        if (form.containsKey('payload')) {
            return (Map<String, Object>) JSON.deserializeUntyped(
                form.get('payload')
            );
        }
        Map<String, Object> out = new Map<String, Object>();
        for (String k : form.keySet())
            out.put(k, form.get(k));
        return out;
    }

    private static Map<String, String> parseForm(String body) {
        Map<String, String> out = new Map<String, String>();
        for (String pair : body.split('&')) {
            if (pair == '')
                continue;
            Integer eq = pair.indexOf('=');
            String k = eq < 0 ? pair : pair.substring(0, eq);
            String v = eq < 0 ? '' : pair.substring(eq + 1);
            out.put(
                EncodingUtil.urlDecode(k, 'UTF-8'),
                EncodingUtil.urlDecode(v, 'UTF-8')
            );
        }
        return out;
    }

    private static String inferType(Map<String, Object> payload) {
        if (payload.containsKey('command'))
            return 'slash_command';
        String t = (String) payload.get('type');
        return t == null ? 'unknown' : t;
    }

    private static String extractTeamId(Map<String, Object> payload) {
        if (payload.containsKey('team_id'))
            return (String) payload.get('team_id');
        Object team = payload.get('team');
        if (team instanceof Map<String, Object>)
            return (String) ((Map<String, Object>) team).get('id');
        return null;
    }

    private static String synthesizeEventId(
        Map<String, Object> payload,
        String raw
    ) {
        // Slack provides event_id for Events API. For slash/interactivity we hash the body.
        Object ev = payload.get('event_id');
        if (ev instanceof String)
            return (String) ev;
        if (payload.containsKey('trigger_id'))
            return 'trig:' + payload.get('trigger_id');
        return 'h:' + sha256(raw);
    }

    private static String sha256(String s) {
        if (s == null)
            return '';
        Blob h = Crypto.generateDigest('SHA-256', Blob.valueOf(s));
        return EncodingUtil.convertToHex(h);
    }
}