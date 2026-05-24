/**
 * Handles Slack block_actions interactivity.
 * action_id format: `domain:verb:resourceId[:extra]`.
 */
public with sharing class SlackCertGameInteractionHandler {

    public static String handle(Map<String, Object> payload) {
        List<Object> actions = (List<Object>) payload.get('actions');
        if (actions == null || actions.isEmpty()) return '';
        Map<String, Object> act = (Map<String, Object>) actions[0];
        String actionId = (String) act.get('action_id');
        if (String.isBlank(actionId)) return '';

        List<String> parts = actionId.split(':');
        String domain = parts.size() > 0 ? parts[0] : '';
        String verb   = parts.size() > 1 ? parts[1] : '';

        String teamId = extractTeamId(payload);
        String userId = extractUserId(payload);

        // NOTE: Do not insert Audit_Log__c here — handlers below make Slack callouts
        // (views.open) and Apex forbids callouts after DML in the same transaction.
        // Slack_Event_Log__c (written by the router after dispatch) is the audit trail.

        if (domain == 'game' && verb == 'answer') {
            String roundId = parts.size() > 2 ? parts[2] : null;
            String choiceId = parts.size() > 3 ? parts[3] : null;
            AppLogger.info('SlackCertGameInteractionHandler', 'game:answer',
                'roundId=' + roundId + ' choiceId=' + choiceId);
            // Optimistic UI: build the "locked-in" envelope from the source message
            // BEFORE doing scoring DML, so we can return it as the inline 200 body.
            // Slack swaps the message instantly using this envelope (no second HTTP
            // round-trip), eliminating the perceived lag between click and UI change.
            // The async response_url POST below then replaces it again with the
            // real result card once scoring completes.
            String lockedInBody = buildLockedInEnvelope(payload, act);
            String envelopeJson = CertGameSessionService.recordAnswerFromSlack(teamId, userId, roundId, choiceId);
            AppLogger.info('SlackCertGameInteractionHandler', 'game:answer',
                'envLen=' + (envelopeJson == null ? 0 : envelopeJson.length()));
            dispatchToResponseUrl(payload, envelopeJson);
            return lockedInBody;
        }
        if (domain == 'game' && verb == 'newgame') {
            String examCode = parts.size() > 2 ? parts[2] : null;
            List<String> sargs = new List<String>{ 'play' };
            if (String.isNotBlank(examCode)) sargs.add(examCode);
            String channelId = null;
            Object ch = payload.get('channel');
            if (ch instanceof Map<String, Object>) channelId = (String) ((Map<String, Object>) ch).get('id');
            if (String.isBlank(channelId)) channelId = userId;
            String envelopeJson = CertGameSessionService.startQuickGameFromSlack(teamId, userId, channelId, sargs);
            dispatchToResponseUrl(payload, envelopeJson);
            return '';
        }
        if (domain == 'plan' && verb == 'open') {
            String triggerId = (String) payload.get('trigger_id');
            return CertGameStudyPlanService.openPlanModal(teamId, userId, triggerId);
        }
        if (domain == 'help' && verb == 'show') {
            String triggerId = (String) payload.get('trigger_id');
            return CertGameSlackRenderService.helpCommandsModal(triggerId);
        }
        if (domain == 'home' && verb == 'doctor') {
            // Post the doctor report straight to the user's DM so they see the full card
            // (block_actions has no response_url for App Home buttons).
            return postCardDm(userId, 'Cert Game Doctor', CertGameDoctorService.run(teamId, userId));
        }
        if (domain == 'home' && verb == 'notify') {
            return postCardDm(userId, 'Cert Game notification test', CertGameNotificationTestService.run(teamId, userId));
        }
        if (domain == 'home' && verb == 'games') {
            return postCardDm(userId, 'Cert Game — available games', CertGameExamCatalogService.renderForSlack(teamId));
        }
        if (domain == 'home' && verb == 'leaderboard') {
            return postCardDm(userId, 'Cert Game leaderboard',
                CertGameLeaderboardService.renderLeaderboard(teamId, null, new List<String>{'leaderboard'}));
        }
        if (domain == 'home' && verb == 'stats') {
            return postCardDm(userId, 'Cert Game stats',
                CertGameLeaderboardService.renderStats(teamId, userId));
        }
        if (domain == 'report' && (verb == 'open' || verb == 'theme')) {
            // The picker fires `report:theme:<playerId>[|<examId>]` on every selection;
            // the URL button is statically rendered with action_id `report:open:default`
            // and carries the signed URL inline, so we do not need to mint a second URL.
            // We just DM the card so the user always has a fresh signed link from App Home.
            if (verb == 'open') {
                return postCardDm(userId, 'Your Study Guide',
                    CertGameStudyGuideService.renderReport(teamId, userId));
            }
            return '';
        }
        if (domain == 'tournament' && verb == 'join') {
            String tournamentId = parts.size() > 2 ? parts[2] : null;
            return CertGameTournamentService.joinFromSlack(teamId, userId, tournamentId);
        }
        if (domain == 'duel' && verb == 'accept') {
            String challengerUid = parts.size() > 2 ? parts[2] : null;
            String opponentUid   = parts.size() > 3 ? parts[3] : null;
            String examId        = parts.size() > 4 ? parts[4] : null;
            String duelGroupId   = parts.size() > 5 ? parts[5] : null;
            String originChannel = null;
            Object ch = payload.get('channel');
            if (ch instanceof Map<String, Object>) originChannel = (String) ((Map<String, Object>) ch).get('id');
            String envelopeJson = CertGameDuelService.acceptChallengeFromSlack(
                teamId, userId, challengerUid, opponentUid, examId, duelGroupId, originChannel);
            dispatchToResponseUrl(payload, envelopeJson);
            return '';
        }
        if (domain == 'duel' && verb == 'decline') {
            String challengerUid = parts.size() > 2 ? parts[2] : null;
            String opponentUid   = parts.size() > 3 ? parts[3] : null;
            String envelopeJson = CertGameDuelService.declineChallengeFromSlack(userId, challengerUid, opponentUid);
            dispatchToResponseUrl(payload, envelopeJson);
            return '';
        }
        if (domain == 'duel' && verb == 'rematch') {
            String challengerUid = parts.size() > 2 ? parts[2] : null;
            String opponentUid   = parts.size() > 3 ? parts[3] : null;
            // Build a fresh challenge card with the clicker as the new challenger.
            String otherUid = (userId == challengerUid) ? opponentUid : challengerUid;
            List<String> sargs = new List<String>{ 'challenge', '<@' + otherUid + '>' };
            String originChannel = null;
            Object ch2 = payload.get('channel');
            if (ch2 instanceof Map<String, Object>) originChannel = (String) ((Map<String, Object>) ch2).get('id');
            String envelopeJson = CertGameDuelService.openChallengeFromSlack(teamId, userId, originChannel, sargs);
            dispatchToResponseUrl(payload, envelopeJson);
            return '';
        }
        return '';
    }

    /**
     * App Home button clicks have no response_url — use chat.postMessage to DM the user the
     * rendered Block Kit card. Caller passes an already-serialized response_envelope JSON;
     * we extract its `blocks` and forward.
     */
    private static String postCardDm(String userId, String fallbackText, String envelopeJson) {
        if (String.isBlank(userId) || String.isBlank(envelopeJson)) return '';
        try {
            Map<String, Object> env = (Map<String, Object>) JSON.deserializeUntyped(envelopeJson);
            List<Object> blocks = (List<Object>) env.get('blocks');
            SlackApiClient.postMessage(userId, fallbackText, blocks);
        } catch (Exception e) {
            AppLogger.warn('SlackCertGameInteractionHandler', 'postCardDm', e.getMessage());
        }
        return '';
    }

    /**
     * Build an "optimistic UI" envelope returned as the inline 200 body for a
     * `game:answer` click. Slack swaps the original question card using the
     * envelope's `replace_original: true` immediately on click — no second HTTP
     * round-trip — which eliminates the perceived lag between button press and
     * UI update. The real result card arrives a moment later via response_url.
     *
     * Strategy: take the source message's existing blocks, drop the `actions`
     * block (the answer buttons), and append a context line showing the user's
     * chosen answer plus a "scoring…" hint.
     */
    private static String buildLockedInEnvelope(Map<String, Object> payload, Map<String, Object> act) {
        try {
            String chosenLabel = '';
            Object txt = act == null ? null : act.get('text');
            if (txt instanceof Map<String, Object>) {
                Object t = ((Map<String, Object>) txt).get('text');
                if (t instanceof String) chosenLabel = (String) t;
            }

            List<Object> origBlocks = null;
            Object msg = payload.get('message');
            if (msg instanceof Map<String, Object>) {
                Object b = ((Map<String, Object>) msg).get('blocks');
                if (b instanceof List<Object>) origBlocks = (List<Object>) b;
            }

            List<Object> outBlocks = new List<Object>();
            if (origBlocks != null) {
                for (Object blk : origBlocks) {
                    if (blk instanceof Map<String, Object>) {
                        Map<String, Object> bm = (Map<String, Object>) blk;
                        // Strip the answer buttons so they cannot be clicked again
                        // and to make the locked state visually obvious.
                        if ('actions'.equals(bm.get('type'))) continue;
                        outBlocks.add(bm);
                    }
                }
            }
            String lockedLine = String.isBlank(chosenLabel)
                ? ':lock: Answer locked in — scoring…'
                : ':lock: You answered: *' + chosenLabel + '* — scoring…';
            outBlocks.add(CertGameSlackRenderService.context(lockedLine));

            return JSON.serialize(new Map<String, Object>{
                'replace_original' => true,
                'text' => 'Answer locked in',
                'blocks' => outBlocks
            });
        } catch (Exception e) {
            AppLogger.warn('SlackCertGameInteractionHandler', 'buildLockedInEnvelope', e.getMessage());
            return '';
        }
    }

    /**
     * Adds `replace_original: true` to the envelope so Slack swaps the source message
     * (the question card) with this response inline. No callout needed.
     */
    private static String withReplaceOriginal(String envelopeJson) {
        if (String.isBlank(envelopeJson)) return '';
        try {
            Map<String, Object> env = (Map<String, Object>) JSON.deserializeUntyped(envelopeJson);
            env.put('replace_original', true);
            // `response_type` is for slash-command responses; including it on a
            // response_url / inline interactivity payload is ignored at best and
            // suppresses replace_original at worst.
            env.remove('response_type');
            return JSON.serialize(env);
        } catch (Exception e) {
            AppLogger.warn('SlackCertGameInteractionHandler', 'withReplaceOriginal', e.getMessage());
            return envelopeJson;
        }
    }

    /**
     * POSTs the response envelope to the payload's `response_url` asynchronously.
     * This is the canonical Slack pattern for in-message interactivity: the inline
     * 3-second HTTP body ack can be flaky under DML load, and response_url POSTs
     * happen in a fresh transaction so callouts are legal after DML.
     */
    private static void dispatchToResponseUrl(Map<String, Object> payload, String envelopeJson) {
        if (String.isBlank(envelopeJson)) return;
        String url = (String) payload.get('response_url');
        if (String.isBlank(url)) return;
        String prepared = withReplaceOriginal(envelopeJson);
        SlackApiClient.postToResponseUrlAsync(url, prepared);
    }

    /**
     * Replace the source message (the question card) via chat.update against
     * (channel.id, message.ts). Idempotent on Slack retries — unlike response_url
     * POSTs which can post a duplicate message above the original if Slack
     * re-delivers the same interaction.
     */
    private static void updateSourceMessage(Map<String, Object> payload, String envelopeJson) {
        if (String.isBlank(envelopeJson)) return;
        try {
            Map<String, Object> env = (Map<String, Object>) JSON.deserializeUntyped(envelopeJson);
            List<Object> blocks = (List<Object>) env.get('blocks');
            String text = (String) env.get('text');
            if (String.isBlank(text)) text = 'Cert Game';

            String channelId = null;
            Object ch = payload.get('channel');
            if (ch instanceof Map<String, Object>) channelId = (String) ((Map<String, Object>) ch).get('id');
            String ts = null;
            Object msg = payload.get('message');
            if (msg instanceof Map<String, Object>) ts = (String) ((Map<String, Object>) msg).get('ts');
            if (String.isBlank(ts)) {
                Object container = payload.get('container');
                if (container instanceof Map<String, Object>) ts = (String) ((Map<String, Object>) container).get('message_ts');
            }
            if (String.isBlank(channelId) || String.isBlank(ts)) {
                // No source message to update (e.g. App Home action). Fall back to response_url.
                dispatchToResponseUrl(payload, envelopeJson);
                return;
            }
            String blocksJson = (blocks != null) ? JSON.serialize(blocks) : null;
            SlackApiClient.updateMessageAsync(channelId, ts, text, blocksJson);
        } catch (Exception e) {
            AppLogger.warn('SlackCertGameInteractionHandler', 'updateSourceMessage', e.getMessage());
        }
    }

    /**
     * For in-message button clicks (game cards): try chat.update to replace the original
     * card with the result/next card. If no channel/ts is on the payload, fall back to
     * DMing the user via chat.postMessage.
     */
    private static void replaceOrPost(Map<String, Object> payload, String userId, String fallbackText, String envelopeJson) {
        if (String.isBlank(envelopeJson)) return;
        try {
            Map<String, Object> env = (Map<String, Object>) JSON.deserializeUntyped(envelopeJson);
            List<Object> blocks = (List<Object>) env.get('blocks');
            String envText = (String) env.get('text');
            String text = String.isNotBlank(envText) ? envText : fallbackText;
            String channelId = null;
            Object ch = payload.get('channel');
            if (ch instanceof Map<String, Object>) channelId = (String) ((Map<String, Object>) ch).get('id');
            Object container = payload.get('container');
            if (container instanceof Map<String, Object>) {
                Map<String, Object> cm = (Map<String, Object>) container;
                if (String.isBlank(channelId)) channelId = (String) cm.get('channel_id');
            }
            String target = String.isNotBlank(channelId) ? channelId : userId;
            if (String.isBlank(target)) return;
            String blocksJson = (blocks != null && !blocks.isEmpty()) ? JSON.serialize(blocks) : null;
            SlackApiClient.postMessageAsync(target, text, blocksJson);
        } catch (Exception e) {
            AppLogger.warn('SlackCertGameInteractionHandler', 'replaceOrPost', e.getMessage());
        }
    }

    private static String extractTeamId(Map<String, Object> payload) {
        Object t = payload.get('team');
        if (t instanceof Map<String, Object>) return (String) ((Map<String, Object>) t).get('id');
        return (String) payload.get('team_id');
    }
    private static String extractUserId(Map<String, Object> payload) {
        Object u = payload.get('user');
        if (u instanceof Map<String, Object>) return (String) ((Map<String, Object>) u).get('id');
        return (String) payload.get('user_id');
    }
}