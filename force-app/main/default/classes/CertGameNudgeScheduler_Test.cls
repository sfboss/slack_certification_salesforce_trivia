@IsTest
private class CertGameNudgeScheduler_Test {

    @TestSetup static void setup() {
        Tenant__c t = new Tenant__c(Slack_Team_Id__c='T_NUDGE', Workspace_Name__c='W', Plan__c='Pro', Status__c='Active', Installed_At__c=System.now());
        insert t;
        Player__c p = new Player__c(Tenant__c=t.Id, Slack_User_Id__c='U_N', Display_Name__c='N');
        insert p;
        Certification_Exam__c e = new Certification_Exam__c(Name='X', Certification_Code__c='NDG', Vendor__c='SF', Active__c=true);
        insert e;
        insert new Study_Plan__c(Player__c=p.Id, Certification_Exam__c=e.Id, Daily_Questions__c=5, Active__c=true);
    }

    @IsTest static void runOnceHandlesCalloutFailureGracefully() {
        Test.startTest();
        CertGameNudgeScheduler.runOnce();
        Test.stopTest();
    }

    @IsTest static void scheduleExecutes() {
        Test.startTest();
        String cron = '0 0 14 1 1 ? 2099';
        System.schedule('CertGameNudgeTest', cron, new CertGameNudgeScheduler());
        Test.stopTest();
    }
}