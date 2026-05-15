/**
 * OpenAI Responses API question generator. Uses Named Credential `OpenAI`.
 * Model is read from App_Setting__mdt.OpenAI_Model__c (default gpt-4.1-mini).
 */
public with sharing class OpenAIQuestionProvider implements QuestionGenerationProvider {

    public String name() { return 'openai'; }

    public String generate(String examCode, List<String> domains, String difficulty, Integer count) {
        App_Setting__mdt s = AppSettings.get();
        String model = String.isBlank(s.OpenAI_Model__c) ? 'gpt-4.1-mini' : s.OpenAI_Model__c;

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
        return 'You are generating Salesforce certification trivia questions. '
             + 'Respond ONLY with JSON matching this schema: { "exam": { "code": "...", "name": "..." }, '
             + '"questionBank": { "externalId": "...", "name": "..." }, '
             + '"questions": [ { "externalId": "...", "domain": "...", "difficulty": "...", "questionType": "Single Select", '
             + '"questionText": "...", "scenarioText": "...", "choices": [ { "label": "A", "text": "...", "isCorrect": false } ], '
             + '"citations": [ { "title": "...", "url": "...", "sourceType": "Official Docs" } ] } ] }. '
             + 'Exam code: ' + examCode + '. '
             + (domains == null || domains.isEmpty() ? '' : 'Domains: ' + String.join(domains, ', ') + '. ')
             + (String.isBlank(difficulty) ? '' : 'Difficulty: ' + difficulty + '. ')
             + 'Number of questions: ' + count + '. Each question must include at least one citation to official Salesforce docs.';
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
