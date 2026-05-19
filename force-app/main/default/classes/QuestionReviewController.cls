/**
 * AuraEnabled facade for the LWC review console.
 */
public with sharing class QuestionReviewController {

    public class DraftQuestionDto {
        @AuraEnabled public Id id;
        @AuraEnabled public String externalId;
        @AuraEnabled public String questionText;
        @AuraEnabled public String scenarioText;
        @AuraEnabled public String status;
        @AuraEnabled public String difficulty;
        @AuraEnabled public String questionType;
        @AuraEnabled public String examName;
        @AuraEnabled public String domainName;
        @AuraEnabled public List<ChoiceDto> choices;
        @AuraEnabled public List<CitationDto> citations;
    }
    public class ChoiceDto {
        @AuraEnabled public Id id;
        @AuraEnabled public String label;
        @AuraEnabled public String text;
        @AuraEnabled public Boolean isCorrect;
        @AuraEnabled public String explanation;
    }
    public class CitationDto {
        @AuraEnabled public Id id;
        @AuraEnabled public String title;
        @AuraEnabled public String url;
        @AuraEnabled public String sourceType;
    }

    @AuraEnabled(cacheable=true)
    public static List<DraftQuestionDto> listDrafts(String status, Integer maxRows) {
        Integer cap = (maxRows == null || maxRows <= 0) ? 50 : Math.min(maxRows, 200);
        String s = String.isBlank(status) ? 'Draft' : status;
        List<Trivia_Question__c> rows = [
            SELECT Id, External_Id__c, Question_Text__c, Scenario_Text__c, Status__c,
                   Difficulty__c, Question_Type__c,
                   Certification_Exam__r.Name, Exam_Domain__r.Name,
                   (SELECT Id, Choice_Label__c, Choice_Text__c, Is_Correct__c, Explanation__c, Sort_Order__c
                    FROM Choices__r ORDER BY Sort_Order__c),
                   (SELECT Id, Title__c, URL__c, Source_Type__c FROM Citations__r)
            FROM Trivia_Question__c
            WHERE Status__c = :s
            WITH SYSTEM_MODE
            ORDER BY CreatedDate DESC
            LIMIT :cap
        ];
        List<DraftQuestionDto> out = new List<DraftQuestionDto>();
        for (Trivia_Question__c q : rows) {
            DraftQuestionDto d = new DraftQuestionDto();
            d.id = q.Id; d.externalId = q.External_Id__c;
            d.questionText = q.Question_Text__c; d.scenarioText = q.Scenario_Text__c;
            d.status = q.Status__c; d.difficulty = q.Difficulty__c;
            d.questionType = q.Question_Type__c;
            d.examName = q.Certification_Exam__r != null ? q.Certification_Exam__r.Name : null;
            d.domainName = q.Exam_Domain__r != null ? q.Exam_Domain__r.Name : null;
            d.choices = new List<ChoiceDto>();
            for (Trivia_Answer_Choice__c c : q.Choices__r) {
                ChoiceDto cd = new ChoiceDto();
                cd.id = c.Id; cd.label = c.Choice_Label__c; cd.text = c.Choice_Text__c;
                cd.isCorrect = c.Is_Correct__c; cd.explanation = c.Explanation__c;
                d.choices.add(cd);
            }
            d.citations = new List<CitationDto>();
            for (Question_Citation__c c : q.Citations__r) {
                CitationDto cd = new CitationDto();
                cd.id = c.Id; cd.title = c.Title__c; cd.url = c.URL__c; cd.sourceType = c.Source_Type__c;
                d.citations.add(cd);
            }
            out.add(d);
        }
        return out;
    }

    @AuraEnabled
    public static Id setStatus(Id questionId, String newStatus) {
        if (questionId == null || String.isBlank(newStatus)) {
            throw new AuraHandledException('questionId and newStatus required');
        }
        Set<String> allowed = new Set<String>{'Draft', 'Reviewed', 'Published', 'Retired'};
        if (!allowed.contains(newStatus)) throw new AuraHandledException('Invalid status');
        Trivia_Question__c before = [
            SELECT Id, Status__c FROM Trivia_Question__c WHERE Id = :questionId WITH SYSTEM_MODE LIMIT 1
        ];
        Trivia_Question__c upd = new Trivia_Question__c(Id = questionId, Status__c = newStatus);
        if (newStatus == 'Published' || newStatus == 'Reviewed') {
            upd.Last_Verified_Date__c = System.today();
        }
        update as system upd;
        AuditLogger.log('Question.' + newStatus, 'Trivia_Question__c', questionId,
            new Map<String, Object>{'status' => before.Status__c},
            new Map<String, Object>{'status' => newStatus});
        return questionId;
    }

    @AuraEnabled
    public static CertGameImportService.ImportResult uploadPack(String jsonBody) {
        return CertGameImportService.importPack(jsonBody);
    }
}