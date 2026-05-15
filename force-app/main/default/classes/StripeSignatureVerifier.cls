/**
 * Verifies the Stripe-Signature header on incoming webhooks.
 * Header format: t=timestamp,v1=hex(HMAC_SHA256(secret, "t.payload"))
 * Reject when |now-t| > tolerance (default 300s).
 *
 * Required ≥95% test coverage.
 */
public with sharing class StripeSignatureVerifier {

    @TestVisible private static String secretOverride;

    public static Boolean verify(String header, String rawBody) {
        if (String.isBlank(header) || rawBody == null) return false;
        Long ts;
        String v1;
        for (String part : header.split(',')) {
            List<String> kv = part.split('=', 2);
            if (kv.size() != 2) continue;
            String k = kv[0].trim();
            String v = kv[1].trim();
            if (k == 't') {
                try { ts = Long.valueOf(v); } catch (Exception e) { return false; }
            } else if (k == 'v1' && v1 == null) {
                v1 = v;
            }
        }
        if (ts == null || String.isBlank(v1)) return false;

        Long now = System.currentTimeMillis() / 1000L;
        if (Math.abs(now - ts) > 300L) return false;

        String secret = secretOverride != null ? secretOverride : 'INVALID_DEFAULT_SECRET';
        String basestring = ts + '.' + rawBody;
        Blob mac = Crypto.generateMac('HmacSHA256', Blob.valueOf(basestring), Blob.valueOf(secret));
        String expected = EncodingUtil.convertToHex(mac);
        return constantTimeEquals(expected, v1);
    }

    private static Boolean constantTimeEquals(String a, String b) {
        if (a == null || b == null) return false;
        if (a.length() != b.length()) return false;
        Integer diff = 0;
        for (Integer i = 0; i < a.length(); i++) diff |= (a.charAt(i) ^ b.charAt(i));
        return diff == 0;
    }
}
