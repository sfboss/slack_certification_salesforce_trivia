/**
 * Head-to-Head Duels — viral, social play that drives organic adoption.
 *
 * Flow:
 *  1. `/certgame challenge @user [examCode]` posts an in_channel challenge card
 *     with Accept/Decline buttons. No DB state yet; metadata lives in action_ids.
 *  2. Opponent clicks Accept → we create two `Game_Session__c` rows sharing a
 *     `Duel_Group_Id__c`, DM each player the first question, and update the
 *     original channel message to "Duel in progress".
 *  3. Each player answers in their DM via the standard `game:answer:...` flow.
 *     `CertGameSessionService.recordAnswerFromSlack` advances and finalizes each
 *     session independently.
 *  4. When the second duel session completes, `onSessionComplete` posts a finale
 *     card to the original channel: scores, winner, and a "Rematch" button.
 *
 * Each player gets their own random 5 questions from the same exam (preserves
 * anti-cheat); the duel is decided by total points, which already factors in
 * difficulty, time bonus, and streak via `CertGameScoringService`.
 *
 * Sharing: `without sharing` — invoked by the Slack public-site Guest User.
 * Identity is the verified Slack user id from the signed payload.
 */
public without sharing class CertGameDuelService {

    private static final Integer DUEL_QUESTIONS = 5;
    private static final Integer DEFAULT_TIMER_SEC = 30;

    /** Slash-command entry point: `/certgame challenge @U123 [examCode]`. */
    public static String openChallengeFromSlack(String slackTeamId, String challengerUserId,
                                                String channelId, List<String> args) {
        if (args == null || args.size() < 2) {
            return CertGameSlackRenderService.text(
                'Usage: `/certgame challenge @user [ExamCode]`', true);
        }
        String opponentUserId = parseUserMention(args[1]);
        if (String.isBlank(opponentUserId)) {
            return CertGameSlackRenderService.text(
                'Tag the coworker you want to challenge, e.g. `/certgame challenge @alex`.', true);
        }
        if (opponentUserId == challengerUserId) {
            return CertGameSlackRenderService.text('Pick a coworker — duels need two players.', true);
        }
        if (String.isBlank(channelId)) {
            return CertGameSlackRenderService.text(
                'Duels must be issued from a channel so everyone can watch.', true);
        }

        Tenant__c tenant = CertGameTenantService.getOrCreateTenant(slackTeamId);
        if (!EntitlementGuard.canStartGame(tenant.Id)) {
            return CertGameSlackRenderService.text(CertGameStrings.QUOTA_REACHED, true);
        }

        String examCode = args.size() > 2 ? args[2] : null;
        Certification_Exam__c exam = pickExam(examCode);
        if (exam == null) return CertGameSlackRenderService.text(CertGameStrings.NO_EXAM, true);

        String examLabel = String.isBlank(exam.Certification_Code__c) ? exam.Name : exam.Certification_Code__c;
        String duelGroupId = newDuelGroupId();

        return CertGameSlackRenderService.duelChallengeBlocks(
            challengerUserId, opponentUserId, exam.Id, examLabel, duelGroupId, DUEL_QUESTIONS);
    }

    /**
     * Opponent clicked Accept. action_id encoding:
     *   duel:accept:<challengerUid>:<opponentUid>:<examId>:<duelGroupId>
     */
    public static String acceptChallengeFromSlack(String slackTeamId, String clickerUserId,
                                                  String challengerUid, String opponentUid,
                                                  String examId, String duelGroupId,
                                                  String originChannelId) {
        if (String.isBlank(clickerUserId) || clickerUserId != opponentUid) {
            return CertGameSlackRenderService.text(
                'Only the challenged player can accept this duel.', true);
        }
        if (String.isBlank(examId) || String.isBlank(duelGroupId)) {
            return CertGameSlackRenderService.text(CertGameStrings.GENERIC_ERROR, true);
        }

        // Idempotency: if a session already exists for this duel group, the duel
        // is in progress (Slack retry or double-click). No-op cleanly.
        List<Game_Session__c> existing = [
            SELECT Id FROM Game_Session__c WHERE Duel_Group_Id__c = :duelGroupId LIMIT 1
        ];
        if (!existing.isEmpty()) {
            return CertGameSlackRenderService.text('This duel is already underway.', true);
        }

        Tenant__c tenant = CertGameTenantService.getOrCreateTenant(slackTeamId);
        Certification_Exam__c exam = examById(examId);
        if (exam == null) return CertGameSlackRenderService.text(CertGameStrings.NO_EXAM, true);

        Player__c challengerPlayer = CertGameTenantService.getOrCreatePlayer(tenant.Id, challengerUid);
        Player__c opponentPlayer = CertGameTenantService.getOrCreatePlayer(tenant.Id, opponentUid);

        // Create both duel sessions in one DML.
        Game_Session__c challengerSession = buildDuelSession(
            tenant.Id, exam.Id, slackTeamId, challengerUid, opponentUid,
            originChannelId, duelGroupId, 'Challenger');
        Game_Session__c opponentSession = buildDuelSession(
            tenant.Id, exam.Id, slackTeamId, opponentUid, challengerUid,
            originChannelId, duelGroupId, 'Opponent');
        List<Game_Session__c> toInsert = new List<Game_Session__c>{ challengerSession, opponentSession };
        insert as system toInsert;

        // Open first round for each player.
        Game_Round__c challengerRound = openFirstRound(challengerSession, challengerPlayer);
        Game_Round__c opponentRound = openFirstRound(opponentSession, opponentPlayer);

        if (challengerRound == null || opponentRound == null) {
            // Roll back the sessions so the duel group is reusable.
            delete as system toInsert;
            return CertGameSlackRenderService.text(CertGameStrings.NO_QUESTIONS, true);
        }

        // DM each player their first question, async (we already did DML).
        String cardChallenger = renderRoundCard(challengerSession, challengerRound);
        String cardOpponent = renderRoundCard(opponentSession, opponentRound);
        deliverDmAsync(challengerUid, 'Your duel begins! Question 1 of ' + DUEL_QUESTIONS, cardChallenger);
        deliverDmAsync(opponentUid, 'Your duel begins! Question 1 of ' + DUEL_QUESTIONS, cardOpponent);

        // Replace the in-channel challenge card with a "duel in progress" banner.
        return CertGameSlackRenderService.duelStartedBlocks(challengerUid, opponentUid,
            String.isBlank(exam.Certification_Code__c) ? exam.Name : exam.Certification_Code__c,
            DUEL_QUESTIONS);
    }

    /** Opponent declined the duel. */
    public static String declineChallengeFromSlack(String clickerUserId, String challengerUid, String opponentUid) {
        if (String.isBlank(clickerUserId) || clickerUserId != opponentUid) {
            return CertGameSlackRenderService.text(
                'Only the challenged player can decline this duel.', true);
        }
        return CertGameSlackRenderService.duelDeclinedBlocks(challengerUid, opponentUid);
    }

    /**
     * Called by `CertGameSessionService` when a session marked `Mode__c = 'Duel'`
     * completes. If both sides of the duel group are complete, post the finale
     * card to the original channel.
     *
     * Runs in the SAME transaction as the session-update DML, so we must use
     * @future for the Slack callout.
     */
    public static void onSessionComplete(Id sessionId) {
        if (sessionId == null) return;
        List<Game_Session__c> rows = [
            SELECT Id, Duel_Group_Id__c FROM Game_Session__c WHERE Id = :sessionId LIMIT 1
        ];
        if (rows.isEmpty() || String.isBlank(rows[0].Duel_Group_Id__c)) return;
        scheduleFinale(rows[0].Duel_Group_Id__c);
    }

    @future(callout=true)
    public static void postFinaleAsync(String duelGroupId) {
        if (String.isBlank(duelGroupId)) return;
        List<Game_Session__c> sessions = [
            SELECT Id, Status__c, Mode__c, Duel_Role__c, Started_By_Slack_User_Id__c,
                   Duel_Opponent_Slack_User_Id__c, Duel_Origin_Channel_Id__c,
                   Certification_Exam__c, Certification_Exam__r.Certification_Code__c,
                   Certification_Exam__r.Name
            FROM Game_Session__c
            WHERE Duel_Group_Id__c = :duelGroupId
        ];
        if (sessions.size() != 2) return;
        for (Game_Session__c s : sessions) {
            if (s.Status__c != 'Complete') return; // wait for the other side
        }

        Map<Id, Integer> pointsBySession = new Map<Id, Integer>();
        Map<Id, Integer> correctBySession = new Map<Id, Integer>();
        for (Game_Session__c s : sessions) {
            pointsBySession.put(s.Id, 0);
            correctBySession.put(s.Id, 0);
        }
        for (AggregateResult ar : [
            SELECT Game_Session__c sess, SUM(Points_Awarded__c) pts
            FROM Player_Answer__c
            WHERE Game_Session__c IN :pointsBySession.keySet()
            GROUP BY Game_Session__c
        ]) {
            Decimal p = (Decimal) ar.get('pts');
            pointsBySession.put((Id) ar.get('sess'), p == null ? 0 : p.intValue());
        }
        for (AggregateResult ar : [
            SELECT Game_Session__c sess, COUNT(Id) c
            FROM Player_Answer__c
            WHERE Game_Session__c IN :pointsBySession.keySet() AND Is_Correct__c = true
            GROUP BY Game_Session__c
        ]) {
            correctBySession.put((Id) ar.get('sess'), ((Decimal) ar.get('c')).intValue());
        }

        Game_Session__c challenger = sessions[0].Duel_Role__c == 'Challenger' ? sessions[0] : sessions[1];
        Game_Session__c opponent = sessions[0].Duel_Role__c == 'Challenger' ? sessions[1] : sessions[0];

        String originChannel = challenger.Duel_Origin_Channel_Id__c;
        if (String.isBlank(originChannel)) return;

        String examLabel = String.isBlank(challenger.Certification_Exam__r.Certification_Code__c)
            ? challenger.Certification_Exam__r.Name
            : challenger.Certification_Exam__r.Certification_Code__c;

        String envelope = CertGameSlackRenderService.duelFinaleBlocks(
            challenger.Started_By_Slack_User_Id__c,
            opponent.Started_By_Slack_User_Id__c,
            pointsBySession.get(challenger.Id),
            pointsBySession.get(opponent.Id),
            correctBySession.get(challenger.Id),
            correctBySession.get(opponent.Id),
            DUEL_QUESTIONS,
            examLabel,
            challenger.Certification_Exam__c
        );
        try {
            Map<String, Object> env = (Map<String, Object>) JSON.deserializeUntyped(envelope);
            List<Object> blocks = (List<Object>) env.get('blocks');
            String text = (String) env.get('text');
            SlackApiClient.postMessage(originChannel, text, blocks);
        } catch (Exception e) {
            AppLogger.warn('CertGameDuelService', 'postFinaleAsync', e.getMessage());
        }
    }

    // ---------- helpers ----------

    private static void scheduleFinale(String duelGroupId) {
        // Run in a fresh transaction so we can re-read the latest Status__c values
        // and avoid callout-after-DML constraints.
        if (System.isFuture() || System.isBatch() || System.isQueueable()) {
            // We're already in an async context; the caller can invoke synchronously.
            // (Tests will hit this branch when wrapped in Test.startTest.)
            postFinaleAsync(duelGroupId);
        } else {
            postFinaleAsync(duelGroupId);
        }
    }

    private static Game_Session__c buildDuelSession(Id tenantId, Id examId, String teamId,
                                                    String ownerSlackUid, String otherSlackUid,
                                                    String originChannelId, String duelGroupId,
                                                    String role) {
        return new Game_Session__c(
            Tenant__c = tenantId,
            Certification_Exam__c = examId,
            Slack_Channel_Id__c = ownerSlackUid, // DM target — opens IM via conversations.open
            Slack_Team_Id__c = teamId,
            Started_By_Slack_User_Id__c = ownerSlackUid,
            Mode__c = 'Duel',
            Status__c = 'Active',
            Started_At__c = System.now(),
            Timer_Seconds__c = DEFAULT_TIMER_SEC,
            Total_Questions__c = DUEL_QUESTIONS,
            Current_Question_Index__c = 0,
            Duel_Group_Id__c = duelGroupId,
            Duel_Role__c = role,
            Duel_Opponent_Slack_User_Id__c = otherSlackUid,
            Duel_Origin_Channel_Id__c = originChannelId
        );
    }

    private static Game_Round__c openFirstRound(Game_Session__c session, Player__c player) {
        List<CertGameQuestionService.Pick> picks = CertGameQuestionService.pickQuestions(
            session.Tenant__c, session.Certification_Exam__c, null, null, player.Id, 1);
        if (picks.isEmpty()) return null;
        Game_Round__c r = new Game_Round__c(
            Game_Session__c = session.Id,
            Trivia_Question__c = picks[0].questionId,
            Round_Number__c = 1,
            Status__c = 'Posted',
            Started_At__c = System.now()
        );
        insert as system r;
        return r;
    }

    private static String renderRoundCard(Game_Session__c session, Game_Round__c round) {
        Trivia_Question__c q;
        List<Trivia_Question__c> qs = [
            SELECT Id, Question_Text__c, Difficulty__c FROM Trivia_Question__c
            WHERE Id = :round.Trivia_Question__c LIMIT 1
        ];
        if (qs.isEmpty()) return null;
        q = qs[0];
        List<Map<String, Object>> choices = new List<Map<String, Object>>();
        for (Trivia_Answer_Choice__c c : [
            SELECT Id, Choice_Label__c, Choice_Text__c FROM Trivia_Answer_Choice__c
            WHERE Trivia_Question__c = :round.Trivia_Question__c
            ORDER BY Choice_Label__c
        ]) {
            choices.add(new Map<String, Object>{ 'id' => c.Id, 'label' => c.Choice_Label__c, 'text' => c.Choice_Text__c });
        }
        Integer timer = session.Timer_Seconds__c == null ? DEFAULT_TIMER_SEC : session.Timer_Seconds__c.intValue();
        Integer totalQ = session.Total_Questions__c == null ? DUEL_QUESTIONS : session.Total_Questions__c.intValue();
        return CertGameSlackRenderService.questionBlocks(
            round.Id, q.Question_Text__c, choices, timer, 1, totalQ, q.Difficulty__c);
    }

    private static void deliverDmAsync(String slackUserId, String fallbackText, String envelopeJson) {
        if (String.isBlank(slackUserId) || String.isBlank(envelopeJson)) return;
        try {
            Map<String, Object> env = (Map<String, Object>) JSON.deserializeUntyped(envelopeJson);
            List<Object> blocks = (List<Object>) env.get('blocks');
            String blocksJson = (blocks != null) ? JSON.serialize(blocks) : null;
            SlackApiClient.postMessageAsync(slackUserId, fallbackText, blocksJson);
        } catch (Exception e) {
            AppLogger.warn('CertGameDuelService', 'deliverDmAsync', e.getMessage());
        }
    }

    /** Parses Slack user mentions. Supports `<@U123>`, `<@U123|name>`, raw `U123`. */
    @TestVisible
    private static String parseUserMention(String raw) {
        if (String.isBlank(raw)) return null;
        String s = raw.trim();
        if (s.startsWith('<@') && s.endsWith('>')) {
            String body = s.substring(2, s.length() - 1);
            Integer pipe = body.indexOf('|');
            return pipe >= 0 ? body.substring(0, pipe) : body;
        }
        if (s.startsWith('@')) s = s.substring(1);
        if (s.length() >= 2 && (s.startsWith('U') || s.startsWith('W'))) return s;
        return null;
    }

    private static String newDuelGroupId() {
        // Compact, URL-safe id derived from a UUID — fits inside Slack action_id 255-char cap.
        Blob b = Crypto.generateAesKey(128);
        return 'DG' + EncodingUtil.convertToHex(b).substring(0, 16);
    }

    private static Certification_Exam__c pickExam(String code) {
        if (!String.isBlank(code)) {
            List<Certification_Exam__c> exams = [
                SELECT Id, Name, Certification_Code__c
                FROM Certification_Exam__c WHERE Certification_Code__c = :code LIMIT 1
            ];
            if (!exams.isEmpty()) return exams[0];
        }
        List<Certification_Exam__c> exams = [
            SELECT Id, Name, Certification_Code__c
            FROM Certification_Exam__c WHERE Active__c = true ORDER BY Name LIMIT 1
        ];
        return exams.isEmpty() ? null : exams[0];
    }

    private static Certification_Exam__c examById(String examId) {
        List<Certification_Exam__c> exams = [
            SELECT Id, Name, Certification_Code__c FROM Certification_Exam__c WHERE Id = :examId LIMIT 1
        ];
        return exams.isEmpty() ? null : exams[0];
    }
}