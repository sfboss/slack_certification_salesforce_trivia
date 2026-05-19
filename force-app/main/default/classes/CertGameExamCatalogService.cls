/**
 * Lists certification exams visible to the workspace, with question counts per status.
 * Used by `/certgame games` and App Home.
 */
public with sharing class CertGameExamCatalogService {

    public class ExamSummary {
        public Id examId;
        public String code;
        public String name;
        public Boolean active;
        public Integer published;
        public Integer reviewed;
        public Integer draft;
    }

    public static String renderForSlack(String slackTeamId) {
        List<ExamSummary> rows = new Reader().summarize();
        return CertGameSlackRenderService.gamesList(rows);
    }

    public static List<ExamSummary> summarize() {
        return new Reader().summarize();
    }

    private without sharing class Reader {
        public List<ExamSummary> summarize() {
            Map<Id, ExamSummary> byId = new Map<Id, ExamSummary>();
            for (Certification_Exam__c e : [
                SELECT Id, Name, Certification_Code__c, Active__c
                FROM Certification_Exam__c ORDER BY Active__c DESC, Name LIMIT 100
            ]) {
                ExamSummary s = new ExamSummary();
                s.examId = e.Id;
                s.code = e.Certification_Code__c;
                s.name = e.Name;
                s.active = e.Active__c;
                s.published = 0;
                s.reviewed = 0;
                s.draft = 0;
                byId.put(e.Id, s);
            }
            if (byId.isEmpty()) return new List<ExamSummary>();
            for (AggregateResult ar : [
                SELECT Certification_Exam__c examId, Status__c status, COUNT(Id) c
                FROM Trivia_Question__c
                WHERE Certification_Exam__c IN :byId.keySet()
                GROUP BY Certification_Exam__c, Status__c
            ]) {
                Id eid = (Id) ar.get('examId');
                String st = (String) ar.get('status');
                Integer cnt = ((Decimal) ar.get('c')).intValue();
                ExamSummary s = byId.get(eid);
                if (s == null) continue;
                if (st == 'Published') s.published = cnt;
                else if (st == 'Reviewed') s.reviewed = cnt;
                else if (st == 'Draft') s.draft = cnt;
            }
            return byId.values();
        }
    }
}