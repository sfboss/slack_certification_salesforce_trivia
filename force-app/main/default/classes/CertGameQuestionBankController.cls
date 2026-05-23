/**
 * AuraEnabled facade for the Question Bank Workspace LWC.
 *
 * Surfaces:
 *   - Bank list with question-count + last-import rollups
 *   - Per-bank detail (status counts, recent questions)
 *   - Sample catalog read from `questionBankSamplesCatalog` static resource
 *   - JSON validation + import (thin wrappers over QuestionJsonValidator / CertGameImportService)
 *   - LLM generation kickoff (creates Question_Generation_Job__c + enqueues queueable)
 */
public with sharing class CertGameQuestionBankController {

    // -------------------- DTOs --------------------

    public class BankDto {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public String sourceType;
        @AuraEnabled public String version;
        @AuraEnabled public Id examId;
        @AuraEnabled public String examName;
        @AuraEnabled public String examCode;
        @AuraEnabled public Integer questionCount;
        @AuraEnabled public Integer publishedCount;
        @AuraEnabled public Integer draftCount;
        @AuraEnabled public Datetime lastImportedAt;
        @AuraEnabled public Datetime createdDate;
    }

    public class BankDetailDto {
        @AuraEnabled public BankDto bank;
        @AuraEnabled public List<QuestionRowDto> recentQuestions;
    }

    public class QuestionRowDto {
        @AuraEnabled public Id id;
        @AuraEnabled public String externalId;
        @AuraEnabled public String questionText;
        @AuraEnabled public String status;
        @AuraEnabled public String difficulty;
        @AuraEnabled public String domainName;
        @AuraEnabled public Datetime createdDate;
    }

    public class SampleDto {
        @AuraEnabled public String key;
        @AuraEnabled public String label;
        @AuraEnabled public String description;
        @AuraEnabled public Integer questionCount;
    }

    public class SamplesCatalog {
        @AuraEnabled public List<SampleDto> samples;
    }

    public class ValidationDto {
        @AuraEnabled public Boolean valid;
        @AuraEnabled public Integer questionCount;
        @AuraEnabled public List<String> errors;
    }

    public class GenerationKickoffDto {
        @AuraEnabled public Id jobId;
        @AuraEnabled public String status;
    }

    // -------------------- Read paths --------------------

    @AuraEnabled(cacheable=true)
    public static List<BankDto> listBanks() {
        List<Question_Bank__c> banks = [
            SELECT Id, Name, Status__c, Source_Type__c, Version__c,
                   Certification_Exam__c, Certification_Exam__r.Name, Certification_Exam__r.Certification_Code__c,
                   CreatedDate
            FROM Question_Bank__c
            WITH SYSTEM_MODE
            ORDER BY CreatedDate DESC
            LIMIT 200
        ];
        if (banks.isEmpty()) return new List<BankDto>();

        Set<Id> bankIds = new Set<Id>();
        for (Question_Bank__c b : banks) bankIds.add(b.Id);

        Map<Id, Integer> totalByBank = new Map<Id, Integer>();
        Map<Id, Integer> pubByBank = new Map<Id, Integer>();
        Map<Id, Integer> draftByBank = new Map<Id, Integer>();
        Map<Id, Datetime> lastByBank = new Map<Id, Datetime>();

        for (AggregateResult ar : [
            SELECT Question_Bank__c bank, Status__c status, COUNT(Id) cnt, MAX(CreatedDate) lastAt
            FROM Trivia_Question__c
            WHERE Question_Bank__c IN :bankIds
            WITH SYSTEM_MODE
            GROUP BY Question_Bank__c, Status__c
        ]) {
            Id bId = (Id) ar.get('bank');
            String st = (String) ar.get('status');
            Integer c = ((Decimal) ar.get('cnt')).intValue();
            Datetime lastAt = (Datetime) ar.get('lastAt');
            totalByBank.put(bId, (totalByBank.containsKey(bId) ? totalByBank.get(bId) : 0) + c);
            if (st == 'Published') pubByBank.put(bId, c);
            if (st == 'Draft' || st == 'Needs Review') {
                draftByBank.put(bId, (draftByBank.containsKey(bId) ? draftByBank.get(bId) : 0) + c);
            }
            if (lastAt != null && (!lastByBank.containsKey(bId) || lastAt > lastByBank.get(bId))) {
                lastByBank.put(bId, lastAt);
            }
        }

        List<BankDto> out = new List<BankDto>();
        for (Question_Bank__c b : banks) {
            BankDto d = new BankDto();
            d.id = b.Id;
            d.name = b.Name;
            d.status = b.Status__c;
            d.sourceType = b.Source_Type__c;
            d.version = b.Version__c;
            d.examId = b.Certification_Exam__c;
            d.examName = b.Certification_Exam__r == null ? null : b.Certification_Exam__r.Name;
            d.examCode = b.Certification_Exam__r == null ? null : b.Certification_Exam__r.Certification_Code__c;
            d.questionCount = totalByBank.containsKey(b.Id) ? totalByBank.get(b.Id) : 0;
            d.publishedCount = pubByBank.containsKey(b.Id) ? pubByBank.get(b.Id) : 0;
            d.draftCount = draftByBank.containsKey(b.Id) ? draftByBank.get(b.Id) : 0;
            d.lastImportedAt = lastByBank.get(b.Id);
            d.createdDate = b.CreatedDate;
            out.add(d);
        }
        return out;
    }

    @AuraEnabled(cacheable=true)
    public static BankDetailDto getBankDetail(Id bankId) {
        if (bankId == null) throw new AuraHandledException('bankId is required');
        List<Question_Bank__c> banks = [
            SELECT Id, Name, Status__c, Source_Type__c, Version__c,
                   Certification_Exam__c, Certification_Exam__r.Name, Certification_Exam__r.Certification_Code__c,
                   CreatedDate
            FROM Question_Bank__c WHERE Id = :bankId WITH SYSTEM_MODE LIMIT 1
        ];
        if (banks.isEmpty()) throw new AuraHandledException('Bank not found');
        Question_Bank__c b = banks[0];

        BankDto bd = new BankDto();
        bd.id = b.Id;
        bd.name = b.Name;
        bd.status = b.Status__c;
        bd.sourceType = b.Source_Type__c;
        bd.version = b.Version__c;
        bd.examId = b.Certification_Exam__c;
        bd.examName = b.Certification_Exam__r == null ? null : b.Certification_Exam__r.Name;
        bd.examCode = b.Certification_Exam__r == null ? null : b.Certification_Exam__r.Certification_Code__c;
        bd.createdDate = b.CreatedDate;

        Integer total = 0, pub = 0, drf = 0;
        Datetime last;
        for (AggregateResult ar : [
            SELECT Status__c st, COUNT(Id) c, MAX(CreatedDate) lastAt
            FROM Trivia_Question__c WHERE Question_Bank__c = :bankId
            WITH SYSTEM_MODE GROUP BY Status__c
        ]) {
            String st = (String) ar.get('st');
            Integer c = ((Decimal) ar.get('c')).intValue();
            Datetime la = (Datetime) ar.get('lastAt');
            total += c;
            if (st == 'Published') pub += c;
            if (st == 'Draft' || st == 'Needs Review') drf += c;
            if (la != null && (last == null || la > last)) last = la;
        }
        bd.questionCount = total;
        bd.publishedCount = pub;
        bd.draftCount = drf;
        bd.lastImportedAt = last;

        BankDetailDto dto = new BankDetailDto();
        dto.bank = bd;
        dto.recentQuestions = new List<QuestionRowDto>();
        for (Trivia_Question__c q : [
            SELECT Id, External_Id__c, Question_Text__c, Status__c, Difficulty__c,
                   Exam_Domain__r.Name, CreatedDate
            FROM Trivia_Question__c WHERE Question_Bank__c = :bankId
            WITH SYSTEM_MODE ORDER BY CreatedDate DESC LIMIT 25
        ]) {
            QuestionRowDto r = new QuestionRowDto();
            r.id = q.Id;
            r.externalId = q.External_Id__c;
            r.questionText = q.Question_Text__c;
            r.status = q.Status__c;
            r.difficulty = q.Difficulty__c;
            r.domainName = q.Exam_Domain__r == null ? null : q.Exam_Domain__r.Name;
            r.createdDate = q.CreatedDate;
            dto.recentQuestions.add(r);
        }
        return dto;
    }

    @AuraEnabled(cacheable=true)
    public static SamplesCatalog loadSamplesCatalog() {
        SamplesCatalog cat = new SamplesCatalog();
        cat.samples = new List<SampleDto>();
        List<StaticResource> srs = [
            SELECT Body FROM StaticResource WHERE Name = 'questionBankSamplesCatalog' LIMIT 1
        ];
        if (srs.isEmpty()) return cat;
        try {
            Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(srs[0].Body.toString());
            for (Object o : (List<Object>) root.get('samples')) {
                Map<String, Object> m = (Map<String, Object>) o;
                SampleDto s = new SampleDto();
                s.key = (String) m.get('key');
                s.label = (String) m.get('label');
                s.description = (String) m.get('description');
                List<Object> qs = (List<Object>) ((Map<String, Object>) m.get('pack')).get('questions');
                s.questionCount = qs == null ? 0 : qs.size();
                cat.samples.add(s);
            }
        } catch (Exception e) {
            AppLogger.error('CertGameQuestionBankController', 'loadSamplesCatalog', e.getMessage(), e);
        }
        return cat;
    }

    @AuraEnabled
    public static String loadSampleJson(String sampleKey) {
        if (String.isBlank(sampleKey)) throw new AuraHandledException('sampleKey is required');
        List<StaticResource> srs = [
            SELECT Body FROM StaticResource WHERE Name = 'questionBankSamplesCatalog' LIMIT 1
        ];
        if (srs.isEmpty()) throw new AuraHandledException('Samples catalog not deployed');
        Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(srs[0].Body.toString());
        for (Object o : (List<Object>) root.get('samples')) {
            Map<String, Object> m = (Map<String, Object>) o;
            if (sampleKey.equals((String) m.get('key'))) {
                return JSON.serialize(m.get('pack'));
            }
        }
        throw new AuraHandledException('Sample not found: ' + sampleKey);
    }

    // -------------------- Validate / import --------------------

    @AuraEnabled
    public static ValidationDto validateJson(String jsonBody) {
        ValidationDto v = new ValidationDto();
        QuestionJsonValidator.Result r = QuestionJsonValidator.validate(jsonBody);
        v.valid = r.valid;
        v.questionCount = r.questionCount;
        v.errors = r.errors;
        return v;
    }

    @AuraEnabled
    public static CertGameImportService.ImportResult importPack(String jsonBody) {
        return CertGameImportService.importPack(jsonBody);
    }

    // -------------------- Generation kickoff --------------------

    @AuraEnabled
    public static GenerationKickoffDto startGenerationJob(Id examId, String provider, Integer questionCount, String promptText) {
        if (examId == null) throw new AuraHandledException('examId is required');
        Integer count = (questionCount == null || questionCount <= 0) ? 5 : Math.min(questionCount, 25);
        String prov = String.isBlank(provider) ? 'OpenAI' : provider;

        Question_Generation_Job__c job = new Question_Generation_Job__c(
            Certification_Exam__c = examId,
            Provider__c = prov,
            Requested_Question_Count__c = count,
            Prompt_Text__c = promptText,
            Status__c = 'Queued',
            Requested_By__c = UserInfo.getUserId()
        );
        insert as system job;

        if (!Test.isRunningTest()) {
            System.enqueueJob(new CertGameGenerationJobQueueable(job.Id));
        }

        GenerationKickoffDto out = new GenerationKickoffDto();
        out.jobId = job.Id;
        out.status = job.Status__c;
        return out;
    }

    // -------------------- Exam picker --------------------

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> listExams() {
        List<Map<String, Object>> out = new List<Map<String, Object>>();
        for (Certification_Exam__c e : [
            SELECT Id, Name, Certification_Code__c FROM Certification_Exam__c
            WHERE Active__c = true WITH SYSTEM_MODE ORDER BY Name LIMIT 200
        ]) {
            out.add(new Map<String, Object>{
                'value' => e.Id,
                'label' => (e.Certification_Code__c == null ? e.Name : (e.Certification_Code__c + ' — ' + e.Name))
            });
        }
        return out;
    }
}
