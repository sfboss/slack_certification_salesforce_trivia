@IsTest
private class SlackCertGameCommandHandler_Test {

    @TestSetup static void setup() {
        Tenant__c t = new Tenant__c(Slack_Team_Id__c='T_CMD', Workspace_Name__c='W', Plan__c='Pro', Status__c='Active', Installed_At__c=System.now());
        insert t;
    }

    private static Map<String,Object> p(String text) {
        return new Map<String,Object>{
            'text'=>text, 'team_id'=>'T_CMD', 'user_id'=>'U1', 'channel_id'=>'C1', 'trigger_id'=>'TR1'
        };
    }

    @IsTest static void helpAndUnknown() {
        System.assert(SlackCertGameCommandHandler.handle(p('help')).contains('ephemeral'));
        System.assert(SlackCertGameCommandHandler.handle(p('')).contains('ephemeral'));
        System.assert(SlackCertGameCommandHandler.handle(p('garbage')).contains('ephemeral'));
    }

    @IsTest static void leaderboardAndStats() {
        System.assert(SlackCertGameCommandHandler.handle(p('leaderboard week')).contains('Leaderboard'));
        SlackCertGameCommandHandler.handle(p('stats'));
    }

    @IsTest static void planAndBilling() {
        Test.setMock(HttpCalloutMock.class, new SlackOkMock());
        SlackCertGameCommandHandler.handle(p('plan'));
        SlackCertGameCommandHandler.handle(p('billing'));
    }

    private class SlackOkMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"ok":true}');
            return res;
        }
    }
}