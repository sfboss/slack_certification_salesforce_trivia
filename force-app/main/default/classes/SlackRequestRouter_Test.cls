@IsTest
private class SlackRequestRouter_Test {

    private static Map<String,String> signedHeaders(String body) {
        SlackSignatureVerifier.secretOverride = 'shhh';
        String ts = String.valueOf(System.currentTimeMillis() / 1000L);
        Blob mac = Crypto.generateMac('HmacSHA256', Blob.valueOf('v0:'+ts+':'+body), Blob.valueOf('shhh'));
        String sig = 'v0=' + EncodingUtil.convertToHex(mac);
        return new Map<String,String>{ 'X-Slack-Signature'=>sig, 'X-Slack-Request-Timestamp'=>ts };
    }

    @IsTest static void badSignatureReturns401() {
        SlackSignatureVerifier.secretOverride = 'shhh';
        Map<String,String> h = new Map<String,String>{
            'X-Slack-Signature'=>'v0=deadbeef',
            'X-Slack-Request-Timestamp'=>String.valueOf(System.currentTimeMillis()/1000L)
        };
        SlackRequestRouter.RouterResult r = SlackRequestRouter.dispatch(h, 'team_id=T1', 'application/x-www-form-urlencoded');
        System.assertEquals(401, r.statusCode);
    }

    @IsTest static void urlVerificationEchoesChallenge() {
        String body = JSON.serialize(new Map<String,Object>{'type'=>'url_verification', 'challenge'=>'abc'});
        SlackRequestRouter.RouterResult r = SlackRequestRouter.dispatch(signedHeaders(body), body, 'application/json');
        System.assertEquals('abc', r.body);
    }

    @IsTest static void slashCommandDispatched() {
        insert new Tenant__c(Slack_Team_Id__c='T_RT', Workspace_Name__c='X', Plan__c='Free', Status__c='Active', Installed_At__c=System.now());
        String body = 'team_id=T_RT&user_id=U1&command=%2Fcertgame&text=help&channel_id=C1';
        SlackRequestRouter.RouterResult r = SlackRequestRouter.dispatch(signedHeaders(body), body, 'application/x-www-form-urlencoded');
        System.assertEquals(200, r.statusCode);
        System.assertEquals(1, [SELECT COUNT() FROM Slack_Event_Log__c]);
    }

    @IsTest static void duplicateEventTreatedAsAlreadyProcessed() {
        insert new Tenant__c(Slack_Team_Id__c='T_DUP', Workspace_Name__c='X', Plan__c='Free', Status__c='Active', Installed_At__c=System.now());
        String body = 'team_id=T_DUP&user_id=U1&command=%2Fcertgame&text=help&channel_id=C1';
        Map<String,String> h = signedHeaders(body);
        SlackRequestRouter.dispatch(h, body, 'application/x-www-form-urlencoded');
        SlackRequestRouter.RouterResult r2 = SlackRequestRouter.dispatch(h, body, 'application/x-www-form-urlencoded');
        System.assert(r2.alreadyProcessed);
    }

    @IsTest static void unknownTypeIsHandled() {
        String body = JSON.serialize(new Map<String,Object>{'type'=>'mystery'});
        SlackRequestRouter.RouterResult r = SlackRequestRouter.dispatch(signedHeaders(body), body, 'application/json');
        System.assertEquals(200, r.statusCode);
    }
}
