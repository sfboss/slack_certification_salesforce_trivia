@IsTest
private class CertGameGenerationJobController_Test {
    @TestSetup
    static void setup() {
        Certification_Exam__c exam = new Certification_Exam__c(
            Name = 'Gen Test Exam',
            Certification_Code__c = 'GEN-001',
            Active__c = true
        );
        insert exam;

        Exam_Domain__c d1 = new Exam_Domain__c(
            Certification_Exam__c = exam.Id,
            Name = 'Setup',
            Domain_Order__c = 1,
            Weight_Percent__c = 40
        );
        Exam_Domain__c d2 = new Exam_Domain__c(
            Certification_Exam__c = exam.Id,
            Name = 'Security',
            Domain_Order__c = 2,
            Weight_Percent__c = 30
        );
        insert new List<Exam_Domain__c>{ d1, d2 };

        // Seed a couple of completed jobs for the list tests
        Question_Generation_Job__c j1 = new Question_Generation_Job__c(
            Certification_Exam__c = exam.Id,
            Provider__c = 'OpenAI',
            Requested_Question_Count__c = 5,
            Generated_Question_Count__c = 5,
            Status__c = 'Completed',
            Token_Cost_USD__c = 0.05,
            Difficulty_Focus__c = 'Mixed',
            Domain_Focus__c = 'Setup, Security',
            Output_JSON__c = '{"exam":{"code":"GEN-001"},"questions":[]}'
        );
        Question_Generation_Job__c j2 = new Question_Generation_Job__c(
            Certification_Exam__c = exam.Id,
            Provider__c = 'OpenAI',
            Requested_Question_Count__c = 10,
            Status__c = 'Failed',
            Error_Message__c = 'timeout',
            Difficulty_Focus__c = 'Advanced'
        );
        insert new List<Question_Generation_Job__c>{ j1, j2 };
    }

    @IsTest
    static void listJobsSummary() {
        Test.startTest();
        CertGameGenerationJobController.JobsSummary s = CertGameGenerationJobController.listJobs(
            50
        );
        Test.stopTest();
        System.assertEquals(2, s.totalJobs);
        System.assertEquals(1, s.completedJobs);
        System.assertEquals(1, s.failedJobs);
        System.assertEquals(0, s.runningJobs);
        System.assertEquals(5, s.questionsGenerated);
        System.assert(s.tokenCostMtd >= 0.05);
    }

    @IsTest
    static void listJobsHandlesNullCap() {
        Test.startTest();
        CertGameGenerationJobController.JobsSummary s = CertGameGenerationJobController.listJobs(
            null
        );
        Test.stopTest();
        System.assertEquals(2, s.totalJobs);
    }

    @IsTest
    static void getJobDetailReturnsOutput() {
        Question_Generation_Job__c j = [
            SELECT Id
            FROM Question_Generation_Job__c
            WHERE Status__c = 'Completed'
            LIMIT 1
        ];
        Test.startTest();
        CertGameGenerationJobController.JobDetailDto d = CertGameGenerationJobController.getJobDetail(
            j.Id
        );
        Test.stopTest();
        System.assertEquals('Completed', d.job.status);
        System.assert(d.outputJson != null && d.outputJson.contains('GEN-001'));
        System.assert(d.outputJsonLength > 0);
    }

    @IsTest
    static void getJobDetailRejectsNull() {
        try {
            CertGameGenerationJobController.getJobDetail(null);
            System.assert(false, 'should have thrown');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }

    @IsTest
    static void listExamDomainsByExam() {
        Certification_Exam__c e = [
            SELECT Id
            FROM Certification_Exam__c
            LIMIT 1
        ];
        Test.startTest();
        List<CertGameGenerationJobController.DomainDto> domains = CertGameGenerationJobController.listExamDomains(
            e.Id
        );
        Test.stopTest();
        System.assertEquals(2, domains.size());
        // First domain by Domain_Order__c ASC should be Setup (Order=1)
        System.assertEquals('Setup', domains[0].value);
        System.assert(domains[0].label.contains('40'));
    }

    @IsTest
    static void listExamDomainsNullReturnsEmpty() {
        Test.startTest();
        List<CertGameGenerationJobController.DomainDto> domains = CertGameGenerationJobController.listExamDomains(
            null
        );
        Test.stopTest();
        System.assertEquals(0, domains.size());
    }

    @IsTest
    static void startJobCreatesRecord() {
        Certification_Exam__c e = [
            SELECT Id
            FROM Certification_Exam__c
            LIMIT 1
        ];
        CertGameGenerationJobController.StartJobInput input = new CertGameGenerationJobController.StartJobInput();
        input.examId = e.Id;
        input.provider = 'OpenAI';
        input.questionCount = 7;
        input.difficulty = 'Intermediate';
        input.domains = new List<String>{ 'Setup', 'Security' };
        input.promptNotes = 'focus on edge cases';

        Test.startTest();
        CertGameGenerationJobController.KickoffDto k = CertGameGenerationJobController.startJob(
            input
        );
        Test.stopTest();

        System.assertNotEquals(null, k.jobId);
        System.assertEquals('Queued', k.status);
        Question_Generation_Job__c saved = [
            SELECT
                Provider__c,
                Requested_Question_Count__c,
                Difficulty_Focus__c,
                Domain_Focus__c,
                Prompt_Text__c
            FROM Question_Generation_Job__c
            WHERE Id = :k.jobId
        ];
        System.assertEquals('OpenAI', saved.Provider__c);
        System.assertEquals(7, saved.Requested_Question_Count__c);
        System.assertEquals('Intermediate', saved.Difficulty_Focus__c);
        System.assertEquals('Setup, Security', saved.Domain_Focus__c);
        System.assertEquals('focus on edge cases', saved.Prompt_Text__c);
    }

    @IsTest
    static void startJobAppliesDefaults() {
        Certification_Exam__c e = [
            SELECT Id
            FROM Certification_Exam__c
            LIMIT 1
        ];
        CertGameGenerationJobController.StartJobInput input = new CertGameGenerationJobController.StartJobInput();
        input.examId = e.Id;
        // Leave everything else null

        Test.startTest();
        CertGameGenerationJobController.KickoffDto k = CertGameGenerationJobController.startJob(
            input
        );
        Test.stopTest();

        Question_Generation_Job__c saved = [
            SELECT
                Provider__c,
                Requested_Question_Count__c,
                Difficulty_Focus__c,
                Domain_Focus__c
            FROM Question_Generation_Job__c
            WHERE Id = :k.jobId
        ];
        System.assertEquals('OpenAI', saved.Provider__c);
        System.assertEquals(5, saved.Requested_Question_Count__c);
        System.assertEquals('Mixed', saved.Difficulty_Focus__c);
        System.assertEquals(null, saved.Domain_Focus__c);
    }

    @IsTest
    static void startJobRejectsNullInput() {
        try {
            CertGameGenerationJobController.startJob(null);
            System.assert(false, 'should have thrown');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }

    @IsTest
    static void startJobRejectsMissingExam() {
        CertGameGenerationJobController.StartJobInput input = new CertGameGenerationJobController.StartJobInput();
        try {
            CertGameGenerationJobController.startJob(input);
            System.assert(false, 'should have thrown');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }

    @IsTest
    static void startJobCapsCountAt25() {
        Certification_Exam__c e = [
            SELECT Id
            FROM Certification_Exam__c
            LIMIT 1
        ];
        CertGameGenerationJobController.StartJobInput input = new CertGameGenerationJobController.StartJobInput();
        input.examId = e.Id;
        input.questionCount = 9999;

        Test.startTest();
        CertGameGenerationJobController.KickoffDto k = CertGameGenerationJobController.startJob(
            input
        );
        Test.stopTest();

        Question_Generation_Job__c saved = [
            SELECT Requested_Question_Count__c
            FROM Question_Generation_Job__c
            WHERE Id = :k.jobId
        ];
        System.assertEquals(25, saved.Requested_Question_Count__c);
    }

    @IsTest
    static void rerunJobClonesParameters() {
        Question_Generation_Job__c src = [
            SELECT Id
            FROM Question_Generation_Job__c
            WHERE Status__c = 'Completed'
            LIMIT 1
        ];
        Test.startTest();
        CertGameGenerationJobController.KickoffDto k = CertGameGenerationJobController.rerunJob(
            src.Id
        );
        Test.stopTest();

        Question_Generation_Job__c cloned = [
            SELECT
                Provider__c,
                Requested_Question_Count__c,
                Difficulty_Focus__c,
                Domain_Focus__c
            FROM Question_Generation_Job__c
            WHERE Id = :k.jobId
        ];
        System.assertEquals('OpenAI', cloned.Provider__c);
        System.assertEquals(5, cloned.Requested_Question_Count__c);
        System.assertEquals('Mixed', cloned.Difficulty_Focus__c);
        System.assertEquals('Setup, Security', cloned.Domain_Focus__c);
    }

    @IsTest
    static void rerunJobRejectsNullOrMissing() {
        try {
            CertGameGenerationJobController.rerunJob(null);
            System.assert(false, 'expected exception');
        } catch (AuraHandledException e) {
            System.assert(true);
        }

        Id fakeId = Id.valueOf(
            Schema.SObjectType.Question_Generation_Job__c.getKeyPrefix() +
            '000000000000'
        );
        try {
            CertGameGenerationJobController.rerunJob(fakeId);
            System.assert(false, 'expected exception');
        } catch (Exception e) {
            System.assert(true);
        }
    }
}