@IsTest
private class QuestionDuplicateDetector_Test {
    @IsTest
    static void identicalQuestionsHashEqual() {
        String h1 = QuestionDuplicateDetector.hash(
            'What is X?',
            new List<String>{ 'Foo' }
        );
        String h2 = QuestionDuplicateDetector.hash(
            '  what is X?  ',
            new List<String>{ 'foo' }
        );
        System.assertEquals(h1, h2);
    }

    @IsTest
    static void differentQuestionsDiffer() {
        String h1 = QuestionDuplicateDetector.hash(
            'A',
            new List<String>{ 'x' }
        );
        String h2 = QuestionDuplicateDetector.hash(
            'B',
            new List<String>{ 'x' }
        );
        System.assertNotEquals(h1, h2);
    }

    @IsTest
    static void hashFromQuestionRecord() {
        Trivia_Question__c q = new Trivia_Question__c(Question_Text__c = 'Q');
        List<Trivia_Answer_Choice__c> cs = new List<Trivia_Answer_Choice__c>{
            new Trivia_Answer_Choice__c(
                Choice_Text__c = 'c1',
                Is_Correct__c = true
            ),
            new Trivia_Answer_Choice__c(
                Choice_Text__c = 'c2',
                Is_Correct__c = false
            )
        };
        String h = QuestionDuplicateDetector.hash(q, cs);
        System.assertNotEquals(null, h);
    }

    @IsTest
    static void findDuplicateHashesEmpty() {
        System.assert(
            QuestionDuplicateDetector.findDuplicateHashes(new Set<String>())
                .isEmpty()
        );
    }
}