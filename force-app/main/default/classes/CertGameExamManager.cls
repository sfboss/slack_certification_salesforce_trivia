/**
 * Admin utility for managing Certification_Exam__c records and their question banks.
 * Used by bulk-import scripts and ad-hoc admin tasks.
 *
 * All mutations honor sharing of the calling user; reads run in a without-sharing
 * inner class so import scripts running as the Integration User can still list exams
 * created by other admins.
 */
public with sharing class CertGameExamManager {

    public class ExamStats {
        @AuraEnabled public Id examId;
        @AuraEnabled public String code;
        @AuraEnabled public String name;
        @AuraEnabled public Boolean active;
        @AuraEnabled public Integer published;
        @AuraEnabled public Integer reviewed;
        @AuraEnabled public Integer draft;
        @AuraEnabled public Integer retired;
        @AuraEnabled public Integer total;
    }

    public class ManagerException extends Exception {}

    @AuraEnabled(cacheable=false)
    public static List<ExamStats> listAll() {
        return new Reader().listAll();
    }

    @AuraEnabled
    public static Integer setActive(String examCode, Boolean active) {
        if (String.isBlank(examCode)) throw new ManagerException('examCode required');
        List<Certification_Exam__c> rows = [
            SELECT Id, Active__c FROM Certification_Exam__c
            WHERE Certification_Code__c = :examCode LIMIT 1
        ];
        if (rows.isEmpty()) return 0;
        rows[0].Active__c = active;
        update rows;
        AuditLogger.log(active ? 'EXAM_ACTIVATED' : 'EXAM_DEACTIVATED',
            'Certification_Exam__c', rows[0].Id, null, new Map<String, Object>{'examCode' => examCode, 'active' => active});
        return 1;
    }

    /**
     * Promote every Draft or Reviewed question for the given exam to Published.
     * Returns the number of rows updated. Pass null examCode to publish ALL exams.
     */
    @AuraEnabled
    public static Integer publishAll(String examCode) {
        List<Trivia_Question__c> qs;
        if (String.isBlank(examCode)) {
            qs = [SELECT Id FROM Trivia_Question__c WHERE Status__c IN ('Draft', 'Reviewed')];
        } else {
            qs = [
                SELECT Id FROM Trivia_Question__c
                WHERE Status__c IN ('Draft', 'Reviewed')
                AND Certification_Exam__r.Certification_Code__c = :examCode
            ];
        }
        for (Trivia_Question__c q : qs) q.Status__c = 'Published';
        if (!qs.isEmpty()) {
            update qs;
            AuditLogger.log('EXAM_BULK_PUBLISH', 'Trivia_Question__c', null, null,
                new Map<String, Object>{'examCode' => examCode, 'count' => qs.size()});
        }
        return qs.size();
    }

    /**
     * Retire all published questions for an exam and deactivate the exam itself.
     */
    @AuraEnabled
    public static Integer retireExam(String examCode) {
        if (String.isBlank(examCode)) throw new ManagerException('examCode required');
        List<Trivia_Question__c> qs = [
            SELECT Id FROM Trivia_Question__c
            WHERE Status__c = 'Published'
            AND Certification_Exam__r.Certification_Code__c = :examCode
        ];
        for (Trivia_Question__c q : qs) q.Status__c = 'Retired';
        if (!qs.isEmpty()) update qs;
        setActive(examCode, false);
        AuditLogger.log('EXAM_RETIRED', 'Certification_Exam__c', null, null,
            new Map<String, Object>{'examCode' => examCode, 'questionsRetired' => qs.size()});
        return qs.size();
    }

    private without sharing class Reader {
        public List<ExamStats> listAll() {
            Map<Id, ExamStats> byId = new Map<Id, ExamStats>();
            for (Certification_Exam__c e : [
                SELECT Id, Name, Certification_Code__c, Active__c
                FROM Certification_Exam__c ORDER BY Active__c DESC, Name LIMIT 500
            ]) {
                ExamStats s = new ExamStats();
                s.examId = e.Id;
                s.code = e.Certification_Code__c;
                s.name = e.Name;
                s.active = e.Active__c;
                s.published = 0; s.reviewed = 0; s.draft = 0; s.retired = 0; s.total = 0;
                byId.put(e.Id, s);
            }
            if (byId.isEmpty()) return new List<ExamStats>();
            for (AggregateResult ar : [
                SELECT Certification_Exam__c eId, Status__c status, COUNT(Id) c
                FROM Trivia_Question__c
                WHERE Certification_Exam__c IN :byId.keySet()
                GROUP BY Certification_Exam__c, Status__c
            ]) {
                Id eid = (Id) ar.get('eId');
                String st = (String) ar.get('status');
                Integer cnt = ((Decimal) ar.get('c')).intValue();
                ExamStats s = byId.get(eid);
                if (s == null) continue;
                s.total += cnt;
                if (st == 'Published') s.published = cnt;
                else if (st == 'Reviewed') s.reviewed = cnt;
                else if (st == 'Draft') s.draft = cnt;
                else if (st == 'Retired') s.retired = cnt;
            }
            return byId.values();
        }
    }
}