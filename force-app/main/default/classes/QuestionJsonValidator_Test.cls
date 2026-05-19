@IsTest
private class QuestionJsonValidator_Test {

    private static String validPack() {
        return JSON.serialize(new Map<String,Object>{
            'exam' => new Map<String,Object>{'name'=>'CSA','code'=>'CSA-1','vendor'=>'Salesforce'},
            'questionBank' => new Map<String,Object>{
                'name'=>'B1','externalId'=>'BANK-X','version'=>'1.0',
                'sourceType'=>'Manual','status'=>'Draft'
            },
            'questions' => new List<Object>{
                new Map<String,Object>{
                    'externalId'=>'Q1','domain'=>'Sharing',
                    'difficulty'=>'Beginner','questionType'=>'Single Select',
                    'question'=>'What?','choices'=>new List<Object>{
                        new Map<String,Object>{'label'=>'A','text'=>'a','isCorrect'=>true},
                        new Map<String,Object>{'label'=>'B','text'=>'b','isCorrect'=>false},
                        new Map<String,Object>{'label'=>'C','text'=>'c','isCorrect'=>false}
                    },
                    'citations'=>new List<Object>{ new Map<String,Object>{'title'=>'T','url'=>'https://x','sourceType'=>'Help'}}
                }
            }
        });
    }

    @IsTest static void validPasses() {
        QuestionJsonValidator.Result r = QuestionJsonValidator.validate(validPack());
        System.assert(r.valid, String.join(r.errors, '; '));
        System.assertEquals(1, r.questionCount);
    }

    @IsTest static void emptyBodyFails() {
        QuestionJsonValidator.Result r = QuestionJsonValidator.validate('');
        System.assert(!r.valid);
    }

    @IsTest static void badJsonFails() {
        QuestionJsonValidator.Result r = QuestionJsonValidator.validate('not-json');
        System.assert(!r.valid);
    }

    @IsTest static void missingExamFails() {
        Map<String,Object> root = (Map<String,Object>) JSON.deserializeUntyped(validPack());
        root.remove('exam');
        QuestionJsonValidator.Result r = QuestionJsonValidator.validate(JSON.serialize(root));
        System.assert(!r.valid);
    }

    @IsTest static void singleSelectTooFewChoicesFails() {
        Map<String,Object> root = (Map<String,Object>) JSON.deserializeUntyped(validPack());
        List<Object> qs = (List<Object>) root.get('questions');
        Map<String,Object> q = (Map<String,Object>) qs[0];
        List<Object> ch = (List<Object>) q.get('choices');
        ch.remove(2);
        QuestionJsonValidator.Result r = QuestionJsonValidator.validate(JSON.serialize(root));
        System.assert(!r.valid);
    }

    @IsTest static void multiSelectRequiresTwoCorrect() {
        Map<String,Object> root = (Map<String,Object>) JSON.deserializeUntyped(validPack());
        Map<String,Object> q = (Map<String,Object>) ((List<Object>) root.get('questions'))[0];
        q.put('questionType', 'Multi Select');
        QuestionJsonValidator.Result r = QuestionJsonValidator.validate(JSON.serialize(root));
        System.assert(!r.valid);
    }

    @IsTest static void trueFalseRequiresTwoChoices() {
        Map<String,Object> root = (Map<String,Object>) JSON.deserializeUntyped(validPack());
        Map<String,Object> q = (Map<String,Object>) ((List<Object>) root.get('questions'))[0];
        q.put('questionType', 'True False');
        QuestionJsonValidator.Result r = QuestionJsonValidator.validate(JSON.serialize(root));
        System.assert(!r.valid);
    }

    @IsTest static void citationRequired() {
        Map<String,Object> root = (Map<String,Object>) JSON.deserializeUntyped(validPack());
        Map<String,Object> q = (Map<String,Object>) ((List<Object>) root.get('questions'))[0];
        q.put('citations', new List<Object>());
        QuestionJsonValidator.Result r = QuestionJsonValidator.validate(JSON.serialize(root));
        System.assert(!r.valid);
    }

    @IsTest static void duplicateLabelFails() {
        Map<String,Object> root = (Map<String,Object>) JSON.deserializeUntyped(validPack());
        Map<String,Object> q = (Map<String,Object>) ((List<Object>) root.get('questions'))[0];
        List<Object> ch = (List<Object>) q.get('choices');
        ((Map<String,Object>) ch[1]).put('label', 'A');
        QuestionJsonValidator.Result r = QuestionJsonValidator.validate(JSON.serialize(root));
        System.assert(!r.valid);
    }
}