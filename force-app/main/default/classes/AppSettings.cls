public with sharing class AppSettings {
    private static App_Setting__mdt cached;

    public static App_Setting__mdt get() {
        if (cached != null) return cached;
        List<App_Setting__mdt> rows = [
            SELECT Default_Provider__c, Default_Model__c, Max_Questions_Per_Game__c,
                   Max_Generation_Per_Day_Free__c, Max_Generation_Per_Day_Pro__c,
                   Max_Games_Per_Day_Free__c,
                   Slack_Signing_Secret_Named_Credential__c, Slack_Bot_Named_Credential__c,
                   Stripe_Named_Credential__c, OpenAI_Named_Credential__c,
                   Feature_Flag_Generation__c, Feature_Flag_Tournaments__c,
                   Feature_Flag_Billing__c, Feature_Flag_Nudges__c,
                   Slack_Timestamp_Skew_Seconds__c
            FROM App_Setting__mdt
            WHERE DeveloperName = 'Default'
            LIMIT 1
        ];
        if (rows.isEmpty()) {
            cached = new App_Setting__mdt(
                Default_Provider__c = 'OpenAI',
                Default_Model__c = 'gpt-4.1-mini',
                Max_Questions_Per_Game__c = 65,
                Max_Generation_Per_Day_Free__c = 0,
                Max_Generation_Per_Day_Pro__c = 100,
                Max_Games_Per_Day_Free__c = 5,
                Slack_Signing_Secret_Named_Credential__c = 'Slack_Signing',
                Slack_Bot_Named_Credential__c = 'Slack_Bot',
                Stripe_Named_Credential__c = 'Stripe_API',
                OpenAI_Named_Credential__c = 'OpenAI_API',
                Feature_Flag_Generation__c = true,
                Feature_Flag_Tournaments__c = true,
                Feature_Flag_Billing__c = false,
                Feature_Flag_Nudges__c = true,
                Slack_Timestamp_Skew_Seconds__c = 300
            );
        } else {
            cached = rows[0];
        }
        return cached;
    }

    @TestVisible
    private static void override(App_Setting__mdt s) { cached = s; }
}
