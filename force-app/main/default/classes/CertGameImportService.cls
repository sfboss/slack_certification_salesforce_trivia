/**
 * Imports a question pack JSON into Salesforce. All inserts land as Draft.
 * Idempotent via External_Id__c values on Certification_Exam__c, Question_Bank__c, and Trivia_Question__c.
 */
public with sharing class CertGameImportService {

    public class ImportResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public List<String> errors;
        @AuraEnabled public Id examId;
        @AuraEnabled public Id questionBankId;
        @AuraEnabled public Integer questionsCreated;
        @AuraEnabled public Integer questionsUpdated;
        @AuraEnabled public List<String> duplicateExternalIds;
        public ImportResult() {
            this.success = false;
            this.errors = new List<String>();
            this.questionsCreated = 0;
            this.questionsUpdated = 0;
            this.duplicateExternalIds = new List<String>();
        }
    }

    @AuraEnabled
    public static ImportResult importPack(String jsonBody) {
        ImportResult res = new ImportResult();
        QuestionJsonValidator.Result vr = QuestionJsonValidator.validate(jsonBody);
        if (!vr.valid) {
            res.errors = vr.errors;
            return res;
        }
        try {
            Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(jsonBody);
            res.examId = upsertExam((Map<String, Object>) root.get('exam'));
            res.questionBankId = upsertBank((Map<String, Object>) root.get('questionBank'), res.examId);
            importQuestions((List<Object>) root.get('questions'), res);
            res.success = res.errors.isEmpty();
        } catch (Exception e) {
            AppLogger.error('CertGameImportService', 'importPack', e.getMessage(), e);
            res.errors.add(e.getMessage());
        }
        return res;
    }

    private static Id upsertExam(Map<String, Object> exam) {
        String code = (String) exam.get('code');
        Certification_Exam__c row = new Certification_Exam__c(
            Name = (String) exam.get('name'),
            Certification_Code__c = code,
            Vendor__c = (String) exam.get('vendor'),
            Active__c = true
        );
        Database.upsertResult ur = Database.upsert(row, Certification_Exam__c.Certification_Code__c, false);
        if (!ur.isSuccess()) {
            throw new ImportException('Exam upsert failed: ' + ur.getErrors()[0].getMessage());
        }
        return row.Id;
    }

    private static Id upsertBank(Map<String, Object> bank, Id examId) {
        String extId = (String) bank.get('externalId');
        if (String.isBlank(extId)) extId = 'BANK-' + EncodingUtil.convertToHex(Crypto.generateAesKey(64)).left(20);
        Question_Bank__c row = new Question_Bank__c(
            Name = (String) bank.get('name'),
            Certification_Exam__c = examId,
            Source_Type__c = (String) bank.get('sourceType'),
            Status__c = 'Draft',
            Version__c = (String) bank.get('version'),
            External_Id__c = extId
        );
        Database.upsertResult ur = Database.upsert(row, Question_Bank__c.External_Id__c, false);
        if (!ur.isSuccess()) {
            throw new ImportException('Bank upsert failed: ' + ur.getErrors()[0].getMessage());
        }
        return row.Id;
    }

    private static void importQuestions(List<Object> rawQuestions, ImportResult res) {
        // 1. Existing questions by external id
        Set<String> incomingExtIds = new Set<String>();
        for (Object o : rawQuestions) {
            Map<String, Object> q = (Map<String, Object>) o;
            String eid = (String) q.get('externalId');
            if (String.isNotBlank(eid)) incomingExtIds.add(eid);
        }
        Map<String, Trivia_Question__c> existing = new Map<String, Trivia_Question__c>();
        for (Trivia_Question__c tq : [
            SELECT Id, External_Id__c, Hash__c
            FROM Trivia_Question__c
            WHERE External_Id__c IN :incomingExtIds
            WITH SYSTEM_MODE
        ]) {
            existing.put(tq.External_Id__c, tq);
        }

        // 2. Build domain map
        Map<String, Id> domainByName = new Map<String, Id>();
        for (Exam_Domain__c d : [
            SELECT Id, Name FROM Exam_Domain__c
            WHERE Certification_Exam__c = :res.examId
            WITH SYSTEM_MODE
        ]) {
            domainByName.put(d.Name, d.Id);
        }

        // 3. Upsert exam domains for any new ones in the pack
        List<Exam_Domain__c> domainsToInsert = new List<Exam_Domain__c>();
        Set<String> seenDomain = new Set<String>();
        for (Object o : rawQuestions) {
            Map<String, Object> q = (Map<String, Object>) o;
            String dom = (String) q.get('domain');
            if (String.isBlank(dom) || seenDomain.contains(dom) || domainByName.containsKey(dom)) continue;
            seenDomain.add(dom);
            domainsToInsert.add(new Exam_Domain__c(
                Name = dom,
                Certification_Exam__c = res.examId
            ));
        }
        if (!domainsToInsert.isEmpty()) {
            insert as system domainsToInsert;
            for (Exam_Domain__c d : domainsToInsert) domainByName.put(d.Name, d.Id);
        }

        // 4. Build/Upsert questions
        List<Trivia_Question__c> toUpsert = new List<Trivia_Question__c>();
        Map<Integer, Map<String, Object>> qsByIndex = new Map<Integer, Map<String, Object>>();
        Map<Integer, String> hashByIndex = new Map<Integer, String>();
        for (Integer i = 0; i < rawQuestions.size(); i++) {
            Map<String, Object> q = (Map<String, Object>) rawQuestions[i];
            qsByIndex.put(i, q);
            String extId = (String) q.get('externalId');
            List<Object> rawChoices = (List<Object>) q.get('choices');
            List<String> correctTexts = new List<String>();
            for (Object c : rawChoices) {
                Map<String, Object> cm = (Map<String, Object>) c;
                if (cm.get('isCorrect') == true) correctTexts.add((String) cm.get('text'));
            }
            String h = QuestionDuplicateDetector.hash((String) q.get('question'), correctTexts);
            hashByIndex.put(i, h);

            Trivia_Question__c tq = new Trivia_Question__c(
                External_Id__c = extId,
                Certification_Exam__c = res.examId,
                Question_Bank__c = res.questionBankId,
                Exam_Domain__c = domainByName.get((String) q.get('domain')),
                Question_Text__c = (String) q.get('question'),
                Scenario_Text__c = (String) q.get('scenario'),
                Question_Type__c = (String) q.get('questionType'),
                Difficulty__c = (String) q.get('difficulty'),
                Status__c = 'Draft',
                Correct_Answer_Mode__c = (q.get('questionType') == 'Multi Select') ? 'MultiRequired' : 'Exact',
                Explanation__c = (String) q.get('explanation'),
                Hash__c = h
            );
            toUpsert.add(tq);
        }

        Database.UpsertResult[] urs = Database.upsert(toUpsert, Trivia_Question__c.External_Id__c, false);
        for (Integer i = 0; i < urs.size(); i++) {
            if (!urs[i].isSuccess()) {
                res.errors.add('Question ' + i + ' upsert failed: ' + urs[i].getErrors()[0].getMessage());
                continue;
            }
            if (urs[i].isCreated()) res.questionsCreated++;
            else res.questionsUpdated++;
        }

        // 5. Replace child choices + citations (delete+insert for simplicity)
        Set<Id> qIds = new Set<Id>();
        for (Trivia_Question__c tq : toUpsert) if (tq.Id != null) qIds.add(tq.Id);
        if (!qIds.isEmpty()) {
            delete as system [SELECT Id FROM Trivia_Answer_Choice__c WHERE Trivia_Question__c IN :qIds WITH SYSTEM_MODE];
            delete as system [SELECT Id FROM Question_Citation__c    WHERE Trivia_Question__c IN :qIds WITH SYSTEM_MODE];
        }

        List<Trivia_Answer_Choice__c> choices = new List<Trivia_Answer_Choice__c>();
        List<Question_Citation__c> cites = new List<Question_Citation__c>();
        for (Integer i = 0; i < toUpsert.size(); i++) {
            Trivia_Question__c tq = toUpsert[i];
            if (tq.Id == null) continue;
            Map<String, Object> q = qsByIndex.get(i);
            Integer order = 0;
            for (Object co : (List<Object>) q.get('choices')) {
                Map<String, Object> c = (Map<String, Object>) co;
                choices.add(new Trivia_Answer_Choice__c(
                    Trivia_Question__c = tq.Id,
                    Choice_Label__c = (String) c.get('label'),
                    Choice_Text__c = (String) c.get('text'),
                    Is_Correct__c = c.get('isCorrect') == true,
                    Explanation__c = (String) c.get('explanation'),
                    Sort_Order__c = ++order
                ));
            }
            List<Object> ciList = (List<Object>) q.get('citations');
            if (ciList != null) {
                for (Object cio : ciList) {
                    Map<String, Object> ci = (Map<String, Object>) cio;
                    cites.add(new Question_Citation__c(
                        Trivia_Question__c = tq.Id,
                        Title__c = (String) ci.get('title'),
                        URL__c = (String) ci.get('url'),
                        Source_Type__c = (String) ci.get('sourceType'),
                        Relevance_Note__c = (String) ci.get('relevanceNote')
                    ));
                }
            }
        }
        if (!choices.isEmpty()) insert as system choices;
        if (!cites.isEmpty()) insert as system cites;

        // 6. Duplicate detection across pack vs existing (only for new questions)
        Set<String> hashesIn = new Set<String>();
        for (String h : hashByIndex.values()) hashesIn.add(h);
        Set<String> dupes = QuestionDuplicateDetector.findDuplicateHashes(hashesIn);
        Map<String, Integer> hashCount = new Map<String, Integer>();
        for (String h : hashByIndex.values()) {
            hashCount.put(h, (hashCount.containsKey(h) ? hashCount.get(h) : 0) + 1);
        }
        for (Integer i = 0; i < toUpsert.size(); i++) {
            String h = hashByIndex.get(i);
            // collision if hash already used by a *different* question, or appears more than once in this pack
            if ((dupes.contains(h) && existing.get((String) qsByIndex.get(i).get('externalId')) == null)
                || hashCount.get(h) > 1) {
                res.duplicateExternalIds.add((String) qsByIndex.get(i).get('externalId'));
            }
        }
    }

    public class ImportException extends Exception {}
}