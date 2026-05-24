/**
 * Records per-user topic mastery whenever a Player_Answer__c is captured.
 * Rolls up keywords, tags, named entities, domain, difficulty, and (for wrong answers)
 * misconception tags into `Player_Topic_Stat__c` for word clouds, weakness lists, and
 * guided study sessions.
 *
 * Idempotency: keyed off Player_Topic_Stat__c.Topic_Key__c (PlayerId|Type|lower(value)).
 */
public without sharing class CertGamePlayerInsightsService {
    public static void recordAnswerInsights(
        Id playerId,
        Trivia_Question__c question,
        Trivia_Answer_Choice__c picked,
        Boolean isCorrect
    ) {
        if (playerId == null || question == null)
            return;

        Map<String, Player_Topic_Stat__c> stats = new Map<String, Player_Topic_Stat__c>();
        DateTime now = System.now();

        for (String kw : splitSemi(question.Keywords__c))
            addTopic(stats, playerId, 'Keyword', kw, isCorrect, now);
        for (String tg : splitSemi(question.Tags__c))
            addTopic(stats, playerId, 'Tag', tg, isCorrect, now);
        if (
            question.Exam_Domain__c != null &&
            question.Exam_Domain__r != null
        ) {
            addTopic(
                stats,
                playerId,
                'Domain',
                question.Exam_Domain__r.Name,
                isCorrect,
                now
            );
        }
        if (String.isNotBlank(question.Difficulty__c)) {
            addTopic(
                stats,
                playerId,
                'Difficulty',
                question.Difficulty__c,
                isCorrect,
                now
            );
        }
        for (String ent : extractEntityValues(question.Named_Entities__c)) {
            addTopic(stats, playerId, 'Entity', ent, isCorrect, now);
        }
        if (
            picked != null &&
            isCorrect == false &&
            String.isNotBlank(picked.Misconception_Tag__c)
        ) {
            addTopic(
                stats,
                playerId,
                'Misconception',
                picked.Misconception_Tag__c,
                false,
                now
            );
        }

        if (stats.isEmpty())
            return;

        // Read existing stats for these keys so we can increment counters atomically.
        Set<String> keys = stats.keySet();
        Map<String, Player_Topic_Stat__c> existing = new Map<String, Player_Topic_Stat__c>();
        for (Player_Topic_Stat__c row : [
            SELECT
                Id,
                Topic_Key__c,
                Times_Seen__c,
                Times_Correct__c,
                Times_Incorrect__c
            FROM Player_Topic_Stat__c
            WHERE Topic_Key__c IN :keys
            WITH SYSTEM_MODE
        ]) {
            existing.put(row.Topic_Key__c, row);
        }

        List<Player_Topic_Stat__c> toUpsert = new List<Player_Topic_Stat__c>();
        for (Player_Topic_Stat__c incr : stats.values()) {
            Player_Topic_Stat__c prev = existing.get(incr.Topic_Key__c);
            if (prev == null) {
                toUpsert.add(incr);
            } else {
                prev.Times_Seen__c =
                    nz(prev.Times_Seen__c) + nz(incr.Times_Seen__c);
                prev.Times_Correct__c =
                    nz(prev.Times_Correct__c) + nz(incr.Times_Correct__c);
                prev.Times_Incorrect__c =
                    nz(prev.Times_Incorrect__c) + nz(incr.Times_Incorrect__c);
                prev.Last_Seen_At__c = now;
                toUpsert.add(prev);
            }
        }
        Database.upsert(
            toUpsert,
            Player_Topic_Stat__c.Topic_Key__c,
            false,
            AccessLevel.SYSTEM_MODE
        );
    }

    /**
     * Returns the player's weakest topics (lowest accuracy with at least minSeen samples).
     * Powers the result-card "you keep missing X" coaching line and study-plan ranking.
     */
    public static List<Player_Topic_Stat__c> weakestTopics(
        Id playerId,
        Integer minSeen,
        Integer limitN
    ) {
        Integer ms = minSeen == null ? 2 : minSeen;
        Integer ln = limitN == null ? 5 : limitN;
        return [
            SELECT
                Topic_Type__c,
                Topic_Value__c,
                Times_Seen__c,
                Times_Correct__c,
                Times_Incorrect__c,
                Accuracy_Pct__c,
                Last_Seen_At__c
            FROM Player_Topic_Stat__c
            WHERE Player__c = :playerId AND Times_Seen__c >= :ms
            ORDER BY Accuracy_Pct__c ASC, Times_Incorrect__c DESC NULLS LAST
            LIMIT :ln
        ];
    }

    public static List<Player_Topic_Stat__c> wordCloud(
        Id playerId,
        String topicType,
        Integer limitN
    ) {
        Integer ln = limitN == null ? 50 : limitN;
        return [
            SELECT
                Topic_Value__c,
                Times_Seen__c,
                Times_Correct__c,
                Accuracy_Pct__c
            FROM Player_Topic_Stat__c
            WHERE Player__c = :playerId AND Topic_Type__c = :topicType
            ORDER BY Times_Seen__c DESC
            LIMIT :ln
        ];
    }

    // ---------------- internals ----------------

    private static void addTopic(
        Map<String, Player_Topic_Stat__c> sink,
        Id playerId,
        String type,
        String value,
        Boolean isCorrect,
        DateTime now
    ) {
        if (String.isBlank(value))
            return;
        String trimmed = value.trim();
        if (trimmed.length() > 255)
            trimmed = trimmed.substring(0, 255);
        String key = buildKey(playerId, type, trimmed);
        Player_Topic_Stat__c row = sink.get(key);
        if (row == null) {
            row = new Player_Topic_Stat__c(
                Player__c = playerId,
                Topic_Type__c = type,
                Topic_Value__c = trimmed,
                Topic_Key__c = key,
                Times_Seen__c = 0,
                Times_Correct__c = 0,
                Times_Incorrect__c = 0,
                Last_Seen_At__c = now
            );
            sink.put(key, row);
        }
        row.Times_Seen__c = nz(row.Times_Seen__c) + 1;
        if (isCorrect == true)
            row.Times_Correct__c = nz(row.Times_Correct__c) + 1;
        else
            row.Times_Incorrect__c = nz(row.Times_Incorrect__c) + 1;
        row.Last_Seen_At__c = now;
    }

    private static String buildKey(Id playerId, String type, String value) {
        String v = value.toLowerCase();
        String raw = String.valueOf(playerId) + '|' + type + '|' + v;
        if (raw.length() <= 200)
            return raw;
        String prefix = String.valueOf(playerId) + '|' + type + '|';
        String hash = EncodingUtil.convertToHex(
                Crypto.generateDigest('SHA-256', Blob.valueOf(v))
            )
            .left(40);
        return (prefix + hash).left(200);
    }

    private static List<String> splitSemi(String s) {
        List<String> out = new List<String>();
        if (String.isBlank(s))
            return out;
        for (String tok : s.split(';')) {
            String t = tok == null ? '' : tok.trim();
            if (t != '')
                out.add(t);
        }
        return out;
    }

    private static List<String> extractEntityValues(String jsonStr) {
        List<String> out = new List<String>();
        if (String.isBlank(jsonStr))
            return out;
        try {
            Object parsed = JSON.deserializeUntyped(jsonStr);
            if (!(parsed instanceof List<Object>))
                return out;
            for (Object o : (List<Object>) parsed) {
                if (o instanceof Map<String, Object>) {
                    Object v = ((Map<String, Object>) o).get('value');
                    if (v instanceof String && String.isNotBlank((String) v))
                        out.add((String) v);
                } else if (o instanceof String) {
                    if (String.isNotBlank((String) o))
                        out.add((String) o);
                }
            }
        } catch (Exception e) {
            AppLogger.warn(
                'CertGamePlayerInsightsService',
                'extractEntityValues',
                e.getMessage()
            );
        }
        return out;
    }

    private static Decimal nz(Decimal d) {
        return d == null ? 0 : d;
    }
}