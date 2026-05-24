/**
 * AuraEnabled facade for the Question Review console.
 *
 * Workflow:
 *   Draft / Needs Review  --(Save edits + Facts Verified)-->  Fact Verified
 *   Fact Verified         --(Publish, requires Fact_Check_Passed__c)--> Published
 *   any                   --(Needs Revision, requires notes)-->  Needs Revision
 *   any                   --(Retire)-->                           Retired
 */
public with sharing class QuestionReviewController {
    private static final Set<String> ALLOWED_STATUS = new Set<String>{
        'Draft',
        'Needs Review',
        'Needs Revision',
        'Reviewed',
        'Fact Verified',
        'Published',
        'Retired'
    };
    private static final Set<String> SORT_FIELDS = new Set<String>{
        'CreatedDate',
        'Difficulty__c',
        'Exam_Domain__r.Name'
    };

    // -------------------- DTOs --------------------

    public class ReviewQuestionDto {
        @AuraEnabled
        public Id id;
        @AuraEnabled
        public String externalId;
        @AuraEnabled
        public String questionText;
        @AuraEnabled
        public String scenarioText;
        @AuraEnabled
        public String explanation;
        @AuraEnabled
        public String status;
        @AuraEnabled
        public String difficulty;
        @AuraEnabled
        public String questionType;
        @AuraEnabled
        public String tags;
        @AuraEnabled
        public String reviewerNotes;
        @AuraEnabled
        public Id examId;
        @AuraEnabled
        public String examName;
        @AuraEnabled
        public Id domainId;
        @AuraEnabled
        public String domainName;
        @AuraEnabled
        public Boolean factCheckPassed;
        @AuraEnabled
        public String factCheckedByName;
        @AuraEnabled
        public Datetime factCheckedDate;
        @AuraEnabled
        public String publishedByName;
        @AuraEnabled
        public Datetime publishedDate;
        @AuraEnabled
        public Datetime createdDate;
        @AuraEnabled
        public String createdByName;
        @AuraEnabled
        public List<ChoiceDto> choices;
        @AuraEnabled
        public List<CitationDto> citations;
    }

    public class ChoiceDto {
        @AuraEnabled
        public Id id;
        @AuraEnabled
        public String label;
        @AuraEnabled
        public String text;
        @AuraEnabled
        public Boolean isCorrect;
        @AuraEnabled
        public String explanation;
        @AuraEnabled
        public Integer sortOrder;
    }

    public class CitationDto {
        @AuraEnabled
        public Id id;
        @AuraEnabled
        public String title;
        @AuraEnabled
        public String url;
        @AuraEnabled
        public String sourceType;
        @AuraEnabled
        public Boolean brokenLink;
        @AuraEnabled
        public Datetime lastVerifiedDate;
    }

    public class QueueResult {
        @AuraEnabled
        public Integer total;
        @AuraEnabled
        public List<ReviewQuestionDto> questions;
    }

    public class ReviewPayload {
        @AuraEnabled
        public Id id;
        @AuraEnabled
        public String questionText;
        @AuraEnabled
        public String scenarioText;
        @AuraEnabled
        public String explanation;
        @AuraEnabled
        public String difficulty;
        @AuraEnabled
        public String questionType;
        @AuraEnabled
        public String tags;
        @AuraEnabled
        public String reviewerNotes;
        @AuraEnabled
        public List<ChoiceDto> choices;
        @AuraEnabled
        public List<CitationDto> citations;
    }

    // -------------------- Queries --------------------

    @AuraEnabled(cacheable=true)
    public static QueueResult fetchQueue(
        String status,
        String sortBy,
        Integer maxRows
    ) {
        Integer cap = (maxRows == null ||
            maxRows <= 0)
            ? 50
            : Math.min(maxRows, 200);
        String s = String.isBlank(status) ? 'Needs Review' : status;
        if (!ALLOWED_STATUS.contains(s)) {
            throw new AuraHandledException('Invalid status filter: ' + s);
        }
        String orderField = (String.isBlank(sortBy) ||
            !SORT_FIELDS.contains(sortBy))
            ? 'CreatedDate'
            : sortBy;
        String orderClause =
            orderField +
            (orderField == 'CreatedDate' ? ' ASC' : ' ASC NULLS LAST');

        String soql =
            'SELECT Id, External_Id__c, Question_Text__c, Scenario_Text__c, Explanation__c, Status__c, ' +
            '       Difficulty__c, Question_Type__c, Tags__c, Reviewer_Notes__c, ' +
            '       Certification_Exam__c, Certification_Exam__r.Name, ' +
            '       Exam_Domain__c, Exam_Domain__r.Name, ' +
            '       Fact_Check_Passed__c, Fact_Checked_By__r.Name, Fact_Checked_Date__c, ' +
            '       Published_By__r.Name, Published_Date__c, ' +
            '       CreatedDate, CreatedBy.Name, ' +
            '       (SELECT Id, Choice_Label__c, Choice_Text__c, Is_Correct__c, Explanation__c, Sort_Order__c ' +
            '        FROM Choices__r ORDER BY Sort_Order__c), ' +
            '       (SELECT Id, Title__c, URL__c, Source_Type__c, Broken_Link__c, Last_Verified_Date__c ' +
            '        FROM Citations__r) ' +
            'FROM Trivia_Question__c ' +
            'WHERE Status__c = :s ' +
            'WITH SYSTEM_MODE ' +
            'ORDER BY ' +
            orderClause +
            ' ' +
            'LIMIT :cap';

        List<Trivia_Question__c> rows = Database.query(soql);

        Integer total = [
            SELECT COUNT()
            FROM Trivia_Question__c
            WHERE Status__c = :s
            WITH SYSTEM_MODE
        ];

        QueueResult qr = new QueueResult();
        qr.total = total;
        qr.questions = new List<ReviewQuestionDto>();
        for (Trivia_Question__c q : rows) {
            qr.questions.add(toDto(q));
        }
        return qr;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Integer> getStatusCounts() {
        Map<String, Integer> out = new Map<String, Integer>();
        for (String st : ALLOWED_STATUS)
            out.put(st, 0);
        for (AggregateResult ar : [
            SELECT Status__c st, COUNT(Id) c
            FROM Trivia_Question__c
            WITH SYSTEM_MODE
            GROUP BY Status__c
        ]) {
            out.put((String) ar.get('st'), (Integer) ar.get('c'));
        }
        return out;
    }

    // -------------------- Mutations --------------------

    @AuraEnabled
    public static Id saveEdits(ReviewPayload payload) {
        if (payload == null || payload.id == null)
            throw new AuraHandledException('Question id required');
        applyEdits(payload);
        AuditLogger.log(
            'Question.SaveEdits',
            'Trivia_Question__c',
            payload.id,
            null,
            new Map<String, Object>{ 'editor' => UserInfo.getUserId() }
        );
        return payload.id;
    }

    @AuraEnabled
    public static Id markFactsVerified(ReviewPayload payload) {
        if (payload == null || payload.id == null)
            throw new AuraHandledException('Question id required');
        applyEdits(payload);
        Trivia_Question__c upd = new Trivia_Question__c(
            Id = payload.id,
            Fact_Check_Passed__c = true,
            Fact_Checked_By__c = UserInfo.getUserId(),
            Fact_Checked_Date__c = System.now(),
            Status__c = 'Fact Verified'
        );
        update as system upd;
        AuditLogger.log(
            'Question.FactsVerified',
            'Trivia_Question__c',
            payload.id,
            null,
            new Map<String, Object>{ 'status' => 'Fact Verified' }
        );
        return payload.id;
    }

    @AuraEnabled
    public static Id clearFactsVerified(Id questionId) {
        if (questionId == null)
            throw new AuraHandledException('Question id required');
        Trivia_Question__c cur = [
            SELECT Id, Status__c
            FROM Trivia_Question__c
            WHERE Id = :questionId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        Trivia_Question__c upd = new Trivia_Question__c(
            Id = questionId,
            Fact_Check_Passed__c = false,
            Fact_Checked_By__c = null,
            Fact_Checked_Date__c = null
        );
        if (cur.Status__c == 'Fact Verified')
            upd.Status__c = 'Needs Review';
        update as system upd;
        AuditLogger.log(
            'Question.ClearFactsVerified',
            'Trivia_Question__c',
            questionId,
            null,
            null
        );
        return questionId;
    }

    @AuraEnabled
    public static Id publish(ReviewPayload payload) {
        if (payload == null || payload.id == null)
            throw new AuraHandledException('Question id required');
        applyEdits(payload);
        Trivia_Question__c q = [
            SELECT Id, Status__c, Fact_Check_Passed__c
            FROM Trivia_Question__c
            WHERE Id = :payload.id
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (q.Fact_Check_Passed__c != true) {
            throw new AuraHandledException(
                'Cannot publish: Fact Check has not been confirmed.'
            );
        }
        Trivia_Question__c upd = new Trivia_Question__c(
            Id = payload.id,
            Status__c = 'Published',
            Published_By__c = UserInfo.getUserId(),
            Published_Date__c = System.now(),
            Last_Verified_Date__c = System.today()
        );
        update as system upd;
        AuditLogger.log(
            'Question.Published',
            'Trivia_Question__c',
            payload.id,
            new Map<String, Object>{ 'status' => q.Status__c },
            new Map<String, Object>{ 'status' => 'Published' }
        );
        return payload.id;
    }

    @AuraEnabled
    public static Id needsRevision(ReviewPayload payload) {
        if (payload == null || payload.id == null)
            throw new AuraHandledException('Question id required');
        if (String.isBlank(payload.reviewerNotes)) {
            throw new AuraHandledException(
                'Reviewer notes are required when sending for revision.'
            );
        }
        applyEdits(payload);
        Trivia_Question__c upd = new Trivia_Question__c(
            Id = payload.id,
            Status__c = 'Needs Revision',
            Fact_Check_Passed__c = false,
            Fact_Checked_By__c = null,
            Fact_Checked_Date__c = null
        );
        update as system upd;
        AuditLogger.log(
            'Question.NeedsRevision',
            'Trivia_Question__c',
            payload.id,
            null,
            new Map<String, Object>{ 'notes' => payload.reviewerNotes }
        );
        return payload.id;
    }

    @AuraEnabled
    public static Id retire(Id questionId) {
        if (questionId == null)
            throw new AuraHandledException('Question id required');
        Trivia_Question__c before = [
            SELECT Id, Status__c
            FROM Trivia_Question__c
            WHERE Id = :questionId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        Trivia_Question__c upd = new Trivia_Question__c(
            Id = questionId,
            Status__c = 'Retired'
        );
        update as system upd;
        AuditLogger.log(
            'Question.Retired',
            'Trivia_Question__c',
            questionId,
            new Map<String, Object>{ 'status' => before.Status__c },
            new Map<String, Object>{ 'status' => 'Retired' }
        );
        return questionId;
    }

    // -------------------- Citation link verification --------------------

    @AuraEnabled
    public static CitationDto verifyCitation(Id citationId) {
        if (citationId == null)
            throw new AuraHandledException('Citation id required');
        Question_Citation__c c = [
            SELECT
                Id,
                URL__c,
                Title__c,
                Source_Type__c,
                Broken_Link__c,
                Last_Verified_Date__c
            FROM Question_Citation__c
            WHERE Id = :citationId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (String.isBlank(c.URL__c))
            throw new AuraHandledException('Citation has no URL.');

        Boolean reachable = CitationLinkVerifier.check(c.URL__c);
        c.Broken_Link__c = !reachable;
        c.Last_Verified_Date__c = System.today();
        update as system c;

        CitationDto d = new CitationDto();
        d.id = c.Id;
        d.title = c.Title__c;
        d.url = c.URL__c;
        d.sourceType = c.Source_Type__c;
        d.brokenLink = c.Broken_Link__c;
        d.lastVerifiedDate = c.Last_Verified_Date__c;
        return d;
    }

    // -------------------- Legacy / passthrough --------------------

    @AuraEnabled
    public static Id setStatus(Id questionId, String newStatus) {
        if (questionId == null || String.isBlank(newStatus)) {
            throw new AuraHandledException('questionId and newStatus required');
        }
        if (!ALLOWED_STATUS.contains(newStatus))
            throw new AuraHandledException('Invalid status');
        Trivia_Question__c before = [
            SELECT Id, Status__c
            FROM Trivia_Question__c
            WHERE Id = :questionId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        Trivia_Question__c upd = new Trivia_Question__c(
            Id = questionId,
            Status__c = newStatus
        );
        if (newStatus == 'Published' || newStatus == 'Reviewed') {
            upd.Last_Verified_Date__c = System.today();
        }
        update as system upd;
        AuditLogger.log(
            'Question.' + newStatus,
            'Trivia_Question__c',
            questionId,
            new Map<String, Object>{ 'status' => before.Status__c },
            new Map<String, Object>{ 'status' => newStatus }
        );
        return questionId;
    }

    @AuraEnabled
    public static CertGameImportService.ImportResult uploadPack(
        String jsonBody
    ) {
        return CertGameImportService.importPack(jsonBody);
    }

    /** Back-compat shape for any callers still on the old list view. */
    @AuraEnabled(cacheable=true)
    public static List<ReviewQuestionDto> listDrafts(
        String status,
        Integer maxRows
    ) {
        return fetchQueue(status, 'CreatedDate', maxRows).questions;
    }

    // -------------------- Helpers --------------------

    private static void applyEdits(ReviewPayload p) {
        Trivia_Question__c q = new Trivia_Question__c(Id = p.id);
        if (p.questionText != null)
            q.Question_Text__c = p.questionText;
        if (p.scenarioText != null)
            q.Scenario_Text__c = p.scenarioText;
        if (p.explanation != null)
            q.Explanation__c = p.explanation;
        if (p.difficulty != null)
            q.Difficulty__c = p.difficulty;
        if (p.questionType != null)
            q.Question_Type__c = p.questionType;
        if (p.tags != null)
            q.Tags__c = p.tags;
        if (p.reviewerNotes != null)
            q.Reviewer_Notes__c = p.reviewerNotes;
        update as system q;

        if (p.choices != null && !p.choices.isEmpty()) {
            List<Trivia_Answer_Choice__c> upd = new List<Trivia_Answer_Choice__c>();
            for (ChoiceDto c : p.choices) {
                if (c.id == null)
                    continue;
                upd.add(
                    new Trivia_Answer_Choice__c(
                        Id = c.id,
                        Choice_Text__c = c.text,
                        Is_Correct__c = c.isCorrect == true,
                        Explanation__c = c.explanation
                    )
                );
            }
            if (!upd.isEmpty())
                update as system upd;
        }
    }

    private static ReviewQuestionDto toDto(Trivia_Question__c q) {
        ReviewQuestionDto d = new ReviewQuestionDto();
        d.id = q.Id;
        d.externalId = q.External_Id__c;
        d.questionText = q.Question_Text__c;
        d.scenarioText = q.Scenario_Text__c;
        d.explanation = q.Explanation__c;
        d.status = q.Status__c;
        d.difficulty = q.Difficulty__c;
        d.questionType = q.Question_Type__c;
        d.tags = q.Tags__c;
        d.reviewerNotes = q.Reviewer_Notes__c;
        d.examId = q.Certification_Exam__c;
        d.examName = q.Certification_Exam__r != null
            ? q.Certification_Exam__r.Name
            : null;
        d.domainId = q.Exam_Domain__c;
        d.domainName = q.Exam_Domain__r != null ? q.Exam_Domain__r.Name : null;
        d.factCheckPassed = q.Fact_Check_Passed__c;
        d.factCheckedByName = q.Fact_Checked_By__r != null
            ? q.Fact_Checked_By__r.Name
            : null;
        d.factCheckedDate = q.Fact_Checked_Date__c;
        d.publishedByName = q.Published_By__r != null
            ? q.Published_By__r.Name
            : null;
        d.publishedDate = q.Published_Date__c;
        d.createdDate = q.CreatedDate;
        d.createdByName = q.CreatedBy != null ? q.CreatedBy.Name : null;
        d.choices = new List<ChoiceDto>();
        for (Trivia_Answer_Choice__c c : q.Choices__r) {
            ChoiceDto cd = new ChoiceDto();
            cd.id = c.Id;
            cd.label = c.Choice_Label__c;
            cd.text = c.Choice_Text__c;
            cd.isCorrect = c.Is_Correct__c;
            cd.explanation = c.Explanation__c;
            cd.sortOrder = c.Sort_Order__c == null
                ? null
                : Integer.valueOf(c.Sort_Order__c);
            d.choices.add(cd);
        }
        d.citations = new List<CitationDto>();
        for (Question_Citation__c c : q.Citations__r) {
            CitationDto cd = new CitationDto();
            cd.id = c.Id;
            cd.title = c.Title__c;
            cd.url = c.URL__c;
            cd.sourceType = c.Source_Type__c;
            cd.brokenLink = c.Broken_Link__c;
            cd.lastVerifiedDate = c.Last_Verified_Date__c;
            d.citations.add(cd);
        }
        return d;
    }
}