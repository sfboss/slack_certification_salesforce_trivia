/**
 * AuraEnabled facade for the Exams Workspace LWC.
 *
 *   - listExams       : every Certification_Exam__c with question / bank / job rollups
 *   - getExamDetail   : full exam record + domain breakdown + recent banks + recent jobs
 *   - mintPracticeUrl : returns a mobile-friendly Site URL that pre-selects this exam in CertGameWeb
 *
 * Sharing: with sharing because all reads are admin-facing in Lightning. Mint URL uses Site.getBaseSecureUrl().
 */
public with sharing class CertGameExamWorkspaceController {

    // -------------------- DTOs --------------------

    public class ExamRowDto {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String code;
        @AuraEnabled public String vendor;
        @AuraEnabled public String track;
        @AuraEnabled public String level;
        @AuraEnabled public Decimal cost;
        @AuraEnabled public Boolean active;
        @AuraEnabled public Integer questionCount;
        @AuraEnabled public Integer publishedCount;
        @AuraEnabled public Integer draftCount;
        @AuraEnabled public Integer bankCount;
        @AuraEnabled public Integer jobCount;
        @AuraEnabled public Integer domainCount;
        @AuraEnabled public Datetime lastActivityAt;
    }

    public class ExamsSummary {
        @AuraEnabled public List<ExamRowDto> exams;
        @AuraEnabled public Integer totalExams;
        @AuraEnabled public Integer activeExams;
        @AuraEnabled public Integer examsWithPublished;
        @AuraEnabled public Integer totalQuestions;
        @AuraEnabled public Integer totalPublishedQuestions;
    }

    public class DomainRowDto {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public Decimal weightPercent;
        @AuraEnabled public Integer questionCount;
    }

    public class BankRowDto {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public String sourceType;
        @AuraEnabled public Datetime createdDate;
    }

    public class JobRowDto {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public String provider;
        @AuraEnabled public Integer generatedCount;
        @AuraEnabled public Datetime createdDate;
    }

    public class ExamDetailDto {
        @AuraEnabled public ExamRowDto exam;
        @AuraEnabled public List<DomainRowDto> domains;
        @AuraEnabled public List<BankRowDto> banks;
        @AuraEnabled public List<JobRowDto> jobs;
    }

    public class PracticeUrlDto {
        @AuraEnabled public String url;
        @AuraEnabled public Integer questionCount;
    }

    // -------------------- Reads --------------------

    @AuraEnabled(cacheable=true)
    public static ExamsSummary listExams() {
        List<Certification_Exam__c> exams = [
            SELECT Id, Name, Certification_Code__c, Vendor__c, Track__c, Level__c, Cost__c, Active__c
            FROM Certification_Exam__c
            WITH SYSTEM_MODE
            ORDER BY Active__c DESC NULLS LAST, Track__c NULLS LAST, Name
            LIMIT 500
        ];
        if (exams.isEmpty()) {
            ExamsSummary empty = new ExamsSummary();
            empty.exams = new List<ExamRowDto>();
            empty.totalExams = 0; empty.activeExams = 0; empty.examsWithPublished = 0;
            empty.totalQuestions = 0; empty.totalPublishedQuestions = 0;
            return empty;
        }

        Set<Id> examIds = new Set<Id>();
        for (Certification_Exam__c e : exams) examIds.add(e.Id);

        Map<Id, Integer> totalByExam = new Map<Id, Integer>();
        Map<Id, Integer> pubByExam = new Map<Id, Integer>();
        Map<Id, Integer> draftByExam = new Map<Id, Integer>();
        Map<Id, Datetime> lastByExam = new Map<Id, Datetime>();
        for (AggregateResult ar : [
            SELECT Certification_Exam__c eId, Status__c st, COUNT(Id) c, MAX(CreatedDate) lastAt
            FROM Trivia_Question__c
            WHERE Certification_Exam__c IN :examIds
            WITH SYSTEM_MODE
            GROUP BY Certification_Exam__c, Status__c
        ]) {
            Id eid = (Id) ar.get('eId');
            String st = (String) ar.get('st');
            Integer c = ((Decimal) ar.get('c')).intValue();
            Datetime la = (Datetime) ar.get('lastAt');
            totalByExam.put(eid, (totalByExam.containsKey(eid) ? totalByExam.get(eid) : 0) + c);
            if (st == 'Published') pubByExam.put(eid, (pubByExam.containsKey(eid) ? pubByExam.get(eid) : 0) + c);
            if (st == 'Draft' || st == 'Needs Review') {
                draftByExam.put(eid, (draftByExam.containsKey(eid) ? draftByExam.get(eid) : 0) + c);
            }
            if (la != null && (!lastByExam.containsKey(eid) || la > lastByExam.get(eid))) {
                lastByExam.put(eid, la);
            }
        }

        Map<Id, Integer> bankByExam = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Certification_Exam__c eId, COUNT(Id) c
            FROM Question_Bank__c WHERE Certification_Exam__c IN :examIds
            WITH SYSTEM_MODE GROUP BY Certification_Exam__c
        ]) {
            bankByExam.put((Id) ar.get('eId'), ((Decimal) ar.get('c')).intValue());
        }

        Map<Id, Integer> jobByExam = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Certification_Exam__c eId, COUNT(Id) c
            FROM Question_Generation_Job__c WHERE Certification_Exam__c IN :examIds
            WITH SYSTEM_MODE GROUP BY Certification_Exam__c
        ]) {
            jobByExam.put((Id) ar.get('eId'), ((Decimal) ar.get('c')).intValue());
        }

        Map<Id, Integer> domainByExam = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Certification_Exam__c eId, COUNT(Id) c
            FROM Exam_Domain__c WHERE Certification_Exam__c IN :examIds
            WITH SYSTEM_MODE GROUP BY Certification_Exam__c
        ]) {
            domainByExam.put((Id) ar.get('eId'), ((Decimal) ar.get('c')).intValue());
        }

        ExamsSummary out = new ExamsSummary();
        out.exams = new List<ExamRowDto>();
        out.totalExams = exams.size();
        out.activeExams = 0; out.examsWithPublished = 0;
        out.totalQuestions = 0; out.totalPublishedQuestions = 0;

        for (Certification_Exam__c e : exams) {
            ExamRowDto r = new ExamRowDto();
            r.id = e.Id;
            r.name = e.Name;
            r.code = e.Certification_Code__c;
            r.vendor = e.Vendor__c;
            r.track = e.Track__c;
            r.level = e.Level__c;
            r.cost = e.Cost__c;
            r.active = e.Active__c;
            r.questionCount = totalByExam.containsKey(e.Id) ? totalByExam.get(e.Id) : 0;
            r.publishedCount = pubByExam.containsKey(e.Id) ? pubByExam.get(e.Id) : 0;
            r.draftCount = draftByExam.containsKey(e.Id) ? draftByExam.get(e.Id) : 0;
            r.bankCount = bankByExam.containsKey(e.Id) ? bankByExam.get(e.Id) : 0;
            r.jobCount = jobByExam.containsKey(e.Id) ? jobByExam.get(e.Id) : 0;
            r.domainCount = domainByExam.containsKey(e.Id) ? domainByExam.get(e.Id) : 0;
            r.lastActivityAt = lastByExam.get(e.Id);
            out.exams.add(r);
            if (e.Active__c == true) out.activeExams++;
            if (r.publishedCount > 0) out.examsWithPublished++;
            out.totalQuestions += r.questionCount;
            out.totalPublishedQuestions += r.publishedCount;
        }
        return out;
    }

    @AuraEnabled(cacheable=true)
    public static ExamDetailDto getExamDetail(Id examId) {
        if (examId == null) throw new AuraHandledException('examId required');
        List<Certification_Exam__c> rows = [
            SELECT Id, Name, Certification_Code__c, Vendor__c, Track__c, Level__c, Cost__c, Active__c
            FROM Certification_Exam__c WHERE Id = :examId WITH SYSTEM_MODE LIMIT 1
        ];
        if (rows.isEmpty()) throw new AuraHandledException('Exam not found');
        Certification_Exam__c e = rows[0];

        ExamRowDto r = new ExamRowDto();
        r.id = e.Id; r.name = e.Name; r.code = e.Certification_Code__c; r.vendor = e.Vendor__c;
        r.track = e.Track__c; r.level = e.Level__c; r.cost = e.Cost__c; r.active = e.Active__c;
        r.questionCount = 0; r.publishedCount = 0; r.draftCount = 0;
        r.bankCount = 0; r.jobCount = 0; r.domainCount = 0;

        Map<Id, Integer> qByDomain = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Exam_Domain__c domainId, Status__c st, COUNT(Id) c, MAX(CreatedDate) lastAt
            FROM Trivia_Question__c WHERE Certification_Exam__c = :examId
            WITH SYSTEM_MODE GROUP BY Exam_Domain__c, Status__c
        ]) {
            Integer c = ((Decimal) ar.get('c')).intValue();
            Id dId = (Id) ar.get('domainId');
            Datetime la = (Datetime) ar.get('lastAt');
            String st = (String) ar.get('st');
            r.questionCount += c;
            if (st == 'Published') r.publishedCount += c;
            if (st == 'Draft' || st == 'Needs Review') r.draftCount += c;
            if (la != null && (r.lastActivityAt == null || la > r.lastActivityAt)) r.lastActivityAt = la;
            if (dId != null) qByDomain.put(dId, (qByDomain.containsKey(dId) ? qByDomain.get(dId) : 0) + c);
        }

        ExamDetailDto out = new ExamDetailDto();
        out.exam = r;

        out.domains = new List<DomainRowDto>();
        for (Exam_Domain__c d : [
            SELECT Id, Name, Weight_Percent__c
            FROM Exam_Domain__c WHERE Certification_Exam__c = :examId
            WITH SYSTEM_MODE ORDER BY Domain_Order__c NULLS LAST, Name LIMIT 50
        ]) {
            DomainRowDto dr = new DomainRowDto();
            dr.id = d.Id; dr.name = d.Name; dr.weightPercent = d.Weight_Percent__c;
            dr.questionCount = qByDomain.containsKey(d.Id) ? qByDomain.get(d.Id) : 0;
            out.domains.add(dr);
            r.domainCount++;
        }

        out.banks = new List<BankRowDto>();
        for (Question_Bank__c qb : [
            SELECT Id, Name, Status__c, Source_Type__c, CreatedDate
            FROM Question_Bank__c WHERE Certification_Exam__c = :examId
            WITH SYSTEM_MODE ORDER BY CreatedDate DESC LIMIT 25
        ]) {
            BankRowDto br = new BankRowDto();
            br.id = qb.Id; br.name = qb.Name; br.status = qb.Status__c;
            br.sourceType = qb.Source_Type__c; br.createdDate = qb.CreatedDate;
            out.banks.add(br);
            r.bankCount++;
        }

        out.jobs = new List<JobRowDto>();
        for (Question_Generation_Job__c j : [
            SELECT Id, Name, Status__c, Provider__c, Generated_Question_Count__c, CreatedDate
            FROM Question_Generation_Job__c WHERE Certification_Exam__c = :examId
            WITH SYSTEM_MODE ORDER BY CreatedDate DESC LIMIT 25
        ]) {
            JobRowDto jr = new JobRowDto();
            jr.id = j.Id; jr.name = j.Name; jr.status = j.Status__c; jr.provider = j.Provider__c;
            jr.generatedCount = j.Generated_Question_Count__c == null ? 0 : j.Generated_Question_Count__c.intValue();
            jr.createdDate = j.CreatedDate;
            out.jobs.add(jr);
            r.jobCount++;
        }

        return out;
    }

    /**
     * Returns a Site-hosted URL that pre-selects this exam in CertGameWeb.
     * Candidates still authenticate via Google OAuth on the page itself; we do not
     * mint a player-bound token here, just an exam deep link.
     *
     * @param examId  required, may be null for "random across all exams" mode
     * @param numQuestions  preferred default question count for the practice run
     */
    @AuraEnabled
    public static PracticeUrlDto mintPracticeUrl(Id examId, Integer numQuestions) {
        Integer n = (numQuestions == null || numQuestions <= 0) ? 10 : Math.min(numQuestions, 60);
        String base = Site.getBaseSecureUrl();
        if (String.isBlank(base)) {
            base = URL.getOrgDomainUrl().toExternalForm() + '/certgame';
        }
        String url = base + '/CertGameWeb?n=' + n;
        if (examId != null) url += '&exam=' + EncodingUtil.urlEncode(String.valueOf(examId), 'UTF-8');
        PracticeUrlDto out = new PracticeUrlDto();
        out.url = url;
        out.questionCount = n;
        return out;
    }
}
