/**
 * Stub providers — same shape as OpenAIQuestionProvider, ready to wire Named Credentials to.
 * Implement when those services are configured.
 */
public with sharing class GeminiQuestionProvider implements QuestionGenerationProvider {
    public String name() { return 'gemini'; }
    public String generate(String examCode, List<String> domains, String difficulty, Integer count) {
        throw new CalloutException('Gemini provider not yet implemented.');
    }
}