/**
 * Selects questions for a round: filters by exam, domain(s), difficulty, prefers questions
 * the player has not recently seen. All reads are bulkified.
 */
public with sharing class CertGameQuestionService {

    public class Pick {
        public Id questionId;
        public String questionText;
        public String scenarioText;
        public String difficulty;
        public List<Map<String, Object>> choices; // id, label, text, isCorrect
        public List<Map<String, Object>> citations; // id, title, url
    }

    /**
     * @param tenantId Tenant for scoping
     * @param examId Exam to draw from
     * @param domainIds optional filter
     * @param difficulty optional filter
     * @param playerId optional to avoid recent repeats
     * @param limitN how many
     */
    public static List<Pick> pickQuestions(Id tenantId, Id examId, Set<Id> domainIds, String difficulty, Id playerId, Integer limitN) {
        if (limitN == null || limitN < 1) limitN = 5;
        return new QuestionReader().pick(tenantId, examId, domainIds, difficulty, playerId, limitN);
    }

    // Guest-user-safe reader. Trivia_Question__c and Player_Answer__c are
    // Tenant-scoped via lookup chains; the Site Guest User has no record
    // sharing on them. WITH SYSTEM_MODE bypasses CRUD/FLS but NOT sharing,
    // so we must run these reads in a without-sharing context.
    private without sharing class QuestionReader {
        public List<Pick> pick(Id tenantId, Id examId, Set<Id> domainIds, String difficulty, Id playerId, Integer limitN) {
            Set<Id> recent = new Set<Id>();
            if (playerId != null) {
                DateTime cutoff = System.now().addDays(-7);
                for (Player_Answer__c pa : [
                    SELECT Trivia_Question__c FROM Player_Answer__c
                    WHERE Player__c = :playerId AND CreatedDate >= :cutoff
                    LIMIT 500
                ]) {
                    if (pa.Trivia_Question__c != null) recent.add(pa.Trivia_Question__c);
                }
            }

            String soql =
                'SELECT Id, Question_Text__c, Scenario_Text__c, Difficulty__c, Question_Type__c, '
              + ' (SELECT Id, Choice_Label__c, Choice_Text__c, Is_Correct__c FROM Choices__r ORDER BY Choice_Label__c), '
              + ' (SELECT Id, Title__c, URL__c FROM Citations__r) '
              + 'FROM Trivia_Question__c '
              + 'WHERE Status__c = \'Published\' AND Certification_Exam__c = :examId';
            if (domainIds != null && !domainIds.isEmpty()) soql += ' AND Exam_Domain__c IN :domainIds';
            if (!String.isBlank(difficulty)) soql += ' AND Difficulty__c = :difficulty';
            String soqlWithRecent = soql + (recent.isEmpty() ? '' : ' AND Id NOT IN :recent') + ' LIMIT 200';

            List<Trivia_Question__c> rows = Database.query(soqlWithRecent);
            // If the recent-answer filter exhausts the bank, allow repeats rather than
            // failing the game start with a misleading "no questions" error.
            if (rows.isEmpty() && !recent.isEmpty()) {
                rows = Database.query(soql + ' LIMIT 200');
            }
            List<Trivia_Question__c> shuffled = shuffle(rows);
            List<Pick> picks = new List<Pick>();
            for (Integer i = 0; i < Math.min(limitN, shuffled.size()); i++) {
                picks.add(toPick(shuffled[i]));
            }
            return picks;
        }
    }

    public static Pick toPick(Trivia_Question__c q) {
        Pick p = new Pick();
        p.questionId = q.Id;
        p.questionText = q.Question_Text__c;
        p.scenarioText = q.Scenario_Text__c;
        p.difficulty = q.Difficulty__c;
        p.choices = new List<Map<String, Object>>();
        for (Trivia_Answer_Choice__c c : q.Choices__r) {
            p.choices.add(new Map<String, Object>{
                'id' => c.Id,
                'label' => c.Choice_Label__c,
                'text' => c.Choice_Text__c,
                'isCorrect' => c.Is_Correct__c
            });
        }
        p.citations = new List<Map<String, Object>>();
        for (Question_Citation__c ct : q.Citations__r) {
            p.citations.add(new Map<String, Object>{
                'id' => ct.Id, 'title' => ct.Title__c, 'url' => ct.URL__c
            });
        }
        return p;
    }

    private static List<Trivia_Question__c> shuffle(List<Trivia_Question__c> src) {
        List<Trivia_Question__c> copy = new List<Trivia_Question__c>(src);
        for (Integer i = copy.size() - 1; i > 0; i--) {
            Integer j = Math.mod(Math.abs(Crypto.getRandomInteger()), i + 1);
            Trivia_Question__c tmp = copy[i];
            copy[i] = copy[j];
            copy[j] = tmp;
        }
        return copy;
    }
}