/**
 * Orchestrates a Slack-driven game session: start quick game, present question, record answer,
 * close round, advance, and finalize.
 *
 * All Block Kit JSON is delegated to CertGameSlackRenderService.
 * Slack response strings returned by entry points are returned to the router.
 *
 * Sharing: `without sharing` — all entry points are invoked by the Slack public-site
 * Guest User which has no record-level access to Game_Session__c / Game_Round__c. Player
 * identity comes from the verified Slack signature, not from the running SF user, so
 * row-level sharing is not the access control boundary for this service.
 */
public without sharing class CertGameSessionService {

    public class SessionException extends Exception {}

    private static final Integer DEFAULT_TIMER_SEC = 30;

    public static String startQuickGameFromSlack(String slackTeamId, String slackUserId, String slackChannelId, List<String> args) {
        Tenant__c tenant = CertGameTenantService.getOrCreateTenant(slackTeamId);
        if (!EntitlementGuard.canStartGame(tenant.Id)) {
            return CertGameSlackRenderService.text(CertGameStrings.QUOTA_REACHED, true);
        }
        Player__c player = CertGameTenantService.getOrCreatePlayer(tenant.Id, slackUserId);

        String examCode = args != null && args.size() > 1 ? args[1] : null;
        Certification_Exam__c exam = pickExam(examCode);
        if (exam == null) return CertGameSlackRenderService.text(CertGameStrings.NO_EXAM, true);

        Game_Session__c session = new Game_Session__c(
            Tenant__c = tenant.Id,
            Certification_Exam__c = exam.Id,
            Slack_Channel_Id__c = slackChannelId,
            Slack_Team_Id__c = slackTeamId,
            Started_By_Slack_User_Id__c = slackUserId,
            Mode__c = 'Solo',
            Status__c = 'Active',
            Started_At__c = System.now(),
            Timer_Seconds__c = DEFAULT_TIMER_SEC,
            Total_Questions__c = 5,
            Current_Question_Index__c = 0
        );
        new SessionDml().insertSession(session);

        Game_Round__c round = openNextRound(session, player, 1);
        return renderRound(session, round);
    }

    // Guest user sharing applies to Tenant__c / Certification_Exam__c lookups
    // independently of `as system`, so cross-tenant inserts run here.
    private without sharing class SessionDml {
        // `as system` bypasses Guest user cross-reference checks on the parent lookups
        // (Tenant__c, Certification_Exam__c, Game_Session__c, Trivia_Question__c).
        public void insertSession(Game_Session__c s) { insert as system s; }
        public void insertRound(Game_Round__c r) { insert as system r; }
        public Certification_Exam__c pickExam(String code) {
            if (!String.isBlank(code)) {
                List<Certification_Exam__c> exams = [SELECT Id, Name, Certification_Code__c FROM Certification_Exam__c
                                                      WHERE Certification_Code__c = :code LIMIT 1];
                return exams.isEmpty() ? null : exams[0];
            }
            List<Certification_Exam__c> exams = [SELECT Id, Name, Certification_Code__c FROM Certification_Exam__c
                                                  WHERE Active__c = true ORDER BY Name LIMIT 1];
            return exams.isEmpty() ? null : exams[0];
        }
    }

    public static String recordAnswerFromSlack(String slackTeamId, String slackUserId, String roundId, String choiceId) {
        if (String.isBlank(roundId) || String.isBlank(choiceId)) {
            return CertGameSlackRenderService.text(CertGameStrings.GENERIC_ERROR, true);
        }

        GameReader reader = new GameReader();
        Game_Round__c round = reader.roundById(roundId);
        if (round == null) return CertGameSlackRenderService.text(CertGameStrings.GENERIC_ERROR, true);

        Player__c player = CertGameTenantService.getOrCreatePlayer(round.Game_Session__r.Tenant__c, slackUserId);
        String uniqueKey = round.Id + ':' + player.Id;

        List<Trivia_Answer_Choice__c> choices = reader.choicesForQuestion(round.Trivia_Question__c);
        Trivia_Answer_Choice__c picked;
        Trivia_Answer_Choice__c correct;
        for (Trivia_Answer_Choice__c c : choices) {
            if (c.Id == (Id) choiceId) picked = c;
            if (c.Is_Correct__c) correct = c;
        }
        if (picked == null) return CertGameSlackRenderService.text(CertGameStrings.GENERIC_ERROR, true);

        Trivia_Question__c qSnap = reader.questionById(round.Trivia_Question__c);

        Integer timerSec = round.Game_Session__r.Timer_Seconds__c == null
                              ? DEFAULT_TIMER_SEC : round.Game_Session__r.Timer_Seconds__c.intValue();
        Integer elapsedSec = elapsedSeconds(round);
        Integer timeRemaining = Math.max(0, timerSec - elapsedSec);
        Integer streak = readStreak(player.Id, round.Game_Session__c);

        CertGameScoringService.Input scoreIn = new CertGameScoringService.Input();
        scoreIn.correct = picked.Is_Correct__c;
        scoreIn.difficulty = readDifficulty(round.Trivia_Question__c);
        scoreIn.timeRemainingSec = timeRemaining;
        scoreIn.timeLimitSec = timerSec;
        scoreIn.streakLength = streak;
        scoreIn.penaltyEnabled = false;
        CertGameScoringService.Output o = CertGameScoringService.score(scoreIn);

        Player_Answer__c pa = new Player_Answer__c(
            Game_Round__c = round.Id,
            Game_Session__c = round.Game_Session__c,
            Player__c = player.Id,
            Trivia_Question__c = round.Trivia_Question__c,
            Selected_Choice__c = picked.Id,
            Selected_Choice_Text__c = clip255(picked.Choice_Text__c),
            Selected_Choice_Labels__c = picked.Choice_Label__c,
            Is_Correct__c = picked.Is_Correct__c,
            Points_Awarded__c = o.pointsAwarded,
            Answered_At__c = System.now(),
            Response_Time_Ms__c = elapsedSec * 1000,
            Unique_Key__c = uniqueKey,
            Question_Domain__c = (qSnap != null && qSnap.Exam_Domain__r != null) ? clip255(qSnap.Exam_Domain__r.Name) : null,
            Question_Difficulty__c = qSnap == null ? null : qSnap.Difficulty__c,
            Question_Keywords__c = qSnap == null ? null : qSnap.Keywords__c,
            Question_Tags__c = qSnap == null ? null : qSnap.Tags__c,
            Misconception_Tag__c = (picked.Is_Correct__c == false) ? picked.Misconception_Tag__c : null
        );
        try {
            Database.UpsertResult ur = Database.upsert(pa, Player_Answer__c.Unique_Key__c, false, AccessLevel.SYSTEM_MODE);
            if (!ur.isSuccess()) {
                Boolean isDup = false;
                String firstErr = '';
                for (Database.Error err : ur.getErrors()) {
                    firstErr = err.getStatusCode() + ': ' + err.getMessage();
                    if (err.getStatusCode() == StatusCode.DUPLICATE_VALUE) isDup = true;
                }
                if (isDup) return CertGameSlackRenderService.alreadyAnsweredBlocks();
                AppLogger.warn('CertGameSessionService', 'recordAnswerFromSlack.upsert',
                    'roundId=' + roundId + ' choiceId=' + choiceId + ' err=' + firstErr);
                return CertGameSlackRenderService.text(CertGameStrings.GENERIC_ERROR, true);
            }
        } catch (Exception e) {
            AppLogger.error('CertGameSessionService', 'recordAnswerFromSlack.upsertEx',
                'roundId=' + roundId + ' choiceId=' + choiceId, e);
            return CertGameSlackRenderService.text(CertGameStrings.GENERIC_ERROR, true);
        }

        EventBus.publish(new QuestionAnswered__e(
            Session_Id__c = round.Game_Session__c,
            Round_Id__c = round.Id,
            Player_Id__c = player.Id,
            Is_Correct__c = pa.Is_Correct__c,
            Points__c = pa.Points_Awarded__c
        ));

        try {
            CertGamePlayerInsightsService.recordAnswerInsights(player.Id, qSnap, picked, picked.Is_Correct__c);
        } catch (Exception insightsEx) {
            AppLogger.warn('CertGameSessionService', 'recordAnswerFromSlack.insights', insightsEx.getMessage());
        }

        List<Map<String, Object>> cites = new List<Map<String, Object>>();
        for (Question_Citation__c c : reader.citationsForQuestion(round.Trivia_Question__c)) {
            cites.add(new Map<String, Object>{ 'id' => c.Id, 'title' => c.Title__c, 'url' => c.URL__c });
        }

        // Running tallies for the result card
        Integer runningPts = 0, answeredCnt = 0, correctCnt = 0;
        for (Player_Answer__c row : [
            SELECT Points_Awarded__c, Is_Correct__c
            FROM Player_Answer__c
            WHERE Game_Session__c = :round.Game_Session__c AND Player__c = :player.Id
        ]) {
            answeredCnt++;
            if (row.Points_Awarded__c != null) runningPts += row.Points_Awarded__c.intValue();
            if (row.Is_Correct__c) correctCnt++;
        }

        Trivia_Question__c qForExp = qSnap == null ? reader.questionById(round.Trivia_Question__c) : qSnap;
        String explanation = qForExp == null ? null : qForExp.Explanation__c;
        explanation = enrichExplanation(explanation, picked, correct, qForExp);

        // Result blocks
        Map<String, Object> resultEnv = (Map<String, Object>) JSON.deserializeUntyped(
            CertGameSlackRenderService.resultBlocks(
                picked.Is_Correct__c,
                correct == null ? '' : correct.Choice_Text__c,
                o.pointsAwarded,
                cites,
                explanation,
                runningPts,
                correctCnt,
                answeredCnt
            )
        );
        List<Object> combined = new List<Object>();
        combined.addAll((List<Object>) resultEnv.get('blocks'));

        // Advance the session: increment question index. If more questions remain,
        // open the next round and append its question card. Otherwise mark the
        // session complete and append a finale block.
        Game_Session__c sess = round.Game_Session__r;
        Integer totalQ = sess.Total_Questions__c == null ? 5 : sess.Total_Questions__c.intValue();
        Integer curIdx = sess.Current_Question_Index__c == null ? 0 : sess.Current_Question_Index__c.intValue();
        Integer newIdx = curIdx + 1;

        Game_Session__c sessUpdate = new Game_Session__c(Id = sess.Id, Current_Question_Index__c = newIdx);
        combined.add(new Map<String, Object>{ 'type' => 'divider' });

        if (newIdx < totalQ) {
            Game_Session__c freshSess = [
                SELECT Id, Tenant__c, Certification_Exam__c, Timer_Seconds__c, Total_Questions__c, Current_Question_Index__c
                FROM Game_Session__c WHERE Id = :sess.Id LIMIT 1
            ];
            // DB still has the pre-advance index (we update at end of txn). Reflect the
            // advance in-memory so renderRound shows the correct "Q N of M" label.
            freshSess.Current_Question_Index__c = newIdx;
            Game_Round__c nextRound = openNextRound(freshSess, player, newIdx + 1);
            String nextEnv = renderRound(freshSess, nextRound);
            Map<String, Object> nextMap = (Map<String, Object>) JSON.deserializeUntyped(nextEnv);
            List<Object> nextBlocks = (List<Object>) nextMap.get('blocks');
            if (nextBlocks != null) combined.addAll(nextBlocks);
        } else {
            sessUpdate.Status__c = 'Complete';
            sessUpdate.Completed_At__c = System.now();
            if (sess.Mode__c == 'Duel') {
                // Fire-and-forget finale check. DML on sessUpdate happens just below;
                // the @future inside onSessionComplete defers the Slack callout to a
                // fresh transaction so it sees the Status__c='Complete' update.
                CertGameDuelService.onSessionComplete(sess.Id);
            }
            String examCode = null;
            for (Certification_Exam__c ex : [SELECT Certification_Code__c FROM Certification_Exam__c WHERE Id = :sess.Certification_Exam__c LIMIT 1]) {
                examCode = ex.Certification_Code__c;
            }
            Map<String, Object> gameOverEnv = (Map<String, Object>) JSON.deserializeUntyped(
                CertGameSlackRenderService.gameOverBlocks(runningPts, correctCnt, totalQ, examCode)
            );
            combined.addAll((List<Object>) gameOverEnv.get('blocks'));
        }
        update as system sessUpdate;

        return JSON.serialize(new Map<String, Object>{
            'response_type' => 'in_channel',
            'blocks' => combined
        });
    }

    // ---------- helpers ----------
    private static Certification_Exam__c pickExam(String code) {
        return new SessionDml().pickExam(code);
    }

    private static Game_Round__c openNextRound(Game_Session__c session, Player__c player, Integer roundNum) {
        List<CertGameQuestionService.Pick> picks = CertGameQuestionService.pickQuestions(
            session.Tenant__c, session.Certification_Exam__c, null, null, player.Id, 1
        );
        if (picks.isEmpty()) throw new SessionException(CertGameStrings.NO_QUESTIONS);
        Game_Round__c r = new Game_Round__c(
            Game_Session__c = session.Id,
            Trivia_Question__c = picks[0].questionId,
            Round_Number__c = roundNum,
            Status__c = 'Posted',
            Started_At__c = System.now()
        );
        new SessionDml().insertRound(r);
        return r;
    }

    private static String renderRound(Game_Session__c session, Game_Round__c round) {
        GameReader reader = new GameReader();
        Trivia_Question__c q = reader.questionById(round.Trivia_Question__c);
        if (q == null) return CertGameSlackRenderService.text(CertGameStrings.GENERIC_ERROR, true);
        List<Map<String, Object>> choices = new List<Map<String, Object>>();
        for (Trivia_Answer_Choice__c c : reader.choicesForQuestion(round.Trivia_Question__c)) {
            choices.add(new Map<String, Object>{ 'id' => c.Id, 'label' => c.Choice_Label__c, 'text' => c.Choice_Text__c });
        }
        Integer timer = session.Timer_Seconds__c == null ? DEFAULT_TIMER_SEC : session.Timer_Seconds__c.intValue();
        Integer totalQ = session.Total_Questions__c == null ? 5 : session.Total_Questions__c.intValue();
        Integer qNum = (session.Current_Question_Index__c == null ? 0 : session.Current_Question_Index__c.intValue()) + 1;
        return CertGameSlackRenderService.questionBlocks(round.Id, q.Question_Text__c, choices, timer, qNum, totalQ, q.Difficulty__c);
    }

    private static Integer elapsedSeconds(Game_Round__c r) {
        if (r.Started_At__c == null) return 0;
        Long elapsed = (System.now().getTime() - r.Started_At__c.getTime()) / 1000L;
        return elapsed < 0 ? 0 : elapsed.intValue();
    }

    private static Integer readStreak(Id playerId, Id sessionId) {
        Integer streak = 0;
        for (Player_Answer__c pa : new GameReader().streakAnswers(playerId, sessionId)) {
            if (pa.Is_Correct__c) streak++;
            else break;
        }
        return streak;
    }

    private static String readDifficulty(Id questionId) {
        Trivia_Question__c q = new GameReader().questionById(questionId);
        return q == null ? 'Medium' : q.Difficulty__c;
    }

    private static String clip255(String s) {
        if (s == null) return null;
        return s.length() > 255 ? s.substring(0, 255) : s;
    }

    private static String enrichExplanation(String base, Trivia_Answer_Choice__c picked,
            Trivia_Answer_Choice__c correctChoice, Trivia_Question__c q) {
        List<String> parts = new List<String>();
        if (String.isNotBlank(base)) parts.add(base);
        if (picked != null && picked.Is_Correct__c == false && String.isNotBlank(picked.Why_Incorrect__c)) {
            parts.add('Why your pick was wrong: ' + picked.Why_Incorrect__c);
        }
        if (correctChoice != null && String.isNotBlank(correctChoice.Direct_Statement__c)) {
            parts.add('Key idea: ' + correctChoice.Direct_Statement__c);
        }
        if (q != null && String.isNotBlank(q.Glossary_Terms__c)) {
            String gloss = formatGlossary(q.Glossary_Terms__c);
            if (String.isNotBlank(gloss)) parts.add('Glossary: ' + gloss);
        }
        if (q != null && String.isNotBlank(q.Primary_Reference_URL__c)) {
            parts.add('Reference: ' + q.Primary_Reference_URL__c);
        }
        return parts.isEmpty() ? null : String.join(parts, '\n\n');
    }

    private static String formatGlossary(String jsonStr) {
        try {
            Object parsed = JSON.deserializeUntyped(jsonStr);
            if (!(parsed instanceof List<Object>)) return null;
            List<String> bits = new List<String>();
            for (Object o : (List<Object>) parsed) {
                if (o instanceof Map<String, Object>) {
                    Map<String, Object> m = (Map<String, Object>) o;
                    String term = (String) m.get('term');
                    String def = (String) m.get('definition');
                    if (String.isNotBlank(term) && String.isNotBlank(def)) bits.add(term + ' — ' + def);
                }
            }
            return bits.isEmpty() ? null : String.join(bits, '; ');
        } catch (Exception e) {
            return null;
        }
    }

    // Guest-user reads must run in `without sharing`; WITH SYSTEM_MODE bypasses
    // CRUD/FLS but not record sharing.
    private without sharing class GameReader {
        public Game_Round__c roundById(String roundId) {
            List<Game_Round__c> rs = [
                SELECT Id, Game_Session__c, Trivia_Question__c, Started_At__c, Status__c,
                       Game_Session__r.Tenant__c, Game_Session__r.Certification_Exam__c,
                       Game_Session__r.Timer_Seconds__c, Game_Session__r.Mode__c,
                       Game_Session__r.Total_Questions__c, Game_Session__r.Current_Question_Index__c
                FROM Game_Round__c WHERE Id = :roundId LIMIT 1
            ];
            return rs.isEmpty() ? null : rs[0];
        }
        public Trivia_Question__c questionById(Id questionId) {
            List<Trivia_Question__c> qs = [
                SELECT Id, Question_Text__c, Difficulty__c, Explanation__c,
                       Keywords__c, Tags__c, Named_Entities__c, Glossary_Terms__c,
                       Primary_Reference_URL__c, Exam_Domain__c, Exam_Domain__r.Name
                FROM Trivia_Question__c
                WHERE Id = :questionId LIMIT 1
            ];
            return qs.isEmpty() ? null : qs[0];
        }
        public List<Trivia_Answer_Choice__c> choicesForQuestion(Id questionId) {
            return [
                SELECT Id, Is_Correct__c, Choice_Text__c, Choice_Label__c, Trivia_Question__c,
                       Explanation__c, Why_Incorrect__c, Direct_Statement__c, Misconception_Tag__c
                FROM Trivia_Answer_Choice__c
                WHERE Trivia_Question__c = :questionId ORDER BY Choice_Label__c
            ];
        }
        public List<Question_Citation__c> citationsForQuestion(Id questionId) {
            return [
                SELECT Id, Title__c, URL__c FROM Question_Citation__c
                WHERE Trivia_Question__c = :questionId LIMIT 5
            ];
        }
        public List<Player_Answer__c> streakAnswers(Id playerId, Id sessionId) {
            return [
                SELECT Is_Correct__c FROM Player_Answer__c
                WHERE Player__c = :playerId AND Game_Round__r.Game_Session__c = :sessionId
                ORDER BY Answered_At__c DESC LIMIT 50
            ];
        }
    }
}