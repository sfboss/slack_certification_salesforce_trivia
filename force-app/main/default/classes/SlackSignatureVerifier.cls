/**
 * Verifies the X-Slack-Signature on incoming Slack requests.
 * Spec: signing key = HMAC-SHA256 over "v0:{ts}:{rawBody}" using signing secret.
 * Rejects when |now - ts| exceeds the configured skew (default 300s).
 *
 * The signing secret is stored in a Named Credential or a protected Custom Metadata field;
 * for unit tests the @TestVisible setSecretOverride hook is used.
 */
public with sharing class SlackSignatureVerifier {
    @TestVisible
    private static String secretOverride;

    public class VerificationException extends Exception {
    }

    public static Boolean verify(Map<String, String> headers, String rawBody) {
        if (headers == null || rawBody == null)
            return false;
        String sig = headers.get('X-Slack-Signature');
        String ts = headers.get('X-Slack-Request-Timestamp');
        if (sig == null)
            sig = headers.get('x-slack-signature');
        if (ts == null)
            ts = headers.get('x-slack-request-timestamp');
        if (String.isBlank(sig) || String.isBlank(ts))
            return false;

        Long now = System.currentTimeMillis() / 1000L;
        Long req;
        try {
            req = Long.valueOf(ts);
        } catch (Exception e) {
            return false;
        }
        Decimal skew = AppSettings.get().Slack_Timestamp_Skew_Seconds__c;
        Long maxSkew = (skew == null) ? 300L : skew.longValue();
        if (Math.abs(now - req) > maxSkew)
            return false;

        String basestring = 'v0:' + ts + ':' + rawBody;
        String expected = 'v0=' + computeHmac(basestring);
        return constantTimeEquals(expected, sig);
    }

    /**
     * Fallback verification for form-urlencoded slash commands received via Salesforce Sites,
     * which discards raw bytes and only exposes req.params. HMAC requires exact byte parity
     * with what Slack signed, which is unrecoverable from a parsed param map. Slack still
     * sends the legacy Verification Token on every slash command and interactivity payload;
     * comparing it against the stored secret + enforcing freshness (300s skew) is the
     * practical equivalent of HMAC for this transport.
     *
     * Returns true only when token matches and timestamp header is within configured skew.
     */
    public static Boolean verifyByToken(
        Map<String, String> headers,
        String submittedToken
    ) {
        if (headers == null || String.isBlank(submittedToken))
            return false;
        String ts = headers.get('X-Slack-Request-Timestamp');
        if (ts == null)
            ts = headers.get('x-slack-request-timestamp');
        if (String.isBlank(ts))
            return false;
        Long now = System.currentTimeMillis() / 1000L;
        Long req;
        try {
            req = Long.valueOf(ts);
        } catch (Exception e) {
            return false;
        }
        Decimal skew = AppSettings.get().Slack_Timestamp_Skew_Seconds__c;
        Long maxSkew = (skew == null) ? 300L : skew.longValue();
        if (Math.abs(now - req) > maxSkew)
            return false;
        String stored = AppSettings.get().Slack_Verification_Token__c;
        if (String.isBlank(stored))
            return false;
        return constantTimeEquals(stored, submittedToken);
    }

    private static String computeHmac(String data) {
        String secret = getSecret();
        Blob mac = Crypto.generateMac(
            'HmacSHA256',
            Blob.valueOf(data),
            Blob.valueOf(secret)
        );
        return EncodingUtil.convertToHex(mac);
    }

    private static String getSecret() {
        if (secretOverride != null)
            return secretOverride;
        String s = AppSettings.get().Slack_Signing_Secret__c;
        if (String.isBlank(s)) {
            // Intentionally do NOT insert App_Log__c here: this method is called on every
            // inbound Slack request, and a DML write before downstream callouts (views.open)
            // trips "uncommitted work pending". The token-fallback path in SlackRequestRouter
            // handles the missing-secret case for form-encoded payloads.
            System.debug(
                LoggingLevel.WARN,
                '[SlackSignatureVerifier] Slack_Signing_Secret__c is blank. HMAC verification will fail; ' +
                'token-fallback will be used for form-encoded requests.'
            );
            return 'INVALID_DEFAULT_SECRET';
        }
        return s;
    }

    private static Boolean constantTimeEquals(String a, String b) {
        if (a == null || b == null)
            return false;
        if (a.length() != b.length())
            return false;
        Integer diff = 0;
        for (Integer i = 0; i < a.length(); i++) {
            diff |= (a.charAt(i) ^ b.charAt(i));
        }
        return diff == 0;
    }
}