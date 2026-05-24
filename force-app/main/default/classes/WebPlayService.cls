/**
 * Game logic for the public web app. Self-contained, decoupled from Slack.
 * All methods accept a verified playerId from WebApiRestResource (token-authenticated).
 */
public without sharing class WebPlayService {

    public class PlayException extends Exception {}

    public class ExamDTO {
        public String id; public String code; public String name;
        public ExamDTO(Certification_Exam__c e) {
            this.id = e.Id; this.code = e.Certification_Code__c; this.name = e.Name;
        }
    }

    public class ChoiceDTO {
        public String id; public String label; public String text;
    }

    public class RoundDTO {
        public String sessionId;
        public String roundId;
        public Integer roundNumber;
        public Integer totalRounds;
        public String questionText;
        public String scenarioText;
        public String difficulty;
        public List<ChoiceDTO> choices;
        public Boolean finished;
    }

    public class AnswerDTO {
        public Boolean correct;
        public String correctChoiceId;
        public String correctChoiceLabel;
        public String explanation;
        public Integer pointsAwarded;
        public RoundDTO next; // null when session complete
        public SessionSummaryDTO summary; // populated when finished
    }

    public class SessionSummaryDTO {
        public String sessionId;
        public Integer totalAnswered;
        public Integer totalCorrect;
        public Integer totalPoints;
        public Decimal accuracy;
    }

    public class PlayerStatsDTO {
        public String playerId;
        public String name;
        public String email;
        public String pictureUrl;
        public Integer totalAnswers;
        public Integer totalCorrect;
        public Integer totalPoints;
        public Decimal accuracy;
        public DateTime lastPlayedAt;
        public List<WeakSpotDTO> weakSpots;
    }

    public class WeakSpotDTO {
        public String questionId;
        public String questionText;
        public Integer wrongCount;
        public Integer totalAttempts;
    }

    public static List<ExamDTO> listExams() {
        List<ExamDTO> out = new List<ExamDTO>();
        for (Certification_Exam__c e : [
            SELECT Id, Name, Certification_Code__c
            FROM Certification_Exam__c
            WHERE Active__c = true
            ORDER BY Name
            LIMIT 200
        ]) {
            out.add(new ExamDTO(e));
        }
        return out;
    }

    public static RoundDTO startSession(Id playerId, Id examId, Integer numQuestions) {
        if (numQuestions == null || numQuestions < 1) numQuestions = 5;
        if (numQuestions > 25) numQuestions = 25;

        List<Trivia_Question__c> pool = [
            SELECT Id
            FROM Trivia_Question__c
            WHERE Certification_Exam__c = :examId AND Status__c = 'Published'
        ];
        if (pool.isEmpty()) throw new PlayException('No published questions for this exam.');

        // Shuffle (simple Fisher–Yates with Math.random)
        List<Id> ids = new List<Id>();
        for (Trivia_Question__c q : pool) ids.add(q.Id);
        for (Integer i = ids.size() - 1; i > 0; i--) {
            Integer j = Math.mod(Math.abs(Crypto.getRandomInteger()), i + 1);
            Id tmp = ids[i]; ids[i] = ids[j]; ids[j] = tmp;
        }
        Integer pick = Math.min(numQuestions, ids.size());
        List<Id> chosen = new List<Id>();
        for (Integer i = 0; i < pick; i++) chosen.add(ids[i]);

        Game_Session__c sess = new Game_Session__c(
            Certification_Exam__c = examId,
            Mode__c = 'Web',
            Status__c = 'Active',
            Started_At__c = System.now(),
            Timer_Seconds__c = 0,
            Total_Questions__c = pick,
            Current_Question_Index__c = 0,
            Slack_Channel_Id__c = 'WEB'
        );
        insert as system sess;

        List<Game_Round__c> rounds = new List<Game_Round__c>();
        for (Integer i = 0; i < chosen.size(); i++) {
            rounds.add(new Game_Round__c(
                Game_Session__c = sess.Id,
                Trivia_Question__c = chosen[i],
                Round_Number__c = i + 1,
                Status__c = 'Posted',
                Started_At__c = System.now()
            ));
        }
        insert as system rounds;

        return buildRoundDTO(sess.Id, playerId);
    }

    public static RoundDTO nextRound(Id playerId, Id sessionId) {
        return buildRoundDTO(sessionId, playerId);
    }

    private static RoundDTO buildRoundDTO(Id sessionId, Id playerId) {
        Game_Session__c sess = [
            SELECT Id, Total_Questions__c, Current_Question_Index__c, Status__c
            FROM Game_Session__c WHERE Id = :sessionId LIMIT 1
        ];
        List<Game_Round__c> rounds = [
            SELECT Id, Round_Number__c, Trivia_Question__c, Status__c
            FROM Game_Round__c
            WHERE Game_Session__c = :sessionId
            ORDER BY Round_Number__c ASC
        ];
        Set<Id> answeredRoundIds = new Set<Id>();
        for (Player_Answer__c a : [
            SELECT Id, Game_Round__c FROM Player_Answer__c
            WHERE Game_Session__c = :sessionId AND Player__c = :playerId
        ]) answeredRoundIds.add(a.Game_Round__c);

        Game_Round__c nextR;
        for (Game_Round__c r : rounds) {
            if (!answeredRoundIds.contains(r.Id)) { nextR = r; break; }
        }
        RoundDTO dto = new RoundDTO();
        dto.sessionId = sessionId;
        dto.totalRounds = rounds.size();
        if (nextR == null) {
            dto.finished = true;
            return dto;
        }
        dto.roundId = nextR.Id;
        dto.roundNumber = nextR.Round_Number__c == null ? 0 : nextR.Round_Number__c.intValue();
        dto.finished = false;

        Trivia_Question__c q = [
            SELECT Id, Question_Text__c, Scenario_Text__c, Difficulty__c
            FROM Trivia_Question__c WHERE Id = :nextR.Trivia_Question__c LIMIT 1
        ];
        dto.questionText = q.Question_Text__c;
        dto.scenarioText = q.Scenario_Text__c;
        dto.difficulty = q.Difficulty__c;

        List<Trivia_Answer_Choice__c> choices = [
            SELECT Id, Choice_Label__c, Choice_Text__c
            FROM Trivia_Answer_Choice__c
            WHERE Trivia_Question__c = :nextR.Trivia_Question__c
            ORDER BY Sort_Order__c ASC NULLS LAST, Choice_Label__c ASC
        ];
        dto.choices = new List<ChoiceDTO>();
        for (Trivia_Answer_Choice__c c : choices) {
            ChoiceDTO cd = new ChoiceDTO();
            cd.id = c.Id; cd.label = c.Choice_Label__c; cd.text = c.Choice_Text__c;
            dto.choices.add(cd);
        }
        return dto;
    }

    public static AnswerDTO submitAnswer(Id playerId, Id roundId, Id choiceId) {
        Game_Round__c round = [
            SELECT Id, Game_Session__c, Trivia_Question__c, Round_Number__c
            FROM Game_Round__c WHERE Id = :roundId LIMIT 1
        ];
        List<Trivia_Answer_Choice__c> choices = [
            SELECT Id, Choice_Label__c, Choice_Text__c, Is_Correct__c
            FROM Trivia_Answer_Choice__c
            WHERE Trivia_Question__c = :round.Trivia_Question__c
        ];
        Trivia_Answer_Choice__c picked;
        Trivia_Answer_Choice__c correct;
        for (Trivia_Answer_Choice__c c : choices) {
            if (c.Id == choiceId) picked = c;
            if (c.Is_Correct__c) correct = c;
        }
        if (picked == null) throw new PlayException('Choice does not belong to this question.');

        String uniqueKey = roundId + ':' + playerId;
        Player_Answer__c pa = new Player_Answer__c(
            Game_Round__c = roundId,
            Game_Session__c = round.Game_Session__c,
            Player__c = playerId,
            Trivia_Question__c = round.Trivia_Question__c,
            Selected_Choice_Labels__c = picked.Choice_Label__c,
            Is_Correct__c = picked.Is_Correct__c,
            Points_Awarded__c = picked.Is_Correct__c ? 10 : 0,
            Answered_At__c = System.now(),
            Response_Time_Ms__c = 0,
            Unique_Key__c = uniqueKey
        );
        Database.UpsertResult ur = Database.upsert(pa, Player_Answer__c.Unique_Key__c, false, AccessLevel.SYSTEM_MODE);
        if (!ur.isSuccess()) {
            Boolean dup = false;
            for (Database.Error e : ur.getErrors()) {
                if (e.getStatusCode() == StatusCode.DUPLICATE_VALUE) dup = true;
            }
            if (!dup) throw new PlayException('Could not record answer.');
        }

        // Update player rollups (simple counters; defer expensive recalc to background).
        updatePlayerRollups(playerId);

        AnswerDTO out = new AnswerDTO();
        out.correct = picked.Is_Correct__c;
        out.correctChoiceId = correct == null ? null : correct.Id;
        out.correctChoiceLabel = correct == null ? null : correct.Choice_Label__c;
        out.pointsAwarded = picked.Is_Correct__c ? 10 : 0;
        Trivia_Question__c q = [SELECT Id, Explanation__c FROM Trivia_Question__c WHERE Id = :round.Trivia_Question__c LIMIT 1];
        out.explanation = q.Explanation__c;

        RoundDTO nxt = buildRoundDTO(round.Game_Session__c, playerId);
        if (nxt.finished) {
            // Finalize session
            Game_Session__c sess = new Game_Session__c(Id = round.Game_Session__c, Status__c = 'Complete', Completed_At__c = System.now());
            update as system sess;

            AggregateResult ar = [
                SELECT COUNT(Id) cnt, SUM(Points_Awarded__c) pts
                FROM Player_Answer__c
                WHERE Game_Session__c = :round.Game_Session__c AND Player__c = :playerId
            ];
            Integer corCnt = [
                SELECT COUNT() FROM Player_Answer__c
                WHERE Game_Session__c = :round.Game_Session__c AND Player__c = :playerId AND Is_Correct__c = true
            ];
            SessionSummaryDTO s = new SessionSummaryDTO();
            s.sessionId = round.Game_Session__c;
            s.totalAnswered = (Integer) ar.get('cnt');
            s.totalCorrect = corCnt;
            s.totalPoints = ar.get('pts') == null ? 0 : ((Decimal) ar.get('pts')).intValue();
            s.accuracy = s.totalAnswered == 0 ? 0 : (Decimal.valueOf(s.totalCorrect) / s.totalAnswered);
            out.summary = s;
            out.next = nxt;

            // Tournament rollup hook (no-op if session is not tied to a tournament).
            try { WebTournamentService.onSessionComplete(playerId, round.Game_Session__c); }
            catch (Exception ex) { AppLogger.error('WebPlayService', 'submitAnswer', 'tournament_rollup', ex); }
        } else {
            out.next = nxt;
        }
        return out;
    }

    public static PlayerStatsDTO getStats(Id playerId) {
        Player__c p = [
            SELECT Id, Display_Name__c, Google_Email__c, Google_Name__c, Google_Picture_URL__c,
                   Total_Points__c, Total_Games__c, Last_Played_At__c
            FROM Player__c WHERE Id = :playerId LIMIT 1
        ];
        PlayerStatsDTO d = new PlayerStatsDTO();
        d.playerId = p.Id;
        d.name = String.isBlank(p.Google_Name__c) ? p.Display_Name__c : p.Google_Name__c;
        d.email = p.Google_Email__c;
        d.pictureUrl = p.Google_Picture_URL__c;
        d.totalPoints = p.Total_Points__c == null ? 0 : p.Total_Points__c.intValue();
        d.lastPlayedAt = p.Last_Played_At__c;

        Integer totalCnt = [SELECT COUNT() FROM Player_Answer__c WHERE Player__c = :playerId];
        Integer corCnt = [SELECT COUNT() FROM Player_Answer__c WHERE Player__c = :playerId AND Is_Correct__c = true];
        d.totalAnswers = totalCnt;
        d.totalCorrect = corCnt;
        d.accuracy = d.totalAnswers == 0 ? 0 : (Decimal.valueOf(d.totalCorrect) / d.totalAnswers);

        // Wrong-answer frequency by question
        List<AggregateResult> wrong = [
            SELECT Trivia_Question__c qid, COUNT(Id) wrong
            FROM Player_Answer__c
            WHERE Player__c = :playerId AND Is_Correct__c = false
            GROUP BY Trivia_Question__c
            ORDER BY COUNT(Id) DESC
            LIMIT 10
        ];
        Set<Id> qIds = new Set<Id>();
        for (AggregateResult a : wrong) qIds.add((Id) a.get('qid'));
        Map<Id, Trivia_Question__c> qMap = new Map<Id, Trivia_Question__c>(
            [SELECT Id, Question_Text__c FROM Trivia_Question__c WHERE Id IN :qIds]
        );
        d.weakSpots = new List<WeakSpotDTO>();
        Map<Id, Integer> attemptsByQ = new Map<Id, Integer>();
        if (!qIds.isEmpty()) {
            for (AggregateResult a : [
                SELECT Trivia_Question__c qid, COUNT(Id) cnt
                FROM Player_Answer__c
                WHERE Player__c = :playerId AND Trivia_Question__c IN :qIds
                GROUP BY Trivia_Question__c
            ]) {
                attemptsByQ.put((Id) a.get('qid'), ((Integer) a.get('cnt')));
            }
        }
        for (AggregateResult a : wrong) {
            WeakSpotDTO w = new WeakSpotDTO();
            w.questionId = (Id) a.get('qid');
            Trivia_Question__c q = qMap.get(w.questionId);
            w.questionText = q == null ? null : q.Question_Text__c;
            w.wrongCount = ((Integer) a.get('wrong'));
            w.totalAttempts = attemptsByQ.containsKey(w.questionId) ? attemptsByQ.get(w.questionId) : w.wrongCount;
            d.weakSpots.add(w);
        }
        return d;
    }

    private static void updatePlayerRollups(Id playerId) {
        AggregateResult ar = [
            SELECT SUM(Points_Awarded__c) pts,
                   COUNT_DISTINCT(Game_Session__c) games,
                   MAX(Answered_At__c) lastAnsweredAt
            FROM Player_Answer__c WHERE Player__c = :playerId
        ];
        Player__c p = new Player__c(
            Id = playerId,
            Total_Points__c = ar.get('pts') == null ? 0 : ((Decimal) ar.get('pts')),
            Total_Games__c = ar.get('games') == null ? 0 : ((Integer) ar.get('games')),
            Last_Played_At__c = (DateTime) ar.get('lastAnsweredAt')
        );
        update as system p;
    }
}