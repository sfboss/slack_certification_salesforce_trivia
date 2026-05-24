@IsTest
private class CertGameDuelService_Test {
    @TestSetup
    static void setup() {
        Tenant__c t = new Tenant__c(
            Slack_Team_Id__c = 'T_DUEL',
            Workspace_Name__c = 'Duel WS',
            Plan__c = 'Free',
            Status__c = 'Active',
            Installed_At__c = System.now()
        );
        insert t;
        Certification_Exam__c ex = new Certification_Exam__c(
            Name = 'Duel Exam',
            Certification_Code__c = 'DUEL-1',
            Vendor__c = 'Salesforce',
            Active__c = true
        );
        insert ex;
        Question_Bank__c bank = new Question_Bank__c(
            Name = 'DBank',
            Certification_Exam__c = ex.Id,
            Source_Type__c = 'Manual',
            Status__c = 'Published',
            Version__c = '1.0',
            External_Id__c = 'BANK-D'
        );
        insert bank;
        List<Trivia_Question__c> qs = new List<Trivia_Question__c>();
        for (Integer i = 0; i < 3; i++) {
            qs.add(
                new Trivia_Question__c(
                    External_Id__c = 'DQ-' + i,
                    Certification_Exam__c = ex.Id,
                    Question_Bank__c = bank.Id,
                    Question_Text__c = 'Q' + i,
                    Question_Type__c = 'Single Select',
                    Difficulty__c = 'Beginner',
                    Status__c = 'Published',
                    Correct_Answer_Mode__c = 'Exact',
                    Hash__c = 'dh' + i
                )
            );
        }
        insert qs;
        List<Trivia_Answer_Choice__c> choices = new List<Trivia_Answer_Choice__c>();
        for (Trivia_Question__c q : qs) {
            choices.add(
                new Trivia_Answer_Choice__c(
                    Trivia_Question__c = q.Id,
                    Choice_Label__c = 'A',
                    Choice_Text__c = 'a',
                    Is_Correct__c = true,
                    Sort_Order__c = 1
                )
            );
            choices.add(
                new Trivia_Answer_Choice__c(
                    Trivia_Question__c = q.Id,
                    Choice_Label__c = 'B',
                    Choice_Text__c = 'b',
                    Is_Correct__c = false,
                    Sort_Order__c = 2
                )
            );
        }
        insert choices;
    }

    private class SlackOkMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse r = new HttpResponse();
            r.setStatusCode(200);
            r.setHeader('Content-Type', 'application/json');
            r.setBody('{"ok":true,"channel":{"id":"D1"},"ts":"1.1"}');
            return r;
        }
    }

    @IsTest
    static void challengeUsageWithoutMention() {
        String envelope = CertGameDuelService.openChallengeFromSlack(
            'T_DUEL',
            'U_A',
            'C_X',
            new List<String>{ 'challenge' }
        );
        System.assert(envelope.contains('Usage'), envelope);
    }

    @IsTest
    static void cannotChallengeSelf() {
        String envelope = CertGameDuelService.openChallengeFromSlack(
            'T_DUEL',
            'U_A',
            'C_X',
            new List<String>{ 'challenge', '<@U_A>' }
        );
        System.assert(envelope.contains('two players'), envelope);
    }

    @IsTest
    static void challengeFromDmRejected() {
        String envelope = CertGameDuelService.openChallengeFromSlack(
            'T_DUEL',
            'U_A',
            null,
            new List<String>{ 'challenge', '<@U_B>' }
        );
        System.assert(envelope.contains('channel'), envelope);
    }

    @IsTest
    static void challengeHappyPathReturnsCard() {
        String envelope = CertGameDuelService.openChallengeFromSlack(
            'T_DUEL',
            'U_A',
            'C_X',
            new List<String>{ 'challenge', '<@U_B|bob>', 'DUEL-1' }
        );
        System.assert(envelope.contains('duel:accept:U_A:U_B'), envelope);
        System.assert(envelope.contains('duel:decline:U_A:U_B'), envelope);
    }

    @IsTest
    static void acceptByWrongUserRejected() {
        Certification_Exam__c ex = [
            SELECT Id
            FROM Certification_Exam__c
            LIMIT 1
        ];
        String envelope = CertGameDuelService.acceptChallengeFromSlack(
            'T_DUEL',
            'U_C',
            'U_A',
            'U_B',
            ex.Id,
            'DG_TEST_1',
            'C_X'
        );
        System.assert(
            envelope.contains('challenged player can accept'),
            envelope
        );
    }

    @IsTest
    static void acceptHappyPathCreatesBothSessions() {
        Test.setMock(HttpCalloutMock.class, new SlackOkMock());
        Certification_Exam__c ex = [
            SELECT Id
            FROM Certification_Exam__c
            LIMIT 1
        ];
        Test.startTest();
        String envelope = CertGameDuelService.acceptChallengeFromSlack(
            'T_DUEL',
            'U_B',
            'U_A',
            'U_B',
            ex.Id,
            'DG_TEST_2',
            'C_X'
        );
        Test.stopTest();
        System.assert(envelope.contains('Duel in progress'), envelope);
        List<Game_Session__c> sessions = [
            SELECT Id, Mode__c, Duel_Role__c, Duel_Origin_Channel_Id__c
            FROM Game_Session__c
            WHERE Duel_Group_Id__c = 'DG_TEST_2'
        ];
        System.assertEquals(2, sessions.size());
        Set<String> roles = new Set<String>();
        for (Game_Session__c s : sessions) {
            System.assertEquals('Duel', s.Mode__c);
            System.assertEquals('C_X', s.Duel_Origin_Channel_Id__c);
            roles.add(s.Duel_Role__c);
        }
        System.assert(roles.contains('Challenger'));
        System.assert(roles.contains('Opponent'));
        System.assertEquals(
            2,
            [
                SELECT COUNT()
                FROM Game_Round__c
                WHERE Game_Session__r.Duel_Group_Id__c = 'DG_TEST_2'
            ]
        );
    }

    @IsTest
    static void doubleAcceptIsNoop() {
        Test.setMock(HttpCalloutMock.class, new SlackOkMock());
        Certification_Exam__c ex = [
            SELECT Id
            FROM Certification_Exam__c
            LIMIT 1
        ];
        CertGameDuelService.acceptChallengeFromSlack(
            'T_DUEL',
            'U_B',
            'U_A',
            'U_B',
            ex.Id,
            'DG_TEST_3',
            'C_X'
        );
        String env = CertGameDuelService.acceptChallengeFromSlack(
            'T_DUEL',
            'U_B',
            'U_A',
            'U_B',
            ex.Id,
            'DG_TEST_3',
            'C_X'
        );
        System.assert(env.contains('already underway'), env);
    }

    @IsTest
    static void declineHappyPath() {
        String env = CertGameDuelService.declineChallengeFromSlack(
            'U_B',
            'U_A',
            'U_B'
        );
        System.assert(env.contains('declined'), env);
    }

    @IsTest
    static void declineByWrongUserRejected() {
        String env = CertGameDuelService.declineChallengeFromSlack(
            'U_C',
            'U_A',
            'U_B'
        );
        System.assert(env.contains('challenged player can decline'), env);
    }

    @IsTest
    static void onSessionCompletePostsFinaleWhenBothDone() {
        Test.setMock(HttpCalloutMock.class, new SlackOkMock());
        Certification_Exam__c ex = [
            SELECT Id
            FROM Certification_Exam__c
            LIMIT 1
        ];
        // Bootstrap a duel and mark both sessions complete.
        CertGameDuelService.acceptChallengeFromSlack(
            'T_DUEL',
            'U_B',
            'U_A',
            'U_B',
            ex.Id,
            'DG_TEST_4',
            'C_X'
        );
        List<Game_Session__c> sessions = [
            SELECT Id
            FROM Game_Session__c
            WHERE Duel_Group_Id__c = 'DG_TEST_4'
        ];
        for (Game_Session__c s : sessions) {
            s.Status__c = 'Complete';
            s.Completed_At__c = System.now();
        }
        update sessions;
        Test.startTest();
        CertGameDuelService.onSessionComplete(sessions[0].Id);
        Test.stopTest();
        // Success criterion: no exception, future drained. (Mock absorbs the callout.)
        System.assertEquals(
            2,
            [
                SELECT COUNT()
                FROM Game_Session__c
                WHERE Duel_Group_Id__c = 'DG_TEST_4' AND Status__c = 'Complete'
            ]
        );
    }

    @IsTest
    static void onSessionCompleteWaitsForOtherSide() {
        Test.setMock(HttpCalloutMock.class, new SlackOkMock());
        Certification_Exam__c ex = [
            SELECT Id
            FROM Certification_Exam__c
            LIMIT 1
        ];
        CertGameDuelService.acceptChallengeFromSlack(
            'T_DUEL',
            'U_B',
            'U_A',
            'U_B',
            ex.Id,
            'DG_TEST_5',
            'C_X'
        );
        List<Game_Session__c> sessions = [
            SELECT Id
            FROM Game_Session__c
            WHERE Duel_Group_Id__c = 'DG_TEST_5'
            LIMIT 1
        ];
        sessions[0].Status__c = 'Complete';
        update sessions;
        Test.startTest();
        CertGameDuelService.onSessionComplete(sessions[0].Id);
        Test.stopTest();
        // The other side is still Active; finale path should early-return without error.
        System.assertEquals(
            1,
            [
                SELECT COUNT()
                FROM Game_Session__c
                WHERE Duel_Group_Id__c = 'DG_TEST_5' AND Status__c = 'Complete'
            ]
        );
    }

    @IsTest
    static void parseUserMentionForms() {
        System.assertEquals(
            'U123',
            CertGameDuelService.parseUserMention('<@U123>')
        );
        System.assertEquals(
            'U456',
            CertGameDuelService.parseUserMention('<@U456|alice>')
        );
        System.assertEquals(
            'U789',
            CertGameDuelService.parseUserMention('@U789')
        );
        System.assertEquals(
            'U000',
            CertGameDuelService.parseUserMention('U000')
        );
        System.assertEquals(
            null,
            CertGameDuelService.parseUserMention('hello')
        );
        System.assertEquals(null, CertGameDuelService.parseUserMention(''));
    }
}