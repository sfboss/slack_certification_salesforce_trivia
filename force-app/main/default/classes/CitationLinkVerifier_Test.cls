@IsTest
private class CitationLinkVerifier_Test {
    private class Mock implements HttpCalloutMock {
        Integer code;
        Boolean throwIt;
        Mock(Integer c) {
            this.code = c;
            this.throwIt = false;
        }
        Mock(Boolean t) {
            this.throwIt = t;
            this.code = 0;
        }
        public HttpResponse respond(HttpRequest req) {
            if (throwIt)
                throw new CalloutException('boom');
            HttpResponse r = new HttpResponse();
            r.setStatusCode(code);
            r.setStatus('x');
            return r;
        }
    }

    @IsTest
    static void reachable200() {
        Test.setMock(HttpCalloutMock.class, new Mock(200));
        Test.startTest();
        System.assertEquals(
            true,
            CitationLinkVerifier.check('https://example.com')
        );
        Test.stopTest();
    }

    @IsTest
    static void unreachable404() {
        Test.setMock(HttpCalloutMock.class, new Mock(404));
        Test.startTest();
        System.assertEquals(
            false,
            CitationLinkVerifier.check('https://example.com')
        );
        Test.stopTest();
    }

    @IsTest
    static void exceptionReturnsFalse() {
        Test.setMock(HttpCalloutMock.class, new Mock(true));
        Test.startTest();
        System.assertEquals(
            false,
            CitationLinkVerifier.check('https://example.com')
        );
        Test.stopTest();
    }

    @IsTest
    static void rejectsNonHttp() {
        System.assertEquals(false, CitationLinkVerifier.check(null));
        System.assertEquals(false, CitationLinkVerifier.check(''));
        System.assertEquals(false, CitationLinkVerifier.check('ftp://x'));
    }
}