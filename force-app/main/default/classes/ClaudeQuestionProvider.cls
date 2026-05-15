public with sharing class ClaudeQuestionProvider implements QuestionGenerationProvider {
    public String name() { return 'claude'; }
    public String generate(String examCode, List<String> domains, String difficulty, Integer count) {
        throw new CalloutException('Claude provider not yet implemented.');
    }
}
