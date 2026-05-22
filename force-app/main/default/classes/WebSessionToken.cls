/**
 * HMAC-SHA256 signed session tokens for the public web app.
 * Format: base64url(payload).base64url(signature)
 *   payload = "{playerId}:{expEpochSec}"
 */
public without sharing class WebSessionToken {
    @TestVisible private static final Integer DEFAULT_TTL_SECONDS = 7 * 24 * 3600;

    public class TokenResult {
        public Boolean valid;
        public Id playerId;
        public Long expiresAt;
        public String reason;
    }

    public static String mint(Id playerId) {
        return mint(playerId, DEFAULT_TTL_SECONDS);
    }

    public static String mint(Id playerId, Integer ttlSeconds) {
        Long expEpoch = (DateTime.now().getTime() / 1000L) + ttlSeconds;
        String payload = String.valueOf(playerId) + ':' + String.valueOf(expEpoch);
        Blob sig = Crypto.generateMac('HmacSHA256', Blob.valueOf(payload), Blob.valueOf(secret()));
        return b64urlEncode(Blob.valueOf(payload)) + '.' + b64urlEncode(sig);
    }

    public static TokenResult verify(String token) {
        TokenResult r = new TokenResult();
        r.valid = false;
        if (String.isBlank(token)) { r.reason = 'missing'; return r; }
        List<String> parts = token.split('\\.');
        if (parts.size() != 2) { r.reason = 'malformed'; return r; }
        Blob payloadBlob;
        Blob sigBlob;
        try {
            payloadBlob = b64urlDecode(parts[0]);
            sigBlob = b64urlDecode(parts[1]);
        } catch (Exception e) { r.reason = 'b64'; return r; }
        Blob expected = Crypto.generateMac('HmacSHA256', payloadBlob, Blob.valueOf(secret()));
        if (EncodingUtil.base64Encode(expected) != EncodingUtil.base64Encode(sigBlob)) {
            r.reason = 'bad_sig';
            return r;
        }
        String payload = payloadBlob.toString();
        List<String> pp = payload.split(':');
        if (pp.size() != 2) { r.reason = 'bad_payload'; return r; }
        Long expEpoch;
        try { expEpoch = Long.valueOf(pp[1]); } catch (Exception e) { r.reason = 'bad_exp'; return r; }
        if (expEpoch < (DateTime.now().getTime() / 1000L)) { r.reason = 'expired'; return r; }
        try { r.playerId = (Id) pp[0]; } catch (Exception e) { r.reason = 'bad_pid'; return r; }
        r.expiresAt = expEpoch;
        r.valid = true;
        return r;
    }

    private static String secret() {
        String s = AppSettings.get().Web_Session_Secret__c;
        if (String.isNotBlank(s)) return s;
        // Deterministic fallback so the app runs out-of-the-box. Replace via CMDT for prod.
        return 'certgame-web-fallback-' + UserInfo.getOrganizationId();
    }

    private static String b64urlEncode(Blob b) {
        String s = EncodingUtil.base64Encode(b);
        return s.replace('+', '-').replace('/', '_').replace('=', '');
    }

    private static Blob b64urlDecode(String s) {
        String t = s.replace('-', '+').replace('_', '/');
        Integer pad = Math.mod(4 - Math.mod(t.length(), 4), 4);
        for (Integer i = 0; i < pad; i++) t += '=';
        return EncodingUtil.base64Decode(t);
    }
}