/**
 * Provider interface for AI question generation. Implementations call their respective
 * Named Credential and return a normalized JSON pack matching the Cert Game schema.
 */
public interface QuestionGenerationProvider {
    /**
     * @param examCode e.g., ADM-201
     * @param domains list of domain names (optional)
     * @param difficulty Easy | Medium | Hard | Mixed
     * @param count number of questions to generate
     * @return JSON string in the same format as the question pack schema
     */
    String generate(String examCode, List<String> domains, String difficulty, Integer count);

    /** Provider name for telemetry / settings, e.g., 'openai', 'gemini', 'claude'. */
    String name();
}