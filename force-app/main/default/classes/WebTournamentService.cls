/**
 * Public tournament operations for the web app (Google-authenticated players).
 * Pairs with WebPlayService for the actual question-answering flow.
 * Tournaments here are async point-races: each participant plays their own session
 * stamped with Tournament__c and points roll up to Tournament_Participant__c.
 */
public without sharing class WebTournamentService {
    public class TournamentPublicDTO {
        public String id;
        public String name;
        public String description;
        public String status;
        public String examName;
        public String examCode;
        public String prizeDescription;
        public DateTime startAt;
        public DateTime endAt;
        public Integer questionsPerMatch;
        public Integer participantCount;
        public Boolean publicJoinEnabled;
        public Boolean joined;
        public Boolean played;
        public Integer myPoints;
        public Integer myRank;
        public List<LeaderRow> leaderboard;
        public String mySessionId;
        public String mySessionStatus;
    }

    public class LeaderRow {
        public Integer rank;
        public String name;
        public String pictureUrl;
        public Integer points;
        public Integer answered;
        public Boolean isMe;
    }

    public class JoinResult {
        public String participantId;
        public Boolean joined;
        public String message;
    }

    public static List<TournamentPublicDTO> listOpenTournaments(Id playerId) {
        List<Tournament__c> rows = [
            SELECT
                Id,
                Name,
                Description__c,
                Status__c,
                Start_At__c,
                End_At__c,
                Questions_Per_Match__c,
                Public_Join_Token__c,
                Public_Join_Enabled__c,
                Prize_Description__c,
                Certification_Exam__r.Name,
                Certification_Exam__r.Certification_Code__c
            FROM Tournament__c
            WHERE
                Public_Join_Enabled__c = TRUE
                AND Status__c IN ('Scheduled', 'Active')
            ORDER BY Start_At__c ASC NULLS LAST, CreatedDate DESC
            LIMIT 50
        ];
        Set<Id> tIds = new Set<Id>();
        for (Tournament__c t : rows)
            tIds.add(t.Id);
        Map<Id, Integer> countsByT = new Map<Id, Integer>();
        Set<Id> joined = new Set<Id>();
        if (!tIds.isEmpty()) {
            for (AggregateResult ar : [
                SELECT Tournament__c tid, COUNT(Id) cnt
                FROM Tournament_Participant__c
                WHERE Tournament__c IN :tIds
                GROUP BY Tournament__c
            ]) {
                countsByT.put((Id) ar.get('tid'), ((Integer) ar.get('cnt')));
            }
            if (playerId != null) {
                for (Tournament_Participant__c tp : [
                    SELECT Tournament__c
                    FROM Tournament_Participant__c
                    WHERE Player__c = :playerId AND Tournament__c IN :tIds
                ]) {
                    joined.add(tp.Tournament__c);
                }
            }
        }
        List<TournamentPublicDTO> out = new List<TournamentPublicDTO>();
        for (Tournament__c t : rows) {
            TournamentPublicDTO d = toPublicDTO(t, null);
            d.participantCount = countsByT.containsKey(t.Id)
                ? countsByT.get(t.Id)
                : 0;
            d.joined = joined.contains(t.Id);
            out.add(d);
        }
        return out;
    }

    public static TournamentPublicDTO getTournamentByToken(
        Id playerId,
        String token
    ) {
        if (String.isBlank(token))
            throw new WebPlayService.PlayException('Missing tournament token.');
        List<Tournament__c> ts = [
            SELECT
                Id,
                Name,
                Description__c,
                Status__c,
                Start_At__c,
                End_At__c,
                Questions_Per_Match__c,
                Public_Join_Token__c,
                Public_Join_Enabled__c,
                Prize_Description__c,
                Certification_Exam__c,
                Certification_Exam__r.Name,
                Certification_Exam__r.Certification_Code__c
            FROM Tournament__c
            WHERE Public_Join_Token__c = :token
            LIMIT 1
        ];
        if (ts.isEmpty())
            throw new WebPlayService.PlayException('Tournament not found.');
        return hydrate(ts[0], playerId);
    }

    public static JoinResult join(Id playerId, String token) {
        if (playerId == null)
            throw new WebPlayService.PlayException('Sign in required.');
        Tournament__c t = lookupByToken(token);
        if (t.Public_Join_Enabled__c != true) {
            throw new WebPlayService.PlayException(
                'Public join is disabled for this tournament.'
            );
        }
        if (t.Status__c == 'Complete' || t.Status__c == 'Cancelled') {
            throw new WebPlayService.PlayException(
                'Tournament is ' + t.Status__c.toLowerCase() + '.'
            );
        }
        Id pid = CertGameTournamentService.upsertParticipant(
            t.Id,
            playerId,
            'Public'
        );
        JoinResult r = new JoinResult();
        r.participantId = pid;
        r.joined = true;
        r.message = 'You are in.';
        return r;
    }

    /**
     * Start a tournament session for this player. Each player gets one session per tournament.
     * If they already have a non-complete session, return that. If they finished, do not allow another.
     */
    public static WebPlayService.RoundDTO startTournamentSession(
        Id playerId,
        String token
    ) {
        if (playerId == null)
            throw new WebPlayService.PlayException('Sign in required.');
        Tournament__c t = lookupByToken(token);
        if (t.Status__c != 'Active') {
            throw new WebPlayService.PlayException('Tournament is not active.');
        }

        Tournament_Participant__c tp = participantFor(t.Id, playerId);
        if (tp == null) {
            CertGameTournamentService.upsertParticipant(
                t.Id,
                playerId,
                'Public'
            );
            tp = participantFor(t.Id, playerId);
        }
        if (
            tp.Status__c == 'Completed' ||
            tp.Status__c == 'Winner' ||
            tp.Status__c == 'Eliminated'
        ) {
            throw new WebPlayService.PlayException(
                'You have already completed this tournament.'
            );
        }

        // If they have an existing session, resume it.
        if (tp.Game_Session__c != null) {
            Game_Session__c sess = [
                SELECT Id, Status__c
                FROM Game_Session__c
                WHERE Id = :tp.Game_Session__c
                LIMIT 1
            ];
            if (sess.Status__c != 'Complete') {
                return WebPlayService.nextRound(playerId, sess.Id);
            }
        }

        Integer n = t.Questions_Per_Match__c == null
            ? 10
            : t.Questions_Per_Match__c.intValue();
        WebPlayService.RoundDTO first = WebPlayService.startSession(
            playerId,
            t.Certification_Exam__c,
            n
        );
        // Stamp the session with the tournament so points roll up cleanly.
        Game_Session__c stamp = new Game_Session__c(
            Id = first.sessionId,
            Tournament__c = t.Id,
            Mode__c = 'Tournament'
        );
        update as system stamp;

        tp.Game_Session__c = first.sessionId;
        tp.Status__c = 'Active';
        update as system tp;
        return first;
    }

    /**
     * Called from the answer flow when a tournament session completes, to recompute standings.
     * Safe to call even when no tournament — checks the session.
     */
    public static void onSessionComplete(Id playerId, Id sessionId) {
        if (sessionId == null)
            return;
        List<Game_Session__c> sess = [
            SELECT Id, Tournament__c
            FROM Game_Session__c
            WHERE Id = :sessionId
            LIMIT 1
        ];
        if (sess.isEmpty() || sess[0].Tournament__c == null)
            return;
        Id tournamentId = sess[0].Tournament__c;

        // Mark the participant as Completed
        List<Tournament_Participant__c> tps = [
            SELECT Id, Status__c
            FROM Tournament_Participant__c
            WHERE Tournament__c = :tournamentId AND Player__c = :playerId
            LIMIT 1
        ];
        if (!tps.isEmpty()) {
            tps[0].Status__c = 'Completed';
            update as system tps[0];
        }

        // Recompute standings for this tournament
        CertGameTournamentService.recomputeStandings(tournamentId);
    }

    // ----------------------------- helpers -----------------------------

    private static Tournament__c lookupByToken(String token) {
        if (String.isBlank(token))
            throw new WebPlayService.PlayException('Missing tournament token.');
        List<Tournament__c> ts = [
            SELECT
                Id,
                Name,
                Status__c,
                Public_Join_Enabled__c,
                Public_Join_Token__c,
                Questions_Per_Match__c,
                Certification_Exam__c,
                Max_Participants__c
            FROM Tournament__c
            WHERE Public_Join_Token__c = :token
            LIMIT 1
        ];
        if (ts.isEmpty())
            throw new WebPlayService.PlayException('Tournament not found.');
        return ts[0];
    }

    private static Tournament_Participant__c participantFor(
        Id tournamentId,
        Id playerId
    ) {
        List<Tournament_Participant__c> rows = [
            SELECT Id, Status__c, Game_Session__c, Total_Points__c, Rank__c
            FROM Tournament_Participant__c
            WHERE Tournament__c = :tournamentId AND Player__c = :playerId
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    private static TournamentPublicDTO hydrate(Tournament__c t, Id playerId) {
        TournamentPublicDTO d = toPublicDTO(t, playerId);
        d.participantCount = [
            SELECT COUNT()
            FROM Tournament_Participant__c
            WHERE Tournament__c = :t.Id
        ];
        if (playerId != null) {
            Tournament_Participant__c tp = participantFor(t.Id, playerId);
            if (tp != null) {
                d.joined = true;
                d.myPoints = tp.Total_Points__c == null
                    ? 0
                    : tp.Total_Points__c.intValue();
                d.myRank = tp.Rank__c == null ? null : tp.Rank__c.intValue();
                d.played =
                    tp.Status__c == 'Completed' ||
                    tp.Status__c == 'Winner';
                d.mySessionId = tp.Game_Session__c;
                if (tp.Game_Session__c != null) {
                    List<Game_Session__c> sx = [
                        SELECT Status__c
                        FROM Game_Session__c
                        WHERE Id = :tp.Game_Session__c
                        LIMIT 1
                    ];
                    if (!sx.isEmpty())
                        d.mySessionStatus = sx[0].Status__c;
                }
            } else {
                d.joined = false;
            }
        }
        d.leaderboard = buildLeaderboard(t.Id, playerId);
        return d;
    }

    private static TournamentPublicDTO toPublicDTO(
        Tournament__c t,
        Id playerId
    ) {
        TournamentPublicDTO d = new TournamentPublicDTO();
        d.id = t.Id;
        d.name = t.Name;
        d.description = t.Description__c;
        d.status = t.Status__c;
        d.examName = t.Certification_Exam__r == null
            ? null
            : t.Certification_Exam__r.Name;
        d.examCode = t.Certification_Exam__r == null
            ? null
            : t.Certification_Exam__r.Certification_Code__c;
        d.prizeDescription = t.Prize_Description__c;
        d.startAt = t.Start_At__c;
        d.endAt = t.End_At__c;
        d.questionsPerMatch = t.Questions_Per_Match__c == null
            ? 10
            : t.Questions_Per_Match__c.intValue();
        d.publicJoinEnabled = t.Public_Join_Enabled__c;
        return d;
    }

    private static List<LeaderRow> buildLeaderboard(
        Id tournamentId,
        Id playerId
    ) {
        List<Tournament_Participant__c> rows = [
            SELECT
                Id,
                Player__c,
                Rank__c,
                Total_Points__c,
                Questions_Answered__c,
                Player__r.Display_Name__c,
                Player__r.Google_Name__c,
                Player__r.Google_Picture_URL__c
            FROM Tournament_Participant__c
            WHERE Tournament__c = :tournamentId
            ORDER BY Rank__c ASC NULLS LAST, Total_Points__c DESC
            LIMIT 25
        ];
        List<LeaderRow> out = new List<LeaderRow>();
        for (Tournament_Participant__c tp : rows) {
            LeaderRow r = new LeaderRow();
            r.rank = tp.Rank__c == null ? null : tp.Rank__c.intValue();
            r.name = String.isBlank(tp.Player__r.Google_Name__c)
                ? tp.Player__r.Display_Name__c
                : tp.Player__r.Google_Name__c;
            r.pictureUrl = tp.Player__r.Google_Picture_URL__c;
            r.points = tp.Total_Points__c == null
                ? 0
                : tp.Total_Points__c.intValue();
            r.answered = tp.Questions_Answered__c == null
                ? 0
                : tp.Questions_Answered__c.intValue();
            r.isMe = playerId != null && tp.Player__c == playerId;
            out.add(r);
        }
        return out;
    }
}