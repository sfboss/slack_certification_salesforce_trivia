@isTest
private class CertGameExamManager_Test {

    @TestSetup
    static void setup() {
        Certification_Exam__c e1 = new Certification_Exam__c(
            Name = 'Test Alpha', Certification_Code__c = 'TST-A', Active__c = true
        );
        Certification_Exam__c e2 = new Certification_Exam__c(
            Name = 'Test Beta', Certification_Code__c = 'TST-B', Active__c = true
        );
        insert new List<Certification_Exam__c>{ e1, e2 };

        List<Trivia_Question__c> qs = new List<Trivia_Question__c>();
        for (Integer i = 0; i < 3; i++) {
            qs.add(new Trivia_Question__c(
                Certification_Exam__c = e1.Id,
                External_Id__c = 'TSTA-' + i,
                Question_Text__c = 'q' + i,
                Question_Type__c = 'Single Select',
                Difficulty__c = 'Beginner',
                Status__c = i == 0 ? 'Published' : 'Draft',
                Correct_Answer_Mode__c = 'Exact'
            ));
        }
        for (Integer i = 0; i < 2; i++) {
            qs.add(new Trivia_Question__c(
                Certification_Exam__c = e2.Id,
                External_Id__c = 'TSTB-' + i,
                Question_Text__c = 'q' + i,
                Question_Type__c = 'Single Select',
                Difficulty__c = 'Beginner',
                Status__c = 'Reviewed',
                Correct_Answer_Mode__c = 'Exact'
            ));
        }
        insert qs;
    }

    @isTest
    static void listAll_returns_counts_per_exam() {
        List<CertGameExamManager.ExamStats> rows = CertGameExamManager.listAll();
        System.assertEquals(2, rows.size(), 'two exams expected');
        Map<String, CertGameExamManager.ExamStats> byCode = new Map<String, CertGameExamManager.ExamStats>();
        for (CertGameExamManager.ExamStats s : rows) byCode.put(s.code, s);
        System.assertEquals(1, byCode.get('TST-A').published);
        System.assertEquals(2, byCode.get('TST-A').draft);
        System.assertEquals(3, byCode.get('TST-A').total);
        System.assertEquals(2, byCode.get('TST-B').reviewed);
    }

    @isTest
    static void setActive_toggles_flag() {
        Integer updated = CertGameExamManager.setActive('TST-A', false);
        System.assertEquals(1, updated);
        Certification_Exam__c e = [SELECT Active__c FROM Certification_Exam__c WHERE Certification_Code__c = 'TST-A'];
        System.assertEquals(false, e.Active__c);
    }

    @isTest
    static void publishAll_for_exam_promotes_draft_and_reviewed() {
        Integer n = CertGameExamManager.publishAll('TST-A');
        System.assertEquals(2, n, 'two Draft rows should publish');
        Integer pub = [SELECT COUNT() FROM Trivia_Question__c WHERE Certification_Exam__r.Certification_Code__c = 'TST-A' AND Status__c = 'Published'];
        System.assertEquals(3, pub);
    }

    @isTest
    static void publishAll_null_examCode_promotes_everything() {
        Integer n = CertGameExamManager.publishAll(null);
        System.assertEquals(4, n);
        Integer pub = [SELECT COUNT() FROM Trivia_Question__c WHERE Status__c = 'Published'];
        System.assertEquals(5, pub);
    }

    @isTest
    static void retireExam_retires_published_and_deactivates() {
        CertGameExamManager.publishAll('TST-A');
        Integer r = CertGameExamManager.retireExam('TST-A');
        System.assert(r >= 3, 'expected published rows to be retired');
        Certification_Exam__c e = [SELECT Active__c FROM Certification_Exam__c WHERE Certification_Code__c = 'TST-A'];
        System.assertEquals(false, e.Active__c);
    }

    @isTest
    static void setActive_blank_code_throws() {
        try {
            CertGameExamManager.setActive('', true);
            System.assert(false, 'should have thrown');
        } catch (CertGameExamManager.ManagerException e) {
            System.assert(e.getMessage().contains('required'));
        }
    }
}