@IsTest
private class CertGameExamWorkspaceController_Test {
    @TestSetup
    static void setup() {
        Certification_Exam__c admin201 = new Certification_Exam__c(
            Name = 'ADM-201 Admin',
            Certification_Code__c = 'ADM-201',
            Vendor__c = 'Salesforce',
            Track__c = 'Admin',
            Level__c = 'Entry',
            Cost__c = 200,
            Active__c = true
        );
        Certification_Exam__c pd1 = new Certification_Exam__c(
            Name = 'PD-I Developer',
            Certification_Code__c = 'PD-1',
            Vendor__c = 'Salesforce',
            Track__c = 'Developer',
            Level__c = 'Intermediate',
            Cost__c = 200,
            Active__c = true
        );
        insert new List<Certification_Exam__c>{ admin201, pd1 };

        Exam_Domain__c d1 = new Exam_Domain__c(
            Certification_Exam__c = admin201.Id,
            Name = 'Setup',
            Domain_Order__c = 1,
            Weight_Percent__c = 30
        );
        Exam_Domain__c d2 = new Exam_Domain__c(
            Certification_Exam__c = admin201.Id,
            Name = 'Security',
            Domain_Order__c = 2,
            Weight_Percent__c = 25
        );
        insert new List<Exam_Domain__c>{ d1, d2 };

        Question_Bank__c bank = new Question_Bank__c(
            Name = 'ADM-201 Bank',
            Certification_Exam__c = admin201.Id,
            Status__c = 'Draft',
            Source_Type__c = 'Manual',
            Version__c = '1.0',
            External_Id__c = 'BANK-ADM-201'
        );
        insert bank;

        List<Trivia_Question__c> qs = new List<Trivia_Question__c>{
            new Trivia_Question__c(
                External_Id__c = 'AQ1',
                Certification_Exam__c = admin201.Id,
                Question_Bank__c = bank.Id,
                Exam_Domain__c = d1.Id,
                Question_Text__c = 'q1',
                Difficulty__c = 'Beginner',
                Question_Type__c = 'Single Select',
                Status__c = 'Published'
            ),
            new Trivia_Question__c(
                External_Id__c = 'AQ2',
                Certification_Exam__c = admin201.Id,
                Question_Bank__c = bank.Id,
                Exam_Domain__c = d1.Id,
                Question_Text__c = 'q2',
                Difficulty__c = 'Beginner',
                Question_Type__c = 'Single Select',
                Status__c = 'Draft'
            ),
            new Trivia_Question__c(
                External_Id__c = 'AQ3',
                Certification_Exam__c = admin201.Id,
                Question_Bank__c = bank.Id,
                Exam_Domain__c = d2.Id,
                Question_Text__c = 'q3',
                Difficulty__c = 'Intermediate',
                Question_Type__c = 'Single Select',
                Status__c = 'Needs Review'
            )
        };
        insert qs;

        insert new Question_Generation_Job__c(
            Certification_Exam__c = admin201.Id,
            Provider__c = 'OpenAI',
            Status__c = 'Completed',
            Requested_Question_Count__c = 5,
            Generated_Question_Count__c = 5
        );
    }

    @IsTest
    static void listExamsRollups() {
        Test.startTest();
        CertGameExamWorkspaceController.ExamsSummary s = CertGameExamWorkspaceController.listExams();
        Test.stopTest();

        System.assertEquals(2, s.totalExams);
        System.assertEquals(2, s.activeExams);
        System.assertEquals(1, s.examsWithPublished);
        System.assertEquals(3, s.totalQuestions);
        System.assertEquals(1, s.totalPublishedQuestions);

        CertGameExamWorkspaceController.ExamRowDto adm = null;
        for (CertGameExamWorkspaceController.ExamRowDto r : s.exams) {
            if (r.code == 'ADM-201')
                adm = r;
        }
        System.assertNotEquals(null, adm);
        System.assertEquals(3, adm.questionCount);
        System.assertEquals(1, adm.publishedCount);
        System.assertEquals(
            2,
            adm.draftCount,
            'Draft + Needs Review count as drafts'
        );
        System.assertEquals(1, adm.bankCount);
        System.assertEquals(1, adm.jobCount);
        System.assertEquals(2, adm.domainCount);
    }

    @IsTest
    static void getExamDetailReturnsRollupsAndDomains() {
        Certification_Exam__c e = [
            SELECT Id
            FROM Certification_Exam__c
            WHERE Certification_Code__c = 'ADM-201'
            LIMIT 1
        ];
        Test.startTest();
        CertGameExamWorkspaceController.ExamDetailDto d = CertGameExamWorkspaceController.getExamDetail(
            e.Id
        );
        Test.stopTest();

        System.assertEquals('ADM-201', d.exam.code);
        System.assertEquals(3, d.exam.questionCount);
        System.assertEquals(2, d.domains.size());
        // 2 questions are in Setup domain
        Integer setupQs = 0;
        for (CertGameExamWorkspaceController.DomainRowDto dr : d.domains) {
            if (dr.name == 'Setup')
                setupQs = dr.questionCount;
        }
        System.assertEquals(2, setupQs);
        System.assertEquals(1, d.banks.size());
        System.assertEquals(1, d.jobs.size());
    }

    @IsTest
    static void getExamDetailRejectsNull() {
        try {
            CertGameExamWorkspaceController.getExamDetail(null);
            System.assert(false, 'expected exception');
        } catch (AuraHandledException ex) {
            System.assert(true);
        }
    }

    @IsTest
    static void getExamDetailMissingThrows() {
        Id fakeId = Id.valueOf(
            Schema.SObjectType.Certification_Exam__c.getKeyPrefix() +
            '000000000000'
        );
        try {
            CertGameExamWorkspaceController.getExamDetail(fakeId);
            System.assert(false, 'expected exception');
        } catch (Exception ex) {
            System.assert(true);
        }
    }

    @IsTest
    static void mintPracticeUrlWithExam() {
        Certification_Exam__c e = [
            SELECT Id
            FROM Certification_Exam__c
            LIMIT 1
        ];
        Test.startTest();
        CertGameExamWorkspaceController.PracticeUrlDto u = CertGameExamWorkspaceController.mintPracticeUrl(
            e.Id,
            15
        );
        Test.stopTest();
        System.assertEquals(15, u.questionCount);
        System.assert(u.url.contains('CertGameWeb'));
        System.assert(u.url.contains('n=15'));
        System.assert(u.url.contains('exam='));
    }

    @IsTest
    static void mintPracticeUrlRandomNoExam() {
        Test.startTest();
        CertGameExamWorkspaceController.PracticeUrlDto u = CertGameExamWorkspaceController.mintPracticeUrl(
            null,
            null
        );
        Test.stopTest();
        // Default count is 10 when null
        System.assertEquals(10, u.questionCount);
        System.assert(u.url.contains('n=10'));
        System.assert(!u.url.contains('exam='));
    }

    @IsTest
    static void mintPracticeUrlCapsAt60() {
        Test.startTest();
        CertGameExamWorkspaceController.PracticeUrlDto u = CertGameExamWorkspaceController.mintPracticeUrl(
            null,
            9999
        );
        Test.stopTest();
        System.assertEquals(60, u.questionCount);
    }

    @IsTest
    static void listExamsHandlesEmpty() {
        delete [SELECT Id FROM Trivia_Question__c];
        delete [SELECT Id FROM Question_Bank__c];
        delete [SELECT Id FROM Question_Generation_Job__c];
        delete [SELECT Id FROM Exam_Domain__c];
        delete [SELECT Id FROM Certification_Exam__c];
        Test.startTest();
        CertGameExamWorkspaceController.ExamsSummary s = CertGameExamWorkspaceController.listExams();
        Test.stopTest();
        System.assertEquals(0, s.totalExams);
        System.assertEquals(0, s.exams.size());
    }
}