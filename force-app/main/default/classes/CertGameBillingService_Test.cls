@IsTest
private class CertGameBillingService_Test {

    @IsTest static void openBillingNoCalloutAllowedSafely() {
        // openView throws because no Named Credential in test; caught and logged.
        CertGameBillingService.openBillingModal('T_BL', 'U1', 'TR1');
    }

    @IsTest static void handleUpgradeFree() {
        Map<String,Object> view = new Map<String,Object>{
            'state'=> new Map<String,Object>{ 'values'=> new Map<String,Object>{
                'plan_block'=> new Map<String,Object>{ 'plan'=> new Map<String,Object>{
                    'selected_option'=> new Map<String,Object>{ 'value'=>'Free' }
                }}}}};
        CertGameBillingService.handleUpgradeSubmission('T_BL', 'U1', view);
        Tenant__c t = [SELECT Plan__c FROM Tenant__c WHERE Slack_Team_Id__c='T_BL'];
        System.assertEquals('Free', t.Plan__c);
    }

    @IsTest static void handleUpgradePaidIntent() {
        Map<String,Object> view = new Map<String,Object>{
            'state'=> new Map<String,Object>{ 'values'=> new Map<String,Object>{
                'plan_block'=> new Map<String,Object>{ 'plan'=> new Map<String,Object>{
                    'selected_option'=> new Map<String,Object>{ 'value'=>'Pro' }
                }}}}};
        CertGameBillingService.handleUpgradeSubmission('T_BL2', 'U1', view);
    }

    @IsTest static void handleUpgradeNoSelection() {
        Map<String,Object> view = new Map<String,Object>{
            'state'=> new Map<String,Object>{ 'values'=> new Map<String,Object>{
                'plan_block'=> new Map<String,Object>{ 'plan'=> new Map<String,Object>{}}}}};
        CertGameBillingService.handleUpgradeSubmission('T_BL3', 'U1', view);
    }
}
