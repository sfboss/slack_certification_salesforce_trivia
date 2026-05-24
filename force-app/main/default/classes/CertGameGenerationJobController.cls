/**
 * AuraEnabled facade for the Generation Workspace LWC.
 *
 * Read paths:
 *   - listJobs       : summary with status counts + token cost MTD
 *   - getJobDetail   : full record including Output_JSON__c
 *   - listExamDomains: domain picker for the kickoff wizard
 *
 * Write paths:
 *   - startJob       : creates Question_Generation_Job__c and enqueues the worker
 *   - rerunJob       : clones an existing job's parameters and enqueues a fresh run
 */
public with sharing class CertGameGenerationJobController {

    // -------------------- DTOs --------------------

    public class JobRowDto {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public Id examId;
        @AuraEnabled public String examName;
        @AuraEnabled public String examCode;
        @AuraEnabled public String status;
        @AuraEnabled public String provider;
        @AuraEnabled public String model;
        @AuraEnabled public Integer requestedCount;
        @AuraEnabled public Integer generatedCount;
        @AuraEnabled public String domainFocus;
        @AuraEnabled public String difficultyFocus;
        @AuraEnabled public Decimal tokenCostUsd;
        @AuraEnabled public String errorMessage;
        @AuraEnabled public String requestedByName;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public Datetime lastModifiedDate;
    }

    public class JobsSummary {
        @AuraEnabled public List<JobRowDto> jobs;
        @AuraEnabled public Integer totalJobs;
        @AuraEnabled public Integer runningJobs;
        @AuraEnabled public Integer completedJobs;
        @AuraEnabled public Integer failedJobs;
        @AuraEnabled public Integer questionsGenerated;
        @AuraEnabled public Decimal tokenCostMtd;
    }

    public class JobDetailDto {
        @AuraEnabled public JobRowDto job;
        @AuraEnabled public String promptText;
        @AuraEnabled public String outputJson;
        @AuraEnabled public Integer outputJsonLength;
    }

    public class DomainDto {
        @AuraEnabled public String value;
        @AuraEnabled public String label;
    }

    public class StartJobInput {
        @AuraEnabled public Id examId;
        @AuraEnabled public String provider;
        @AuraEnabled public Integer questionCount;
        @AuraEnabled public String difficulty;
        @AuraEnabled public List<String> domains;
        @AuraEnabled public String promptNotes;
    }

    public class KickoffDto {
        @AuraEnabled public Id jobId;
        @AuraEnabled public String status;
    }

    // -------------------- Reads --------------------

    @AuraEnabled(cacheable=true)
    public static JobsSummary listJobs(Integer maxRows) {
        Integer cap = (maxRows == null || maxRows <= 0) ? 50 : Math.min(maxRows, 200);

        List<Question_Generation_Job__c> rows = [
            SELECT Id, Name, Certification_Exam__c, Certification_Exam__r.Name, Certification_Exam__r.Certification_Code__c,
                   Status__c, Provider__c, Model__c, Requested_Question_Count__c, Generated_Question_Count__c,
                   Domain_Focus__c, Difficulty_Focus__c, Token_Cost_USD__c, Error_Message__c,
                   Requested_By__r.Name, CreatedDate, LastModifiedDate
            FROM Question_Generation_Job__c
            WITH SYSTEM_MODE
            ORDER BY CreatedDate DESC
            LIMIT :cap
        ];

        JobsSummary out = new JobsSummary();
        out.jobs = new List<JobRowDto>();
        out.totalJobs = 0;
        out.runningJobs = 0;
        out.completedJobs = 0;
        out.failedJobs = 0;
        out.questionsGenerated = 0;
        out.tokenCostMtd = 0;

        Date monthStart = Date.today().toStartOfMonth();
        for (Question_Generation_Job__c j : rows) {
            out.jobs.add(toRow(j));
            out.totalJobs++;
            if (j.Status__c == 'Running' || j.Status__c == 'Queued') out.runningJobs++;
            else if (j.Status__c == 'Completed') out.completedJobs++;
            else if (j.Status__c == 'Failed') out.failedJobs++;
            if (j.Generated_Question_Count__c != null) out.questionsGenerated += j.Generated_Question_Count__c.intValue();
            if (j.CreatedDate >= monthStart && j.Token_Cost_USD__c != null) out.tokenCostMtd += j.Token_Cost_USD__c;
        }
        return out;
    }

    @AuraEnabled(cacheable=true)
    public static JobDetailDto getJobDetail(Id jobId) {
        if (jobId == null) throw new AuraHandledException('jobId required');
        List<Question_Generation_Job__c> rows = [
            SELECT Id, Name, Certification_Exam__c, Certification_Exam__r.Name, Certification_Exam__r.Certification_Code__c,
                   Status__c, Provider__c, Model__c, Requested_Question_Count__c, Generated_Question_Count__c,
                   Domain_Focus__c, Difficulty_Focus__c, Token_Cost_USD__c, Error_Message__c, Prompt_Text__c, Output_JSON__c,
                   Requested_By__r.Name, CreatedDate, LastModifiedDate
            FROM Question_Generation_Job__c WHERE Id = :jobId WITH SYSTEM_MODE LIMIT 1
        ];
        if (rows.isEmpty()) throw new AuraHandledException('Job not found');
        Question_Generation_Job__c j = rows[0];

        JobDetailDto dto = new JobDetailDto();
        dto.job = toRow(j);
        dto.promptText = j.Prompt_Text__c;
        dto.outputJson = j.Output_JSON__c;
        dto.outputJsonLength = j.Output_JSON__c == null ? 0 : j.Output_JSON__c.length();
        return dto;
    }

    @AuraEnabled(cacheable=true)
    public static List<DomainDto> listExamDomains(Id examId) {
        List<DomainDto> out = new List<DomainDto>();
        if (examId == null) return out;
        for (Exam_Domain__c d : [
            SELECT Id, Name, Weight_Percent__c FROM Exam_Domain__c
            WHERE Certification_Exam__c = :examId WITH SYSTEM_MODE
            ORDER BY Domain_Order__c NULLS LAST, Name LIMIT 50
        ]) {
            DomainDto dd = new DomainDto();
            dd.value = d.Name;
            dd.label = d.Weight_Percent__c == null ? d.Name : (d.Name + ' (' + d.Weight_Percent__c.intValue() + '%)');
            out.add(dd);
        }
        return out;
    }

    // -------------------- Writes --------------------

    @AuraEnabled
    public static KickoffDto startJob(StartJobInput input) {
        if (input == null) throw new AuraHandledException('input required');
        if (input.examId == null) throw new AuraHandledException('examId required');
        Integer count = (input.questionCount == null || input.questionCount <= 0)
            ? 5 : Math.min(input.questionCount, 25);
        String prov = String.isBlank(input.provider) ? 'OpenAI' : input.provider;
        String diff = String.isBlank(input.difficulty) ? 'Mixed' : input.difficulty;
        String domainCsv = (input.domains == null || input.domains.isEmpty())
            ? null : String.join(input.domains, ', ');

        Question_Generation_Job__c job = new Question_Generation_Job__c(
            Certification_Exam__c = input.examId,
            Provider__c = prov,
            Requested_Question_Count__c = count,
            Difficulty_Focus__c = diff,
            Domain_Focus__c = domainCsv,
            Prompt_Text__c = input.promptNotes,
            Status__c = 'Queued',
            Requested_By__c = UserInfo.getUserId()
        );
        insert as system job;

        if (!Test.isRunningTest()) {
            System.enqueueJob(new CertGameGenerationJobQueueable(job.Id));
        }

        KickoffDto out = new KickoffDto();
        out.jobId = job.Id;
        out.status = job.Status__c;
        return out;
    }

    @AuraEnabled
    public static KickoffDto rerunJob(Id jobId) {
        if (jobId == null) throw new AuraHandledException('jobId required');
        List<Question_Generation_Job__c> rows = [
            SELECT Certification_Exam__c, Provider__c, Requested_Question_Count__c,
                   Domain_Focus__c, Difficulty_Focus__c, Prompt_Text__c
            FROM Question_Generation_Job__c WHERE Id = :jobId WITH SYSTEM_MODE LIMIT 1
        ];
        if (rows.isEmpty()) throw new AuraHandledException('Job not found');
        Question_Generation_Job__c src = rows[0];

        StartJobInput input = new StartJobInput();
        input.examId = src.Certification_Exam__c;
        input.provider = src.Provider__c;
        input.questionCount = src.Requested_Question_Count__c == null ? 5 : src.Requested_Question_Count__c.intValue();
        input.difficulty = src.Difficulty_Focus__c;
        input.promptNotes = src.Prompt_Text__c;
        input.domains = new List<String>();
        if (String.isNotBlank(src.Domain_Focus__c)) {
            for (String d : src.Domain_Focus__c.split(',')) {
                if (String.isNotBlank(d)) input.domains.add(d.trim());
            }
        }
        return startJob(input);
    }

    // -------------------- Helpers --------------------

    private static JobRowDto toRow(Question_Generation_Job__c j) {
        JobRowDto r = new JobRowDto();
        r.id = j.Id;
        r.name = j.Name;
        r.examId = j.Certification_Exam__c;
        r.examName = j.Certification_Exam__r == null ? null : j.Certification_Exam__r.Name;
        r.examCode = j.Certification_Exam__r == null ? null : j.Certification_Exam__r.Certification_Code__c;
        r.status = j.Status__c;
        r.provider = j.Provider__c;
        r.model = j.Model__c;
        r.requestedCount = j.Requested_Question_Count__c == null ? 0 : j.Requested_Question_Count__c.intValue();
        r.generatedCount = j.Generated_Question_Count__c == null ? 0 : j.Generated_Question_Count__c.intValue();
        r.domainFocus = j.Domain_Focus__c;
        r.difficultyFocus = j.Difficulty_Focus__c;
        r.tokenCostUsd = j.Token_Cost_USD__c == null ? 0 : j.Token_Cost_USD__c;
        r.errorMessage = j.Error_Message__c;
        r.requestedByName = j.Requested_By__r == null ? null : j.Requested_By__r.Name;
        r.createdDate = j.CreatedDate;
        r.lastModifiedDate = j.LastModifiedDate;
        return r;
    }
}
