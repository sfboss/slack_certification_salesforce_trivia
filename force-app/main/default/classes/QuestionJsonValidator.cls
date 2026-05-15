/**
 * Validates a Cert Game question pack JSON string against the schema in README §7.
 * Mirrors scripts/validate-question-json.py.
 */
public with sharing class QuestionJsonValidator {

    public class Result {
        @AuraEnabled public Boolean valid;
        @AuraEnabled public List<String> errors;
        @AuraEnabled public Integer questionCount;
        public Result() { this.valid = true; this.errors = new List<String>(); this.questionCount = 0; }
    }

    public static Result validate(String json) {
        Result r = new Result();
        if (String.isBlank(json)) { r.valid = false; r.errors.add('Empty body.'); return r; }
        Map<String, Object> root;
        try {
            root = (Map<String, Object>) JSON.deserializeUntyped(json);
        } catch (Exception e) {
            r.valid = false; r.errors.add('Invalid JSON: ' + e.getMessage()); return r;
        }
        validateExam(root, r);
        validateBank(root, r);
        validateQuestions(root, r);
        r.valid = r.errors.isEmpty();
        return r;
    }

    private static void validateExam(Map<String, Object> root, Result r) {
        Object o = root.get('exam');
        if (!(o instanceof Map<String, Object>)) { r.errors.add('exam: missing object'); return; }
        Map<String, Object> exam = (Map<String, Object>) o;
        if (String.isBlank((String) exam.get('name'))) r.errors.add('exam.name: required');
        if (String.isBlank((String) exam.get('code'))) r.errors.add('exam.code: required');
    }

    private static void validateBank(Map<String, Object> root, Result r) {
        Object o = root.get('questionBank');
        if (!(o instanceof Map<String, Object>)) { r.errors.add('questionBank: missing object'); return; }
        Map<String, Object> b = (Map<String, Object>) o;
        if (String.isBlank((String) b.get('name'))) r.errors.add('questionBank.name: required');
        if (String.isBlank((String) b.get('version'))) r.errors.add('questionBank.version: required');
        Set<String> sources = new Set<String>{'Manual', 'Generated', 'Imported', 'OfficialNotesDerived'};
        Set<String> statuses = new Set<String>{'Draft', 'Review', 'Published', 'Retired'};
        if (!sources.contains((String) b.get('sourceType'))) r.errors.add('questionBank.sourceType: invalid');
        if (!statuses.contains((String) b.get('status'))) r.errors.add('questionBank.status: invalid');
    }

    private static void validateQuestions(Map<String, Object> root, Result r) {
        Object o = root.get('questions');
        if (!(o instanceof List<Object>)) { r.errors.add('questions: missing array'); return; }
        List<Object> qs = (List<Object>) o;
        if (qs.isEmpty()) { r.errors.add('questions: must contain at least 1 question'); return; }
        r.questionCount = qs.size();
        Set<String> diffs = new Set<String>{'Beginner', 'Intermediate', 'Advanced', 'Expert'};
        Set<String> qtypes = new Set<String>{'Single Select', 'Multi Select', 'True False'};
        for (Integer i = 0; i < qs.size(); i++) {
            String prefix = 'questions[' + i + ']';
            if (!(qs[i] instanceof Map<String, Object>)) { r.errors.add(prefix + ': not an object'); continue; }
            Map<String, Object> q = (Map<String, Object>) qs[i];
            String extId = (String) q.get('externalId');
            if (String.isBlank(extId)) { r.errors.add(prefix + '.externalId: required'); }
            else prefix = 'questions[' + i + '] (' + extId + ')';
            if (String.isBlank((String) q.get('domain'))) r.errors.add(prefix + '.domain: required');
            if (!diffs.contains((String) q.get('difficulty'))) r.errors.add(prefix + '.difficulty: invalid');
            String qtype = (String) q.get('questionType');
            if (!qtypes.contains(qtype)) r.errors.add(prefix + '.questionType: invalid');
            if (String.isBlank((String) q.get('question'))) r.errors.add(prefix + '.question: required');

            Object cObj = q.get('choices');
            if (!(cObj instanceof List<Object>)) { r.errors.add(prefix + '.choices: required array'); continue; }
            List<Object> choices = (List<Object>) cObj;
            Integer correct = 0;
            Set<String> labels = new Set<String>();
            for (Object co : choices) {
                if (!(co instanceof Map<String, Object>)) continue;
                Map<String, Object> c = (Map<String, Object>) co;
                if (String.isBlank((String) c.get('label'))) r.errors.add(prefix + '.choices.label: required');
                else if (!labels.add((String) c.get('label'))) r.errors.add(prefix + '.choices: duplicate label ' + c.get('label'));
                if (String.isBlank((String) c.get('text'))) r.errors.add(prefix + '.choices.text: required');
                if (c.get('isCorrect') == true) correct++;
            }
            if (qtype == 'Single Select') {
                if (choices.size() < 3) r.errors.add(prefix + ': Single Select requires >= 3 choices');
                if (correct != 1) r.errors.add(prefix + ': Single Select requires exactly 1 correct, got ' + correct);
            } else if (qtype == 'Multi Select') {
                if (correct < 2) r.errors.add(prefix + ': Multi Select requires >= 2 correct, got ' + correct);
            } else if (qtype == 'True False') {
                if (choices.size() != 2) r.errors.add(prefix + ': True False requires exactly 2 choices');
                if (correct != 1) r.errors.add(prefix + ': True False requires exactly 1 correct');
            }
            Object citeObj = q.get('citations');
            if (citeObj == null || ((List<Object>) citeObj).isEmpty()) {
                r.errors.add(prefix + ': at least one citation is required');
            }
        }
    }
}
