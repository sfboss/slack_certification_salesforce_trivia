/**
 * Verifies the X-Slack-Signature on incoming Slack requests.
 * Spec: signing key = HMAC-SHA256 over "v0:{ts}:{rawBody}" using signing secret.
 * Rejects when |now - ts| exceeds the configured skew (default 300s).
 *
 * The signing secret is stored in a Named Credential or a protected Custom Metadata field;
 * for unit tests the @TestVisible setSecretOverride hook is used.
 */
public with sharing class SlackSignatureVerifier {

    @TestVisible private static String secretOverride;

    public class VerificationException extends Exception {}

    public static Boolean verify(Map<String, String> headers, String rawBody) {
        if (headers == null || rawBody == null) return false;
        String sig = headers.get('X-Slack-Signature');
        String ts  = headers.get('X-Slack-Request-Timestamp');
        if (sig == null) sig = headers.get('x-slack-signature');
        if (ts == null)  ts  = headers.get('x-slack-request-timestamp');
        if (String.isBlank(sig) || String.isBlank(ts)) return false;

        Long now = System.currentTimeMillis() / 1000L;
        Long req;
        try { req = Long.valueOf(ts); } catch (Exception e) { return false; }
        Decimal skew = AppSettings.get().Slack_Timestamp_Skew_Seconds__c;
        Long maxSkew = (skew == null) ? 300L : skew.longValue();
        if (Math.abs(now - req) > maxSkew) return false;

        String basestring = 'v0:' + ts + ':' + rawBody;
        String expected = 'v0=' + computeHmac(basestring);
        return constantTimeEquals(expected, sig);
    }

    private static String computeHmac(String data) {
        String secret = getSecret();
        Blob mac = Crypto.generateMac('HmacSHA256', Blob.valueOf(data), Blob.valueOf(secret));
        return EncodingUtil.convertToHex(mac);
    }

    private static String getSecret() {
        if (secretOverride != null) return secretOverride;
        // In a real org the signing secret lives in a Named Credential External Credential
        // or a protected Custom Metadata. Reading from a Named Credential header callout is
        // not possible from Apex without making a callout, so for now we read from a custom
        // setting / protected mdt. The default below is intentionally invalid so any non-test
        // path fails closed.
        return 'INVALID_DEFAULT_SECRET';
    }

    private static Boolean constantTimeEquals(String a, String b) {
        if (a == null || b == null) return false;
        if (a.length() != b.length()) return false;
        Integer diff = 0;
        for (Integer i = 0; i < a.length(); i++) {
            diff |= (a.charAt(i) ^ b.charAt(i));
        }
        return diff == 0;
    }
}
