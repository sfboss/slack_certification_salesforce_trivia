@IsTest
private class SlackCertGameInteractionHandler_Test {
    @TestSetup
    static void setup() {
        Tenant__c t = new Tenant__c(
            Slack_Team_Id__c = 'T_INT',
            Workspace_Name__c = 'W',
            Plan__c = 'Pro',
            Status__c = 'Active',
            Installed_At__c = System.now()
        );
        insert t;
    }

    private static Map<String, Object> wrap(String actionId) {
        return new Map<String, Object>{
            'team' => new Map<String, Object>{ 'id' => 'T_INT' },
            'user' => new Map<String, Object>{ 'id' => 'U1' },
            'trigger_id' => 'TR1',
            'actions' => new List<Object>{
                new Map<String, Object>{ 'action_id' => actionId }
            }
        };
    }

    @IsTest
    static void noActionsReturnsEmpty() {
        System.assertEquals(
            '',
            SlackCertGameInteractionHandler.handle(
                new Map<String, Object>{ 'actions' => new List<Object>() }
            )
        );
    }

    @IsTest
    static void planOpenRoutes() {
        SlackCertGameInteractionHandler.handle(wrap('plan:open:none'));
    }

    @IsTest
    static void tournamentJoinRoutes() {
        SlackCertGameInteractionHandler.handle(
            wrap('tournament:join:a0X000000000000')
        );
    }

    @IsTest
    static void answerRoutes() {
        SlackCertGameInteractionHandler.handle(
            wrap('game:answer:roundX:choiceY')
        );
    }

    @IsTest
    static void unknownActionEmpty() {
        SlackCertGameInteractionHandler.handle(wrap('x:y:z'));
    }
}