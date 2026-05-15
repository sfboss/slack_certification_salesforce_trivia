@IsTest
private class SlackCertGameModalHandler_Test {

    @TestSetup static void setup() {
        Tenant__c t = new Tenant__c(Slack_Team_Id__c='T_MD', Workspace_Name__c='W', Plan__c='Pro', Status__c='Active', Installed_At__c=System.now());
        insert t;
    }

    private static Map<String,Object> wrap(String cb) {
        return new Map<String,Object>{
            'team'=>new Map<String,Object>{'id'=>'T_MD'},
            'user'=>new Map<String,Object>{'id'=>'U1'},
            'view'=>new Map<String,Object>{'callback_id'=>cb, 'state'=>new Map<String,Object>{'values'=>new Map<String,Object>{}}}
        };
    }

    @IsTest static void noViewReturnsEmpty() {
        System.assertEquals('', SlackCertGameModalHandler.handle(new Map<String,Object>{}));
    }

    @IsTest static void planCreateRoutes() {
        SlackCertGameModalHandler.handle(wrap('plan:create'));
    }

    @IsTest static void billingUpgradeRoutes() {
        SlackCertGameModalHandler.handle(wrap('billing:upgrade'));
    }

    @IsTest static void tournamentCreateRoutes() {
        SlackCertGameModalHandler.handle(wrap('tournament:create'));
    }

    @IsTest static void unknownNoop() {
        SlackCertGameModalHandler.handle(wrap('x:y'));
    }
}
