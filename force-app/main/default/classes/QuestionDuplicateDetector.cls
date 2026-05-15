/**
 * Computes a normalized SHA-256 hash of a question + correct choice for duplicate detection.
 */
public with sharing class QuestionDuplicateDetector {

    public static String hash(String questionText, List<String> correctChoiceTexts) {
        String normalizedQ = normalize(questionText);
        List<String> sortedChoices = new List<String>();
        for (String c : correctChoiceTexts) sortedChoices.add(normalize(c));
        sortedChoices.sort();
        String payload = normalizedQ + '|' + String.join(sortedChoices, '|');
        Blob digest = Crypto.generateDigest('SHA-256', Blob.valueOf(payload));
        return EncodingUtil.convertToHex(digest);
    }

    public static String hash(Trivia_Question__c q, List<Trivia_Answer_Choice__c> choices) {
        List<String> correct = new List<String>();
        for (Trivia_Answer_Choice__c c : choices) {
            if (c.Is_Correct__c == true) correct.add(c.Choice_Text__c);
        }
        return hash(q.Question_Text__c, correct);
    }

    public static Set<String> findDuplicateHashes(Set<String> hashes) {
        Set<String> dupes = new Set<String>();
        if (hashes == null || hashes.isEmpty()) return dupes;
        for (AggregateResult ar : [
            SELECT Hash__c h, COUNT(Id) cnt
            FROM Trivia_Question__c
            WHERE Hash__c IN :hashes
            GROUP BY Hash__c
            HAVING COUNT(Id) > 0
        ]) {
            dupes.add((String) ar.get('h'));
        }
        return dupes;
    }

    private static String normalize(String s) {
        if (s == null) return '';
        return s.toLowerCase().replaceAll('\\s+', ' ').trim();
    }
}
