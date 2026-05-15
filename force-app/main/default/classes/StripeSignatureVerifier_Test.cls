@IsTest
private class StripeSignatureVerifier_Test {

    private static String hex(String secret, String data) {
        Blob mac = Crypto.generateMac('HmacSHA256', Blob.valueOf(data), Blob.valueOf(secret));
        return EncodingUtil.convertToHex(mac);
    }

    @IsTest static void validPasses() {
        StripeSignatureVerifier.secretOverride = 'whsec';
        Long ts = System.currentTimeMillis() / 1000L;
        String body = '{"id":"evt_1"}';
        String v1 = hex('whsec', ts + '.' + body);
        String header = 't=' + ts + ',v1=' + v1;
        System.assert(StripeSignatureVerifier.verify(header, body));
    }

    @IsTest static void duplicateV1HeaderUsesFirst() {
        StripeSignatureVerifier.secretOverride = 'whsec';
        Long ts = System.currentTimeMillis() / 1000L;
        String body = 'b';
        String v1 = hex('whsec', ts + '.' + body);
        String header = 't=' + ts + ',v1=' + v1 + ',v1=deadbeef';
        System.assert(StripeSignatureVerifier.verify(header, body));
    }

    @IsTest static void invalidFails() {
        StripeSignatureVerifier.secretOverride = 'whsec';
        Long ts = System.currentTimeMillis() / 1000L;
        String header = 't=' + ts + ',v1=deadbeef';
        System.assert(!StripeSignatureVerifier.verify(header, 'b'));
    }

    @IsTest static void expiredFails() {
        StripeSignatureVerifier.secretOverride = 'whsec';
        Long ts = (System.currentTimeMillis() / 1000L) - 99999L;
        String v1 = hex('whsec', ts + '.b');
        System.assert(!StripeSignatureVerifier.verify('t=' + ts + ',v1=' + v1, 'b'));
    }

    @IsTest static void blanksFail() {
        System.assert(!StripeSignatureVerifier.verify(null, 'b'));
        System.assert(!StripeSignatureVerifier.verify('', 'b'));
        System.assert(!StripeSignatureVerifier.verify('garbage', null));
    }

    @IsTest static void malformedHeaderFails() {
        System.assert(!StripeSignatureVerifier.verify('foo,bar', 'b'));
        System.assert(!StripeSignatureVerifier.verify('t=abc,v1=x', 'b'));
    }
}
