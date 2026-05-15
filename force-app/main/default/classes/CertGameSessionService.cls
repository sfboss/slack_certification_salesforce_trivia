/**
 * Orchestrates a Slack-driven game session: start quick game, present question, record answer,
 * close round, advance, and finalize.
 *
 * All Block Kit JSON is delegated to CertGameSlackRenderService.
 * Slack response strings returned by entry points are returned to the router.
 */
public with sharing class CertGameSessionService {

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
        insert as user session;

        Game_Round__c round = openNextRound(session, player, 1);
        return renderRound(session, round);
    }

    public static String recordAnswerFromSlack(String slackTeamId, String slackUserId, String roundId, String choiceId) {
        if (String.isBlank(roundId) || String.isBlank(choiceId)) {
            return CertGameSlackRenderService.text(CertGameStrings.GENERIC_ERROR, true);
        }

        List<Game_Round__c> rs = [
            SELECT Id, Game_Session__c, Trivia_Question__c, Started_At__c, Status__c,
                   Game_Session__r.Tenant__c, Game_Session__r.Timer_Seconds__c
            FROM Game_Round__c WHERE Id = :roundId WITH USER_MODE LIMIT 1
        ];
        if (rs.isEmpty()) return CertGameSlackRenderService.text(CertGameStrings.GENERIC_ERROR, true);
        Game_Round__c round = rs[0];

        Player__c player = CertGameTenantService.getOrCreatePlayer(round.Game_Session__r.Tenant__c, slackUserId);
        String uniqueKey = round.Id + ':' + player.Id;

        List<Trivia_Answer_Choice__c> choices = [
            SELECT Id, Is_Correct__c, Choice_Text__c, Choice_Label__c, Trivia_Question__c
            FROM Trivia_Answer_Choice__c WHERE Trivia_Question__c = :round.Trivia_Question__c WITH USER_MODE
        ];
        Trivia_Answer_Choice__c picked;
        Trivia_Answer_Choice__c correct;
        for (Trivia_Answer_Choice__c c : choices) {
            if (c.Id == (Id) choiceId) picked = c;
            if (c.Is_Correct__c) correct = c;
        }
        if (picked == null) return CertGameSlackRenderService.text(CertGameStrings.GENERIC_ERROR, true);

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
            Selected_Choice_Labels__c = picked.Choice_Label__c,
            Is_Correct__c = picked.Is_Correct__c,
            Points_Awarded__c = o.pointsAwarded,
            Answered_At__c = System.now(),
            Response_Time_Ms__c = elapsedSec * 1000,
            Unique_Key__c = uniqueKey
        );
        try {
            Database.UpsertResult ur = Database.upsert(pa, Player_Answer__c.Unique_Key__c, false);
            if (!ur.isSuccess()) return CertGameSlackRenderService.text(CertGameStrings.ALREADY_ANSWERED, true);
        } catch (Exception e) {
            return CertGameSlackRenderService.text(CertGameStrings.ALREADY_ANSWERED, true);
        }

        EventBus.publish(new QuestionAnswered__e(
            Session_Id__c = round.Game_Session__c,
            Round_Id__c = round.Id,
            Player_Id__c = player.Id,
            Is_Correct__c = pa.Is_Correct__c,
            Points__c = pa.Points_Awarded__c
        ));

        List<Map<String, Object>> cites = new List<Map<String, Object>>();
        for (Question_Citation__c c : [
            SELECT Id, Title__c, URL__c FROM Question_Citation__c
            WHERE Trivia_Question__c = :round.Trivia_Question__c WITH USER_MODE LIMIT 5
        ]) {
            cites.add(new Map<String, Object>{ 'id' => c.Id, 'title' => c.Title__c, 'url' => c.URL__c });
        }

        return CertGameSlackRenderService.resultBlocks(
            picked.Is_Correct__c,
            correct == null ? '' : correct.Choice_Text__c,
            o.pointsAwarded,
            cites
        );
    }

    // ---------- helpers ----------
    private static Certification_Exam__c pickExam(String code) {
        if (!String.isBlank(code)) {
            List<Certification_Exam__c> exams = [SELECT Id, Name, Certification_Code__c FROM Certification_Exam__c
                                                  WHERE Certification_Code__c = :code WITH USER_MODE LIMIT 1];
            return exams.isEmpty() ? null : exams[0];
        }
        List<Certification_Exam__c> exams = [SELECT Id, Name, Certification_Code__c FROM Certification_Exam__c
                                              WHERE Active__c = true WITH USER_MODE ORDER BY Name LIMIT 1];
        return exams.isEmpty() ? null : exams[0];
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
        insert as user r;
        return r;
    }

    private static String renderRound(Game_Session__c session, Game_Round__c round) {
        List<Trivia_Question__c> qs = [
            SELECT Id, Question_Text__c FROM Trivia_Question__c
            WHERE Id = :round.Trivia_Question__c WITH USER_MODE LIMIT 1
        ];
        if (qs.isEmpty()) return CertGameSlackRenderService.text(CertGameStrings.GENERIC_ERROR, true);
        List<Trivia_Answer_Choice__c> cs = [
            SELECT Id, Choice_Label__c, Choice_Text__c FROM Trivia_Answer_Choice__c
            WHERE Trivia_Question__c = :round.Trivia_Question__c WITH USER_MODE ORDER BY Choice_Label__c
        ];
        List<Map<String, Object>> choices = new List<Map<String, Object>>();
        for (Trivia_Answer_Choice__c c : cs) {
            choices.add(new Map<String, Object>{ 'id' => c.Id, 'label' => c.Choice_Label__c, 'text' => c.Choice_Text__c });
        }
        Integer timer = session.Timer_Seconds__c == null ? DEFAULT_TIMER_SEC : session.Timer_Seconds__c.intValue();
        return CertGameSlackRenderService.questionBlocks(round.Id, qs[0].Question_Text__c, choices, timer);
    }

    private static Integer elapsedSeconds(Game_Round__c r) {
        if (r.Started_At__c == null) return 0;
        Long elapsed = (System.now().getTime() - r.Started_At__c.getTime()) / 1000L;
        return elapsed < 0 ? 0 : elapsed.intValue();
    }

    private static Integer readStreak(Id playerId, Id sessionId) {
        Integer streak = 0;
        for (Player_Answer__c pa : [
            SELECT Is_Correct__c FROM Player_Answer__c
            WHERE Player__c = :playerId AND Game_Round__r.Game_Session__c = :sessionId
            WITH USER_MODE ORDER BY Answered_At__c DESC LIMIT 50
        ]) {
            if (pa.Is_Correct__c) streak++;
            else break;
        }
        return streak;
    }

    private static String readDifficulty(Id questionId) {
        List<Trivia_Question__c> qs = [
            SELECT Difficulty__c FROM Trivia_Question__c WHERE Id = :questionId WITH USER_MODE LIMIT 1
        ];
        return qs.isEmpty() ? 'Medium' : qs[0].Difficulty__c;
    }
}
