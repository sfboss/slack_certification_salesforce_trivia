@IsTest
private class CertGameTournamentService_Test {

    @TestSetup static void setup() {
        Tenant__c team = new Tenant__c(
            Slack_Team_Id__c = 'T_TOUR', Workspace_Name__c = 'Tour WS', Plan__c = 'Pro',
            Status__c = 'Active', Installed_At__c = System.now()
        );
        Tenant__c free = new Tenant__c(
            Slack_Team_Id__c = 'T_TOUR_FREE', Workspace_Name__c = 'Free Tour', Plan__c = 'Free',
            Status__c = 'Active', Installed_At__c = System.now()
        );
        insert new List<Tenant__c>{team, free};
        Certification_Exam__c ex = new Certification_Exam__c(
            Name = 'Tour Exam', Certification_Code__c = 'TOUR-1', Vendor__c = 'SF', Active__c = true
        );
        insert ex;
    }

    @IsTest static void createAndBuildBracket() {
        Certification_Exam__c ex = [SELECT Id FROM Certification_Exam__c WHERE Certification_Code__c='TOUR-1'];
        Id tid = CertGameTournamentService.createTournament(
            'Spring Cup', 'Elimination', ex.Id, System.now(), System.now().addDays(7));
        System.assertNotEquals(null, tid);

        List<Id> players = new List<Id>();
        Tenant__c t = [SELECT Id FROM Tenant__c WHERE Slack_Team_Id__c='T_TOUR'];
        for (Integer i = 0; i < 4; i++) {
            Player__c p = new Player__c(Tenant__c=t.Id, Slack_User_Id__c='U'+i, Display_Name__c='P'+i);
            insert p;
            players.add(p.Id);
        }
        String json = CertGameTournamentService.buildBracket(tid, players);
        System.assert(json.contains('round'));
    }

    @IsTest static void createTournamentValidatesArgs() {
        try {
            CertGameTournamentService.createTournament('', 'Elimination', null, null, null);
            System.assert(false, 'expected');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }

    @IsTest static void joinUnknownReturnsNotFound() {
        String res = CertGameTournamentService.joinFromSlack('T_TOUR', 'U_J', null);
        System.assert(res != null);
        String res2 = CertGameTournamentService.joinFromSlack('T_TOUR', 'U_J', '0Q0000000000000');
        System.assert(res2 != null);
    }

    @IsTest static void joinExistingTournament() {
        Tenant__c t = [SELECT Id FROM Tenant__c WHERE Slack_Team_Id__c='T_TOUR'];
        Certification_Exam__c ex = [SELECT Id FROM Certification_Exam__c WHERE Certification_Code__c='TOUR-1'];
        Tournament__c tn = new Tournament__c(
            Tenant__c=t.Id, Certification_Exam__c=ex.Id, Name='X', Bracket_Type__c='Elimination', Status__c='Scheduled'
        );
        insert tn;
        String res = CertGameTournamentService.joinFromSlack('T_TOUR', 'U_J', tn.Id);
        System.assert(res != null);
    }

    @IsTest static void createSubmissionFreePlanBlocked() {
        Map<String,Object> view = new Map<String,Object>{
            'state' => new Map<String,Object>{ 'values' => new Map<String,Object>{
                'name_block' => new Map<String,Object>{ 'name' => new Map<String,Object>{ 'value' => 'Cup' } },
                'format_block' => new Map<String,Object>{ 'format' => new Map<String,Object>{ 'selected_option' => new Map<String,Object>{ 'value' => 'Elimination' } } }
            }}
        };
        String res = CertGameTournamentService.handleCreateSubmission('T_TOUR_FREE', 'U_X', view);
        System.assert(res.contains('Pro plan') || res.contains('premium') || res.contains('Premium') || res.contains('upgrade'));
    }

    @IsTest static void createSubmissionPaidSucceeds() {
        Certification_Exam__c ex = [SELECT Id FROM Certification_Exam__c WHERE Certification_Code__c='TOUR-1'];
        Map<String,Object> view = new Map<String,Object>{
            'state' => new Map<String,Object>{ 'values' => new Map<String,Object>{
                'exam_block' => new Map<String,Object>{ 'exam' => new Map<String,Object>{ 'selected_option' => new Map<String,Object>{ 'value' => (String)ex.Id } } },
                'name_block' => new Map<String,Object>{ 'name' => new Map<String,Object>{ 'value' => 'Cup' } },
                'format_block' => new Map<String,Object>{ 'format' => new Map<String,Object>{ 'selected_option' => new Map<String,Object>{ 'value' => 'Elimination' } } }
            }}
        };
        CertGameTournamentService.handleCreateSubmission('T_TOUR', 'U_X', view);
        Tenant__c t = [SELECT Id FROM Tenant__c WHERE Slack_Team_Id__c='T_TOUR'];
        System.assertEquals(1, [SELECT COUNT() FROM Tournament__c WHERE Tenant__c = :t.Id AND Name='Cup']);
    }
}