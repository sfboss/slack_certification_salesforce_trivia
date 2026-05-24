@IsTest
private class CertGameAchievementService_Test {
    @TestSetup
    static void setup() {
        Tenant__c t = new Tenant__c(
            Slack_Team_Id__c = 'T_ACH',
            Workspace_Name__c = 'Ach',
            Plan__c = 'Free',
            Status__c = 'Active',
            Installed_At__c = System.now()
        );
        insert t;
        Player__c p = new Player__c(
            Tenant__c = t.Id,
            Slack_User_Id__c = 'U_A',
            Display_Name__c = 'A'
        );
        insert p;

        Certification_Exam__c ex = new Certification_Exam__c(
            Name = 'E',
            Certification_Code__c = 'ACH-1',
            Vendor__c = 'SF',
            Active__c = true
        );
        insert ex;
        Question_Bank__c bk = new Question_Bank__c(
            Name = 'B',
            Certification_Exam__c = ex.Id,
            Source_Type__c = 'Manual',
            Status__c = 'Published',
            Version__c = '1.0',
            External_Id__c = 'B-ACH'
        );
        insert bk;
        Trivia_Question__c q = new Trivia_Question__c(
            External_Id__c = 'ACH-Q1',
            Certification_Exam__c = ex.Id,
            Question_Bank__c = bk.Id,
            Question_Text__c = 'Q?',
            Question_Type__c = 'Single Select',
            Difficulty__c = 'Beginner',
            Status__c = 'Published',
            Correct_Answer_Mode__c = 'Exact',
            Hash__c = 'h'
        );
        insert q;
        Game_Session__c s = new Game_Session__c(
            Tenant__c = t.Id,
            Certification_Exam__c = ex.Id,
            Started_At__c = System.now(),
            Mode__c = 'Solo',
            Status__c = 'Active',
            Total_Questions__c = 1,
            Timer_Seconds__c = 30
        );
        insert s;
        Game_Round__c r = new Game_Round__c(
            Game_Session__c = s.Id,
            Trivia_Question__c = q.Id,
            Round_Number__c = 1,
            Status__c = 'Posted',
            Started_At__c = System.now()
        );
        insert r;

        List<Player_Answer__c> pas = new List<Player_Answer__c>();
        for (Integer i = 0; i < 5; i++) {
            pas.add(
                new Player_Answer__c(
                    Game_Round__c = r.Id,
                    Game_Session__c = s.Id,
                    Player__c = p.Id,
                    Trivia_Question__c = q.Id,
                    Selected_Choice_Labels__c = 'A',
                    Is_Correct__c = true,
                    Points_Awarded__c = 10,
                    Answered_At__c = System.now(),
                    Response_Time_Ms__c = 1000,
                    Unique_Key__c = 'r:' + p.Id + ':' + i
                )
            );
        }
        insert pas;

        insert new List<Achievement__c>{
            new Achievement__c(
                Code__c = 'FIRST5',
                Name = '5 Answers',
                Active__c = true,
                Criteria_Type__c = 'TotalAnswers',
                Threshold__c = 5,
                Points__c = 10
            ),
            new Achievement__c(
                Code__c = 'SHARP',
                Name = '5 Correct',
                Active__c = true,
                Criteria_Type__c = 'CorrectAnswers',
                Threshold__c = 5,
                Points__c = 20
            ),
            new Achievement__c(
                Code__c = 'BIG',
                Name = 'Big Points',
                Active__c = true,
                Criteria_Type__c = 'TotalPoints',
                Threshold__c = 1000,
                Points__c = 50
            )
        };
    }

    @IsTest
    static void awardsQualifyingAchievements() {
        Player__c p = [SELECT Id FROM Player__c LIMIT 1];
        QuestionAnswered__e ev = new QuestionAnswered__e(
            Player_Id__c = p.Id,
            Is_Correct__c = true,
            Points__c = 10
        );
        Test.startTest();
        CertGameAchievementService.evaluate(
            new List<QuestionAnswered__e>{ ev }
        );
        Test.stopTest();
        Integer awarded = [
            SELECT COUNT()
            FROM Player_Achievement__c
            WHERE Player__c = :p.Id
        ];
        System.assertEquals(2, awarded);
    }

    @IsTest
    static void duplicateAwardSuppressed() {
        Player__c p = [SELECT Id FROM Player__c LIMIT 1];
        QuestionAnswered__e ev = new QuestionAnswered__e(
            Player_Id__c = p.Id,
            Is_Correct__c = true,
            Points__c = 10
        );
        CertGameAchievementService.evaluate(
            new List<QuestionAnswered__e>{ ev }
        );
        CertGameAchievementService.evaluate(
            new List<QuestionAnswered__e>{ ev }
        );
        Integer awarded = [
            SELECT COUNT()
            FROM Player_Achievement__c
            WHERE Player__c = :p.Id
        ];
        System.assertEquals(2, awarded);
    }

    @IsTest
    static void emptyInputNoop() {
        CertGameAchievementService.evaluate(null);
        CertGameAchievementService.evaluate(new List<QuestionAnswered__e>());
    }
}