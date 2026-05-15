@IsTest
private class QuestionReviewController_Test {

    @TestSetup static void setup() {
        Certification_Exam__c e = new Certification_Exam__c(Name='X', Certification_Code__c='QRC', Vendor__c='SF', Active__c=true);
        insert e;
        Question_Bank__c bank = new Question_Bank__c(Name='B', External_Id__c='QRC-B', Certification_Exam__c=e.Id, Version__c='1.0', Source_Type__c='Manual', Status__c='Published');
        insert bank;
        Trivia_Question__c q = new Trivia_Question__c(
            External_Id__c='Q1', Certification_Exam__c=e.Id, Question_Bank__c=bank.Id,
            Question_Text__c='Q?', Difficulty__c='Beginner', Question_Type__c='Single Select',
            Status__c='Draft'
        );
        insert q;
        insert new Trivia_Answer_Choice__c(Trivia_Question__c=q.Id, Choice_Label__c='A', Choice_Text__c='a', Is_Correct__c=true, Sort_Order__c=1);
        insert new Question_Citation__c(Trivia_Question__c=q.Id, Title__c='T', URL__c='https://x', Source_Type__c='Salesforce Help');
    }

    @IsTest static void listDraftsReturnsRows() {
        List<QuestionReviewController.DraftQuestionDto> rows = QuestionReviewController.listDrafts('Draft', null);
        System.assert(!rows.isEmpty());
    }

    @IsTest static void setStatusUpdates() {
        Trivia_Question__c q = [SELECT Id FROM Trivia_Question__c LIMIT 1];
        QuestionReviewController.setStatus(q.Id, 'Reviewed');
        Trivia_Question__c after = [SELECT Status__c FROM Trivia_Question__c WHERE Id=:q.Id];
        System.assertEquals('Reviewed', after.Status__c);
    }

    @IsTest static void setStatusValidates() {
        try { QuestionReviewController.setStatus(null, 'Reviewed'); System.assert(false); } catch (Exception e) {}
        Trivia_Question__c q = [SELECT Id FROM Trivia_Question__c LIMIT 1];
        try { QuestionReviewController.setStatus(q.Id, 'Bogus'); System.assert(false); } catch (Exception e) {}
    }
}
