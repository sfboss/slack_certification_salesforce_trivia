@IsTest
private class SlackCertGameEventHandler_Test {

    @TestSetup static void setup() {
        Tenant__c t = new Tenant__c(Slack_Team_Id__c='T_EV', Workspace_Name__c='W', Plan__c='Pro', Status__c='Active', Installed_At__c=System.now());
        insert t;
    }

    @IsTest static void appHomeOpened() {
        SlackCertGameEventHandler.handle(new Map<String,Object>{
            'team_id'=>'T_EV',
            'event'=>new Map<String,Object>{'type'=>'app_home_opened','user'=>'U1'}
        });
    }

    @IsTest static void uninstallRoutes() {
        SlackCertGameEventHandler.handle(new Map<String,Object>{
            'team_id'=>'T_EV',
            'event'=>new Map<String,Object>{'type'=>'app_uninstalled','user'=>'U1'}
        });
        Tenant__c t = [SELECT Status__c FROM Tenant__c WHERE Slack_Team_Id__c='T_EV'];
        System.assertEquals('Cancelled', t.Status__c);
    }

    @IsTest static void noEventReturnsEmpty() {
        System.assertEquals('', SlackCertGameEventHandler.handle(new Map<String,Object>{}));
    }

    @IsTest static void unknownTypeReturnsEmpty() {
        System.assertEquals('', SlackCertGameEventHandler.handle(new Map<String,Object>{
            'team_id'=>'T_EV',
            'event'=>new Map<String,Object>{'type'=>'message','user'=>'U1'}
        }));
    }
}