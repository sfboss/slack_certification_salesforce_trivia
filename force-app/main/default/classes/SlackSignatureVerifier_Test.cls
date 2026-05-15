@IsTest
private class SlackSignatureVerifier_Test {

    private static String hexHmac(String secret, String data) {
        Blob mac = Crypto.generateMac('HmacSHA256', Blob.valueOf(data), Blob.valueOf(secret));
        return EncodingUtil.convertToHex(mac);
    }

    @IsTest static void validSignaturePasses() {
        SlackSignatureVerifier.secretOverride = 'shhh';
        String ts = String.valueOf(System.currentTimeMillis() / 1000L);
        String body = '{"a":1}';
        String sig = 'v0=' + hexHmac('shhh', 'v0:' + ts + ':' + body);
        Map<String,String> headers = new Map<String,String>{
            'X-Slack-Signature' => sig,
            'X-Slack-Request-Timestamp' => ts
        };
        System.assert(SlackSignatureVerifier.verify(headers, body));
    }

    @IsTest static void lowercaseHeadersAccepted() {
        SlackSignatureVerifier.secretOverride = 'shhh';
        String ts = String.valueOf(System.currentTimeMillis() / 1000L);
        String body = 'hello';
        String sig = 'v0=' + hexHmac('shhh', 'v0:' + ts + ':' + body);
        Map<String,String> headers = new Map<String,String>{
            'x-slack-signature' => sig,
            'x-slack-request-timestamp' => ts
        };
        System.assert(SlackSignatureVerifier.verify(headers, body));
    }

    @IsTest static void invalidSignatureFails() {
        SlackSignatureVerifier.secretOverride = 'shhh';
        String ts = String.valueOf(System.currentTimeMillis() / 1000L);
        Map<String,String> headers = new Map<String,String>{
            'X-Slack-Signature' => 'v0=deadbeef',
            'X-Slack-Request-Timestamp' => ts
        };
        System.assert(!SlackSignatureVerifier.verify(headers, 'body'));
    }

    @IsTest static void expiredTimestampFails() {
        SlackSignatureVerifier.secretOverride = 'shhh';
        Long old = (System.currentTimeMillis() / 1000L) - 99999L;
        String ts = String.valueOf(old);
        String sig = 'v0=' + hexHmac('shhh', 'v0:' + ts + ':' + 'b');
        Map<String,String> headers = new Map<String,String>{
            'X-Slack-Signature' => sig,
            'X-Slack-Request-Timestamp' => ts
        };
        System.assert(!SlackSignatureVerifier.verify(headers, 'b'));
    }

    @IsTest static void missingHeadersFail() {
        System.assert(!SlackSignatureVerifier.verify(null, 'b'));
        System.assert(!SlackSignatureVerifier.verify(new Map<String,String>(), 'b'));
        System.assert(!SlackSignatureVerifier.verify(new Map<String,String>{'X-Slack-Signature'=>'v0=x'}, 'b'));
    }

    @IsTest static void nonNumericTimestampFails() {
        Map<String,String> headers = new Map<String,String>{
            'X-Slack-Signature' => 'v0=x',
            'X-Slack-Request-Timestamp' => 'not-a-number'
        };
        System.assert(!SlackSignatureVerifier.verify(headers, 'b'));
    }

    @IsTest static void nullBodyFails() {
        System.assert(!SlackSignatureVerifier.verify(new Map<String,String>{'X-Slack-Signature'=>'v0=x','X-Slack-Request-Timestamp'=>'1'}, null));
    }
}
