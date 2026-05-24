@IsTest
private class CertGameQuestionBankController_Test {
    @TestSetup
    static void setup() {
        Certification_Exam__c exam = new Certification_Exam__c(
            Name = 'Test Exam',
            Certification_Code__c = 'TEST-001',
            Active__c = true
        );
        insert exam;

        Question_Bank__c bank = new Question_Bank__c(
            Name = 'Test Bank',
            Certification_Exam__c = exam.Id,
            Status__c = 'Draft',
            Source_Type__c = 'Manual',
            Version__c = '1.0.0',
            External_Id__c = 'BANK-TEST-001'
        );
        insert bank;

        List<Trivia_Question__c> qs = new List<Trivia_Question__c>{
            new Trivia_Question__c(
                External_Id__c = 'TQ-1',
                Certification_Exam__c = exam.Id,
                Question_Bank__c = bank.Id,
                Question_Text__c = 'Q1?',
                Difficulty__c = 'Beginner',
                Question_Type__c = 'Single Select',
                Status__c = 'Published'
            ),
            new Trivia_Question__c(
                External_Id__c = 'TQ-2',
                Certification_Exam__c = exam.Id,
                Question_Bank__c = bank.Id,
                Question_Text__c = 'Q2?',
                Difficulty__c = 'Beginner',
                Question_Type__c = 'Single Select',
                Status__c = 'Draft'
            ),
            new Trivia_Question__c(
                External_Id__c = 'TQ-3',
                Certification_Exam__c = exam.Id,
                Question_Bank__c = bank.Id,
                Question_Text__c = 'Q3?',
                Difficulty__c = 'Intermediate',
                Question_Type__c = 'Single Select',
                Status__c = 'Needs Review'
            )
        };
        insert qs;
    }

    @IsTest
    static void listBanksReturnsRollups() {
        Test.startTest();
        List<CertGameQuestionBankController.BankDto> banks = CertGameQuestionBankController.listBanks();
        Test.stopTest();
        System.assertEquals(1, banks.size(), 'one bank in setup');
        CertGameQuestionBankController.BankDto b = banks[0];
        System.assertEquals('Test Bank', b.name);
        System.assertEquals(3, b.questionCount, 'all questions counted');
        System.assertEquals(1, b.publishedCount);
        System.assertEquals(
            2,
            b.draftCount,
            'Draft + Needs Review both count as drafts'
        );
        System.assertNotEquals(null, b.lastImportedAt);
        System.assertEquals('TEST-001', b.examCode);
    }

    @IsTest
    static void getBankDetailReturnsRecentQuestions() {
        Question_Bank__c b = [SELECT Id FROM Question_Bank__c LIMIT 1];
        Test.startTest();
        CertGameQuestionBankController.BankDetailDto d = CertGameQuestionBankController.getBankDetail(
            b.Id
        );
        Test.stopTest();
        System.assertEquals(3, d.bank.questionCount);
        System.assertEquals(3, d.recentQuestions.size());
    }

    @IsTest
    static void getBankDetailRejectsNullId() {
        try {
            CertGameQuestionBankController.getBankDetail(null);
            System.assert(false, 'expected exception');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }

    @IsTest
    static void getBankDetailRejectsMissingBank() {
        // Build a syntactically valid Question_Bank__c id from the actual key prefix,
        // padded out to 15 chars, that will not match any row.
        String prefix = Schema.SObjectType.Question_Bank__c.getKeyPrefix();
        Id fakeId = Id.valueOf(prefix + '000000000000');
        try {
            CertGameQuestionBankController.getBankDetail(fakeId);
            System.assert(false, 'expected exception');
        } catch (Exception e) {
            System.assert(true);
        }
    }

    @IsTest
    static void loadSamplesCatalogReturnsSamples() {
        Test.startTest();
        CertGameQuestionBankController.SamplesCatalog cat = CertGameQuestionBankController.loadSamplesCatalog();
        Test.stopTest();
        System.assertNotEquals(null, cat);
        System.assertNotEquals(null, cat.samples);
        // The static resource ships with 2 samples; verify we got at least one back.
        System.assert(
            cat.samples.size() >= 1,
            'expected at least one sample in catalog'
        );
        System.assertNotEquals(null, cat.samples[0].key);
        System.assert(cat.samples[0].questionCount > 0);
    }

    @IsTest
    static void loadSampleJsonReturnsPack() {
        Test.startTest();
        String json = CertGameQuestionBankController.loadSampleJson(
            'lwc-basics'
        );
        Test.stopTest();
        System.assertNotEquals(null, json);
        System.assert(json.contains('"exam"'));
        System.assert(json.contains('"questions"'));
    }

    @IsTest
    static void loadSampleJsonUnknownKeyThrows() {
        try {
            CertGameQuestionBankController.loadSampleJson('no-such-sample');
            System.assert(false, 'expected exception');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }

    @IsTest
    static void loadSampleJsonBlankKeyThrows() {
        try {
            CertGameQuestionBankController.loadSampleJson(null);
            System.assert(false, 'expected exception');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }

    @IsTest
    static void validateJsonReturnsResult() {
        String good = '{"exam":{"name":"X","code":"X1","vendor":"V"},"questionBank":{"name":"B","version":"1","sourceType":"Manual","status":"Draft","externalId":"BX"},"questions":[{"externalId":"Q1","domain":"D","difficulty":"Beginner","questionType":"Single Select","question":"q?","choices":[{"label":"A","text":"a","isCorrect":true,"explanation":"e"},{"label":"B","text":"b","isCorrect":false,"explanation":"e"},{"label":"C","text":"c","isCorrect":false,"explanation":"e"}],"explanation":"e","citations":[{"title":"T","url":"https://x","sourceType":"Salesforce Help","relevanceNote":"n"}]}]}';
        Test.startTest();
        CertGameQuestionBankController.ValidationDto v = CertGameQuestionBankController.validateJson(
            good
        );
        Test.stopTest();
        System.assertEquals(true, v.valid, String.join(v.errors, '; '));
        System.assertEquals(1, v.questionCount);
    }

    @IsTest
    static void validateJsonReturnsErrorsForGarbage() {
        Test.startTest();
        CertGameQuestionBankController.ValidationDto v = CertGameQuestionBankController.validateJson(
            'not json'
        );
        Test.stopTest();
        System.assertEquals(false, v.valid);
        System.assert(!v.errors.isEmpty());
    }

    @IsTest
    static void importPackDelegatesToService() {
        String good = '{"exam":{"name":"Imp Exam","code":"IMP-001","vendor":"V"},"questionBank":{"name":"ImpBank","version":"1","sourceType":"Manual","status":"Draft","externalId":"BIMP-1"},"questions":[{"externalId":"IMP-Q1","domain":"D","difficulty":"Beginner","questionType":"Single Select","question":"q?","choices":[{"label":"A","text":"a","isCorrect":true,"explanation":"e"},{"label":"B","text":"b","isCorrect":false,"explanation":"e"},{"label":"C","text":"c","isCorrect":false,"explanation":"e"}],"explanation":"e","citations":[{"title":"T","url":"https://x","sourceType":"Salesforce Help","relevanceNote":"n"}]}]}';
        Test.startTest();
        CertGameImportService.ImportResult r = CertGameQuestionBankController.importPack(
            good
        );
        Test.stopTest();
        System.assertEquals(true, r.success, String.join(r.errors, '; '));
        System.assert(r.questionsCreated >= 1);
    }

    @IsTest
    static void startGenerationJobCreatesRecord() {
        Certification_Exam__c e = [
            SELECT Id
            FROM Certification_Exam__c
            LIMIT 1
        ];
        Test.startTest();
        CertGameQuestionBankController.GenerationKickoffDto k = CertGameQuestionBankController.startGenerationJob(
            e.Id,
            'OpenAI',
            5,
            'focus on basics'
        );
        Test.stopTest();
        System.assertNotEquals(null, k.jobId);
        System.assertEquals('Queued', k.status);
        Question_Generation_Job__c j = [
            SELECT Provider__c, Requested_Question_Count__c, Status__c
            FROM Question_Generation_Job__c
            WHERE Id = :k.jobId
        ];
        System.assertEquals('OpenAI', j.Provider__c);
        System.assertEquals(5, j.Requested_Question_Count__c);
    }

    @IsTest
    static void startGenerationJobRejectsNullExam() {
        try {
            CertGameQuestionBankController.startGenerationJob(
                null,
                'OpenAI',
                5,
                null
            );
            System.assert(false, 'expected exception');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }

    @IsTest
    static void startGenerationJobDefaultsProviderAndCount() {
        Certification_Exam__c e = [
            SELECT Id
            FROM Certification_Exam__c
            LIMIT 1
        ];
        Test.startTest();
        CertGameQuestionBankController.GenerationKickoffDto k = CertGameQuestionBankController.startGenerationJob(
            e.Id,
            null,
            null,
            null
        );
        Test.stopTest();
        Question_Generation_Job__c j = [
            SELECT Provider__c, Requested_Question_Count__c
            FROM Question_Generation_Job__c
            WHERE Id = :k.jobId
        ];
        System.assertEquals('OpenAI', j.Provider__c);
        System.assertEquals(5, j.Requested_Question_Count__c);
    }

    @IsTest
    static void listExamsReturnsActive() {
        Test.startTest();
        List<Map<String, Object>> exams = CertGameQuestionBankController.listExams();
        Test.stopTest();
        System.assert(!exams.isEmpty());
        System.assertEquals(
            'TEST-001 — Test Exam',
            (String) exams[0].get('label')
        );
    }
}