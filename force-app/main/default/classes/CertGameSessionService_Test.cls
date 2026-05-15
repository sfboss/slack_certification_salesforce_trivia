@IsTest
private class CertGameSessionService_Test {

    @TestSetup static void setup() {
        Tenant__c t = new Tenant__c(
            Slack_Team_Id__c = 'T_SESS', Workspace_Name__c = 'Sess WS', Plan__c = 'Free',
            Status__c = 'Active', Installed_At__c = System.now()
        );
        insert t;
        Certification_Exam__c ex = new Certification_Exam__c(
            Name = 'Sess Exam', Certification_Code__c = 'SESS-1',
            Vendor__c = 'Salesforce', Active__c = true
        );
        insert ex;
        Question_Bank__c bank = new Question_Bank__c(
            Name='B', Certification_Exam__c=ex.Id, Source_Type__c='Manual',
            Status__c='Published', Version__c='1.0', External_Id__c='BANK-S'
        );
        insert bank;
        Trivia_Question__c q = new Trivia_Question__c(
            External_Id__c='SESS-Q1', Certification_Exam__c=ex.Id, Question_Bank__c=bank.Id,
            Question_Text__c='Q?', Question_Type__c='Single Select',
            Difficulty__c='Beginner', Status__c='Published',
            Correct_Answer_Mode__c='Exact', Hash__c='h1'
        );
        insert q;
        insert new List<Trivia_Answer_Choice__c>{
            new Trivia_Answer_Choice__c(Trivia_Question__c=q.Id, Choice_Label__c='A', Choice_Text__c='a', Is_Correct__c=true, Sort_Order__c=1),
            new Trivia_Answer_Choice__c(Trivia_Question__c=q.Id, Choice_Label__c='B', Choice_Text__c='b', Is_Correct__c=false, Sort_Order__c=2),
            new Trivia_Answer_Choice__c(Trivia_Question__c=q.Id, Choice_Label__c='C', Choice_Text__c='c', Is_Correct__c=false, Sort_Order__c=3)
        };
    }

    @IsTest static void startQuickGameRendersFirstRound() {
        String json = CertGameSessionService.startQuickGameFromSlack('T_SESS', 'U_S1', 'C1', new List<String>{'play'});
        System.assert(json != null);
        System.assert(json.contains('blocks') || json.contains('text'));
        System.assertEquals(1, [SELECT COUNT() FROM Game_Session__c WHERE Slack_Team_Id__c='T_SESS']);
        System.assertEquals(1, [SELECT COUNT() FROM Game_Round__c]);
    }

    @IsTest static void recordCorrectAnswerScores() {
        CertGameSessionService.startQuickGameFromSlack('T_SESS', 'U_S2', 'C1', new List<String>{'play'});
        Game_Round__c rd = [SELECT Id FROM Game_Round__c LIMIT 1];
        Trivia_Answer_Choice__c correct = [SELECT Id FROM Trivia_Answer_Choice__c WHERE Is_Correct__c = true LIMIT 1];
        String json = CertGameSessionService.recordAnswerFromSlack('T_SESS', 'U_S2', rd.Id, correct.Id);
        System.assert(json != null);
        Player_Answer__c pa = [SELECT Is_Correct__c, Points_Awarded__c, Selected_Choice_Labels__c FROM Player_Answer__c LIMIT 1];
        System.assert(pa.Is_Correct__c);
        System.assert(pa.Points_Awarded__c > 0);
        System.assertEquals('A', pa.Selected_Choice_Labels__c);
    }

    @IsTest static void duplicateAnswerRejected() {
        CertGameSessionService.startQuickGameFromSlack('T_SESS', 'U_S3', 'C1', new List<String>{'play'});
        Game_Round__c rd = [SELECT Id FROM Game_Round__c LIMIT 1];
        Trivia_Answer_Choice__c correct = [SELECT Id FROM Trivia_Answer_Choice__c WHERE Is_Correct__c = true LIMIT 1];
        CertGameSessionService.recordAnswerFromSlack('T_SESS', 'U_S3', rd.Id, correct.Id);
        String json2 = CertGameSessionService.recordAnswerFromSlack('T_SESS', 'U_S3', rd.Id, correct.Id);
        System.assert(json2 != null);
        System.assertEquals(1, [SELECT COUNT() FROM Player_Answer__c]);
    }

    @IsTest static void invalidRoundReturnsError() {
        String json = CertGameSessionService.recordAnswerFromSlack('T_SESS', 'U_X', null, null);
        System.assert(json != null);
    }
}
