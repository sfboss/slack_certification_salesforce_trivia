/**
 * OpenAI Responses API question generator. Uses Named Credential `OpenAI`.
 * Model is read from App_Setting__mdt.OpenAI_Model__c (default gpt-4.1-mini).
 */
public with sharing class OpenAIQuestionProvider implements QuestionGenerationProvider {

    public String name() { return 'openai'; }

    public String generate(String examCode, List<String> domains, String difficulty, Integer count) {
        App_Setting__mdt s = AppSettings.get();
        String model = String.isBlank(s.Default_Model__c) ? 'gpt-4.1-mini' : s.Default_Model__c;

        String prompt = buildPrompt(examCode, domains, difficulty, count);
        Map<String, Object> body = new Map<String, Object>{
            'model' => model,
            'input' => prompt,
            'temperature' => 0.4,
            'max_output_tokens' => 4000
        };

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:OpenAI/v1/responses');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(120000);
        req.setBody(JSON.serialize(body));

        HttpResponse resp;
        try {
            resp = new Http().send(req);
        } catch (Exception e) {
            AppLogger.error('OpenAIQuestionProvider', 'generate', 'callout failure', e);
            throw new CalloutException('OpenAI callout failed: ' + e.getMessage());
        }
        if (resp.getStatusCode() < 200 || resp.getStatusCode() > 299) {
            AppLogger.warn('OpenAIQuestionProvider', 'generate', 'HTTP ' + resp.getStatusCode() + ': ' + resp.getBody());
            throw new CalloutException('OpenAI non-2xx: ' + resp.getStatusCode());
        }
        return extractJson(resp.getBody());
    }

    @TestVisible
    private static String buildPrompt(String examCode, List<String> domains, String difficulty, Integer count) {
        String schema = '{ '
            + '"exam": { "code": "<exam code>", "name": "<exam name>", "vendor": "Salesforce" }, '
            + '"questionBank": { "externalId": "BANK-<exam>-<yyyymmddhhmm>", "name": "<short pack name>", '
            +   '"version": "1.0.0", "sourceType": "Generated", "status": "Draft" }, '
            + '"questions": [ { '
            +   '"externalId": "<exam>-Q<n>", '
            +   '"domain": "<one of the listed domains>", '
            +   '"difficulty": "<Beginner|Intermediate|Advanced>", '
            +   '"questionType": "Single Select", '
            +   '"question": "<one-sentence stem>", '
            +   '"scenarioText": "<optional 1-3 sentence scenario, may be empty>", '
            +   '"choices": ['
            +     ' { "label": "A", "text": "...", "isCorrect": false, "explanation": "<why this is wrong>" },'
            +     ' { "label": "B", "text": "...", "isCorrect": true,  "explanation": "<why this is right>" },'
            +     ' { "label": "C", "text": "...", "isCorrect": false, "explanation": "<why this is wrong>" },'
            +     ' { "label": "D", "text": "...", "isCorrect": false, "explanation": "<why this is wrong>" }'
            +   ' ], '
            +   '"explanation": "<2-4 sentence overall explanation a candidate would learn from>", '
            +   '"primaryReferenceUrl": "<single canonical Salesforce docs URL>", '
            +   '"referenceSummary": "<one-sentence summary of what the reference covers>", '
            +   '"keywords": "<comma-separated keywords>", '
            +   '"citations": ['
            +     ' { "title": "<doc title>", "url": "<full URL>", "sourceType": "Salesforce Help", '
            +       '"relevanceNote": "<why this source backs the answer>" }'
            +   ' ]'
            + ' } ] }';

        return 'You are generating Salesforce certification trivia questions. '
             + 'Respond ONLY with raw JSON (no Markdown fence, no commentary) matching this schema:\n'
             + schema + '\n\n'
             + 'Rules:\n'
             + '- Exactly one correct choice per Single Select question.\n'
             + '- Provide 4 choices per question (A-D).\n'
             + '- Every choice must have a non-empty explanation.\n'
             + '- Every question must include at least one citation to official Salesforce documentation.\n'
             + '- Use the actual exam code and a plausible exam name; the importer will upsert by code.\n'
             + '- Question externalIds must be unique within the pack.\n\n'
             + 'Exam code: ' + examCode + '.\n'
             + (domains == null || domains.isEmpty() ? '' : 'Bias toward these domains (spread questions across them): ' + String.join(domains, ', ') + '.\n')
             + (String.isBlank(difficulty) ? 'Difficulty: mix of Beginner / Intermediate / Advanced.\n' : 'Difficulty: ' + difficulty + ' for every question.\n')
             + 'Number of questions: ' + count + '.';
    }

    @TestVisible
    private static String extractJson(String responseBody) {
        // OpenAI Responses API: output[0].content[0].text
        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
        Object output = parsed.get('output');
        if (output instanceof List<Object>) {
            List<Object> arr = (List<Object>) output;
            if (!arr.isEmpty()) {
                Map<String, Object> first = (Map<String, Object>) arr[0];
                Object content = first.get('content');
                if (content instanceof List<Object>) {
                    List<Object> contentArr = (List<Object>) content;
                    if (!contentArr.isEmpty()) {
                        Map<String, Object> c0 = (Map<String, Object>) contentArr[0];
                        if (c0.containsKey('text')) return (String) c0.get('text');
                    }
                }
            }
        }
        return responseBody;
    }
}