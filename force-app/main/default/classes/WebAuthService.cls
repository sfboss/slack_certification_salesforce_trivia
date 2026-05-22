/**
 * Verifies Google OAuth ID tokens and upserts a Player__c keyed on Google sub.
 * Used by the public web app (Visualforce on a Salesforce Site, guest user context).
 */
public without sharing class WebAuthService {

    public class AuthResult {
        public Boolean ok;
        public String error;
        public Id playerId;
        public String sessionToken;
        public Long expiresAt;
        public String name;
        public String email;
        public String pictureUrl;
    }

    public class GoogleClaims {
        public String iss;
        public String aud;
        public String sub;
        public String email;
        public String email_verified;
        public String name;
        public String picture;
    }

    // Test/diagnostic injection point. When non-null, verifyGoogleToken returns this
    // instead of calling Google. Used by anonymous-apex test scripts to simulate
    // multiple Google identities without real tokens.
    public static GoogleClaims claimsOverride;

    public static AuthResult signInWithGoogleIdToken(String idToken) {
        AuthResult r = new AuthResult();
        if (String.isBlank(idToken)) { r.ok = false; r.error = 'missing_id_token'; return r; }
        GoogleClaims claims;
        try {
            claims = verifyGoogleToken(idToken);
        } catch (Exception e) {
            r.ok = false;
            r.error = 'verify_failed:' + e.getMessage();
            AppLogger.error('WebAuthService', 'signInWithGoogleIdToken', 'Google token verify failed', e);
            return r;
        }
        if (claims == null || String.isBlank(claims.sub)) {
            r.ok = false; r.error = 'invalid_claims'; return r;
        }
        // Audience check
        String expectedAud = AppSettings.get().Web_Google_Client_Id__c;
        if (String.isNotBlank(expectedAud) && expectedAud != claims.aud) {
            r.ok = false; r.error = 'aud_mismatch'; return r;
        }
        // Issuer check
        if (claims.iss != 'accounts.google.com' && claims.iss != 'https://accounts.google.com') {
            r.ok = false; r.error = 'iss_mismatch'; return r;
        }

        Player__c p = upsertPlayer(claims);
        r.playerId = p.Id;
        r.name = p.Google_Name__c;
        r.email = p.Google_Email__c;
        r.pictureUrl = p.Google_Picture_URL__c;
        r.sessionToken = WebSessionToken.mint(p.Id);
        r.expiresAt = (DateTime.now().getTime() / 1000L) + (7 * 24 * 3600);
        r.ok = true;
        return r;
    }

    private static Player__c upsertPlayer(GoogleClaims c) {
        List<Player__c> existing = [
            SELECT Id, Google_Sub__c, Google_Email__c, Google_Name__c, Google_Picture_URL__c, Display_Name__c
            FROM Player__c
            WHERE Google_Sub__c = :c.sub
            LIMIT 1
        ];
        Player__c p;
        if (!existing.isEmpty()) {
            p = existing[0];
            p.Google_Email__c = c.email;
            p.Google_Name__c = c.name;
            p.Google_Picture_URL__c = c.picture;
            p.Web_Last_Login_At__c = DateTime.now();
            if (String.isBlank(p.Display_Name__c)) p.Display_Name__c = c.name;
        } else {
            p = new Player__c(
                Google_Sub__c = c.sub,
                Google_Email__c = c.email,
                Google_Name__c = c.name,
                Google_Picture_URL__c = c.picture,
                Display_Name__c = String.isBlank(c.name) ? c.email : c.name,
                Web_Last_Login_At__c = DateTime.now(),
                Notifications_Opt_In__c = false
            );
        }
        Database.upsert(p, Player__c.Google_Sub__c, false, AccessLevel.SYSTEM_MODE);
        return p;
    }

    private static GoogleClaims verifyGoogleToken(String idToken) {
        if (claimsOverride != null) return claimsOverride;
        if (Test.isRunningTest()) {
            GoogleClaims tc = new GoogleClaims();
            tc.iss = 'accounts.google.com';
            tc.sub = 'test-sub';
            tc.email = 'test@example.com';
            tc.name = 'Test User';
            return tc;
        }
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://oauth2.googleapis.com/tokeninfo?id_token=' + EncodingUtil.urlEncode(idToken, 'UTF-8'));
        req.setMethod('GET');
        req.setTimeout(10000);
        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) {
            throw new AuthException('tokeninfo HTTP ' + res.getStatusCode() + ': ' + res.getBody());
        }
        Map<String, Object> m = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        GoogleClaims c = new GoogleClaims();
        c.iss = (String) m.get('iss');
        c.aud = (String) m.get('aud');
        c.sub = (String) m.get('sub');
        c.email = (String) m.get('email');
        c.email_verified = String.valueOf(m.get('email_verified'));
        c.name = (String) m.get('name');
        c.picture = (String) m.get('picture');
        return c;
    }

    public class AuthException extends Exception {}
}