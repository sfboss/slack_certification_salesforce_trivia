@IsTest
private class QuestionReviewController_Test {
    @TestSetup
    static void setup() {
        Certification_Exam__c e = new Certification_Exam__c(
            Name = 'X',
            Certification_Code__c = 'QRC',
            Vendor__c = 'SF',
            Active__c = true
        );
        insert e;
        Question_Bank__c bank = new Question_Bank__c(
            Name = 'B',
            External_Id__c = 'QRC-B',
            Certification_Exam__c = e.Id,
            Version__c = '1.0',
            Source_Type__c = 'Manual',
            Status__c = 'Published'
        );
        insert bank;
        Trivia_Question__c q = new Trivia_Question__c(
            External_Id__c = 'Q1',
            Certification_Exam__c = e.Id,
            Question_Bank__c = bank.Id,
            Question_Text__c = 'Q?',
            Difficulty__c = 'Beginner',
            Question_Type__c = 'Single Select',
            Status__c = 'Needs Review'
        );
        insert q;
        insert new Trivia_Answer_Choice__c(
            Trivia_Question__c = q.Id,
            Choice_Label__c = 'A',
            Choice_Text__c = 'a',
            Is_Correct__c = true,
            Sort_Order__c = 1
        );
        insert new Trivia_Answer_Choice__c(
            Trivia_Question__c = q.Id,
            Choice_Label__c = 'B',
            Choice_Text__c = 'b',
            Is_Correct__c = false,
            Sort_Order__c = 2
        );
        insert new Question_Citation__c(
            Trivia_Question__c = q.Id,
            Title__c = 'T',
            URL__c = 'https://example.com',
            Source_Type__c = 'Salesforce Help'
        );
    }

    private static QuestionReviewController.ReviewPayload payloadFor(Id qid) {
        QuestionReviewController.ReviewPayload p = new QuestionReviewController.ReviewPayload();
        p.id = qid;
        p.questionText = 'Updated stem?';
        p.difficulty = 'Intermediate';
        p.questionType = 'Single Select';
        p.tags = 'foo,bar';
        p.reviewerNotes = 'Looks good';
        p.choices = new List<QuestionReviewController.ChoiceDto>();
        for (Trivia_Answer_Choice__c c : [
            SELECT Id, Choice_Label__c, Is_Correct__c
            FROM Trivia_Answer_Choice__c
            WHERE Trivia_Question__c = :qid
        ]) {
            QuestionReviewController.ChoiceDto cd = new QuestionReviewController.ChoiceDto();
            cd.id = c.Id;
            cd.label = c.Choice_Label__c;
            cd.text = 'updated ' + c.Choice_Label__c;
            cd.isCorrect = c.Is_Correct__c;
            p.choices.add(cd);
        }
        return p;
    }

    @IsTest
    static void fetchQueueReturnsRows() {
        QuestionReviewController.QueueResult qr = QuestionReviewController.fetchQueue(
            'Needs Review',
            'CreatedDate',
            null
        );
        System.assert(qr.total >= 1);
        System.assert(!qr.questions.isEmpty());
        QuestionReviewController.ReviewQuestionDto d = qr.questions[0];
        System.assertEquals(2, d.choices.size());
        System.assertEquals(1, d.citations.size());
    }

    @IsTest
    static void fetchQueueRejectsBadStatus() {
        try {
            QuestionReviewController.fetchQueue('Bogus', null, null);
            System.assert(false);
        } catch (Exception e) {
            System.assert(true);
        }
    }

    @IsTest
    static void statusCountsAggregates() {
        Map<String, Integer> counts = QuestionReviewController.getStatusCounts();
        System.assert(counts.containsKey('Needs Review'));
    }

    @IsTest
    static void saveEditsAppliesChanges() {
        Trivia_Question__c q = [SELECT Id FROM Trivia_Question__c LIMIT 1];
        QuestionReviewController.saveEdits(payloadFor(q.Id));
        Trivia_Question__c after = [
            SELECT Question_Text__c, Difficulty__c, Tags__c
            FROM Trivia_Question__c
            WHERE Id = :q.Id
        ];
        System.assertEquals('Updated stem?', after.Question_Text__c);
        System.assertEquals('Intermediate', after.Difficulty__c);
        System.assertEquals('foo,bar', after.Tags__c);
    }

    @IsTest
    static void publishBlockedWithoutFactCheck() {
        Trivia_Question__c q = [SELECT Id FROM Trivia_Question__c LIMIT 1];
        try {
            QuestionReviewController.publish(payloadFor(q.Id));
            System.assert(false, 'Should have thrown');
        } catch (AuraHandledException e) {
            // expected
        }
        Trivia_Question__c after = [
            SELECT Status__c
            FROM Trivia_Question__c
            WHERE Id = :q.Id
        ];
        System.assertNotEquals('Published', after.Status__c);
    }

    @IsTest
    static void doubleOkPublishesAndStamps() {
        Trivia_Question__c q = [SELECT Id FROM Trivia_Question__c LIMIT 1];
        QuestionReviewController.markFactsVerified(payloadFor(q.Id));
        Trivia_Question__c afterFact = [
            SELECT
                Status__c,
                Fact_Check_Passed__c,
                Fact_Checked_By__c,
                Fact_Checked_Date__c
            FROM Trivia_Question__c
            WHERE Id = :q.Id
        ];
        System.assertEquals(true, afterFact.Fact_Check_Passed__c);
        System.assertEquals('Fact Verified', afterFact.Status__c);
        System.assertEquals(UserInfo.getUserId(), afterFact.Fact_Checked_By__c);
        System.assertNotEquals(null, afterFact.Fact_Checked_Date__c);

        QuestionReviewController.publish(payloadFor(q.Id));
        Trivia_Question__c afterPub = [
            SELECT Status__c, Published_By__c, Published_Date__c
            FROM Trivia_Question__c
            WHERE Id = :q.Id
        ];
        System.assertEquals('Published', afterPub.Status__c);
        System.assertEquals(UserInfo.getUserId(), afterPub.Published_By__c);
        System.assertNotEquals(null, afterPub.Published_Date__c);
    }

    @IsTest
    static void clearFactsResetsStatus() {
        Trivia_Question__c q = [SELECT Id FROM Trivia_Question__c LIMIT 1];
        QuestionReviewController.markFactsVerified(payloadFor(q.Id));
        QuestionReviewController.clearFactsVerified(q.Id);
        Trivia_Question__c after = [
            SELECT Status__c, Fact_Check_Passed__c
            FROM Trivia_Question__c
            WHERE Id = :q.Id
        ];
        System.assertEquals(false, after.Fact_Check_Passed__c);
        System.assertEquals('Needs Review', after.Status__c);
    }

    @IsTest
    static void needsRevisionRequiresNotes() {
        Trivia_Question__c q = [SELECT Id FROM Trivia_Question__c LIMIT 1];
        QuestionReviewController.ReviewPayload p = payloadFor(q.Id);
        p.reviewerNotes = '';
        try {
            QuestionReviewController.needsRevision(p);
            System.assert(false);
        } catch (AuraHandledException e) {
            /* expected */
        }

        p.reviewerNotes = 'Fix citation';
        QuestionReviewController.needsRevision(p);
        Trivia_Question__c after = [
            SELECT Status__c, Reviewer_Notes__c
            FROM Trivia_Question__c
            WHERE Id = :q.Id
        ];
        System.assertEquals('Needs Revision', after.Status__c);
        System.assertEquals('Fix citation', after.Reviewer_Notes__c);
    }

    @IsTest
    static void retireSetsStatus() {
        Trivia_Question__c q = [SELECT Id FROM Trivia_Question__c LIMIT 1];
        QuestionReviewController.retire(q.Id);
        Trivia_Question__c after = [
            SELECT Status__c
            FROM Trivia_Question__c
            WHERE Id = :q.Id
        ];
        System.assertEquals('Retired', after.Status__c);
    }

    @IsTest
    static void setStatusLegacyStillWorks() {
        Trivia_Question__c q = [SELECT Id FROM Trivia_Question__c LIMIT 1];
        QuestionReviewController.setStatus(q.Id, 'Reviewed');
        Trivia_Question__c after = [
            SELECT Status__c
            FROM Trivia_Question__c
            WHERE Id = :q.Id
        ];
        System.assertEquals('Reviewed', after.Status__c);
    }

    @IsTest
    static void setStatusValidates() {
        try {
            QuestionReviewController.setStatus(null, 'Reviewed');
            System.assert(false);
        } catch (Exception e) {
        }
        Trivia_Question__c q = [SELECT Id FROM Trivia_Question__c LIMIT 1];
        try {
            QuestionReviewController.setStatus(q.Id, 'Bogus');
            System.assert(false);
        } catch (Exception e) {
        }
    }

    @IsTest
    static void verifyCitationUpdatesRecord() {
        Question_Citation__c c = [SELECT Id FROM Question_Citation__c LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new CitationMock(200));
        Test.startTest();
        QuestionReviewController.CitationDto d = QuestionReviewController.verifyCitation(
            c.Id
        );
        Test.stopTest();
        System.assertEquals(false, d.brokenLink);
        Question_Citation__c after = [
            SELECT Broken_Link__c, Last_Verified_Date__c
            FROM Question_Citation__c
            WHERE Id = :c.Id
        ];
        System.assertEquals(false, after.Broken_Link__c);
        System.assertNotEquals(null, after.Last_Verified_Date__c);
    }

    @IsTest
    static void verifyCitationFlagsBrokenLink() {
        Question_Citation__c c = [SELECT Id FROM Question_Citation__c LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new CitationMock(404));
        Test.startTest();
        QuestionReviewController.CitationDto d = QuestionReviewController.verifyCitation(
            c.Id
        );
        Test.stopTest();
        System.assertEquals(true, d.brokenLink);
    }

    private class CitationMock implements HttpCalloutMock {
        Integer code;
        CitationMock(Integer c) {
            this.code = c;
        }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse r = new HttpResponse();
            r.setStatusCode(code);
            r.setStatus(code == 200 ? 'OK' : 'Not Found');
            return r;
        }
    }
}