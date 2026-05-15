/**
 * Resolves the active question generation provider from App_Setting__mdt.Default_Provider__c.
 * @TestVisible providerOverride lets tests inject mocks.
 */
public with sharing class QuestionGenerationProviderFactory {

    @TestVisible private static QuestionGenerationProvider providerOverride;

    public static QuestionGenerationProvider provider() {
        if (providerOverride != null) return providerOverride;
        String name = AppSettings.get().Default_Provider__c;
        if (String.isBlank(name)) name = 'openai';
        name = name.toLowerCase();
        if (name == 'openai') return new OpenAIQuestionProvider();
        if (name == 'gemini') return new GeminiQuestionProvider();
        if (name == 'claude') return new ClaudeQuestionProvider();
        throw new TypeException('Unknown question generation provider: ' + name);
    }
}
