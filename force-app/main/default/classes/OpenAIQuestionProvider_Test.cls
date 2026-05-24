@IsTest
private class OpenAIQuestionProvider_Test {
    public class OkMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse r = new HttpResponse();
            r.setStatusCode(200);
            r.setBody('{"output":[{"content":[{"text":"PACK_JSON"}]}]}');
            return r;
        }
    }
    public class ErrMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse r = new HttpResponse();
            r.setStatusCode(500);
            r.setBody('boom');
            return r;
        }
    }

    @IsTest
    static void generateReturnsExtractedText() {
        Test.setMock(HttpCalloutMock.class, new OkMock());
        OpenAIQuestionProvider p = new OpenAIQuestionProvider();
        Test.startTest();
        String out = p.generate(
            'ADM-201',
            new List<String>{ 'Security' },
            'Beginner',
            2
        );
        Test.stopTest();
        System.assertEquals('PACK_JSON', out);
        System.assertEquals('openai', p.name());
    }

    @IsTest
    static void non2xxThrows() {
        Test.setMock(HttpCalloutMock.class, new ErrMock());
        try {
            new OpenAIQuestionProvider().generate('X', null, null, 1);
            System.assert(false, 'expected CalloutException');
        } catch (CalloutException e) {
            System.assert(e.getMessage().contains('non-2xx'));
        }
    }
}