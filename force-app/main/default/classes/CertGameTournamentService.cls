/**
 * Tournament service. Supports admin operations (create, edit, enroll, start, complete, cancel,
 * standings, public join token) and the legacy Slack/Builder methods used elsewhere.
 *
 * Tournaments run as "async point race": each participant plays a private quiz session built
 * from the tournament's exam; their total points roll up onto Tournament_Participant__c.
 * Highest points at completion wins.
 */
public with sharing class CertGameTournamentService {

    private static final Integer DEFAULT_QUESTIONS = 10;
    private static final Integer MAX_BULK_EMAILS = 200;

    // ----------------------------- DTOs -----------------------------

    public class ExamOption {
        @AuraEnabled public Id id;
        @AuraEnabled public String label;
    }

    public class TournamentSummary {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public String bracketType;
        @AuraEnabled public String examName;
        @AuraEnabled public String examCode;
        @AuraEnabled public DateTime startAt;
        @AuraEnabled public DateTime endAt;
        @AuraEnabled public DateTime completedAt;
        @AuraEnabled public Integer participantCount;
        @AuraEnabled public Integer activeCount;
        @AuraEnabled public Integer completedCount;
        @AuraEnabled public Integer questionsPerMatch;
        @AuraEnabled public Integer maxParticipants;
        @AuraEnabled public Boolean publicJoinEnabled;
        @AuraEnabled public String publicJoinToken;
        @AuraEnabled public String winnerName;
        @AuraEnabled public String prizeDescription;
    }

    public class ParticipantRow {
        @AuraEnabled public Id id;
        @AuraEnabled public Id playerId;
        @AuraEnabled public String name;
        @AuraEnabled public String email;
        @AuraEnabled public String pictureUrl;
        @AuraEnabled public String status;
        @AuraEnabled public String source;
        @AuraEnabled public Integer points;
        @AuraEnabled public Integer answered;
        @AuraEnabled public Integer correct;
        @AuraEnabled public Decimal accuracy;
        @AuraEnabled public Integer rank;
        @AuraEnabled public DateTime joinedAt;
        @AuraEnabled public DateTime lastPlayedAt;
    }

    public class TournamentDetail {
        @AuraEnabled public TournamentSummary tournament;
        @AuraEnabled public List<ParticipantRow> participants;
        @AuraEnabled public Integer totalAnswers;
        @AuraEnabled public Integer totalCorrect;
        @AuraEnabled public String description;
        @AuraEnabled public Id examId;
    }

    public class PlayerSearchRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String email;
        @AuraEnabled public String pictureUrl;
        @AuraEnabled public Boolean alreadyEnrolled;
    }

    public class TournamentInput {
        @AuraEnabled public String name;
        @AuraEnabled public String description;
        @AuraEnabled public String bracketType;
        @AuraEnabled public Id examId;
        @AuraEnabled public DateTime startAt;
        @AuraEnabled public DateTime endAt;
        @AuraEnabled public Integer questionsPerMatch;
        @AuraEnabled public Integer maxParticipants;
        @AuraEnabled public Boolean publicJoinEnabled;
        @AuraEnabled public String prizeDescription;
    }

    public class EnrollResult {
        @AuraEnabled public Integer added;
        @AuraEnabled public Integer existing;
        @AuraEnabled public Integer notFound;
        @AuraEnabled public List<String> notFoundEmails;
    }

    // ----------------------------- Read -----------------------------

    @AuraEnabled(cacheable=true)
    public static List<ExamOption> listExams() {
        List<ExamOption> out = new List<ExamOption>();
        for (Certification_Exam__c e : [SELECT Id, Name, Certification_Code__c
                                        FROM Certification_Exam__c
                                        WITH SYSTEM_MODE
                                        ORDER BY Name LIMIT 200]) {
            ExamOption o = new ExamOption();
            o.id = e.Id;
            o.label = e.Name + ' (' + e.Certification_Code__c + ')';
            out.add(o);
        }
        return out;
    }

    @AuraEnabled(cacheable=true)
    public static List<TournamentSummary> listTournaments(String statusFilter) {
        String soql = 'SELECT Id, Name, Status__c, Bracket_Type__c, Start_At__c, End_At__c, Completed_At__c, ' +
                      'Questions_Per_Match__c, Max_Participants__c, Public_Join_Enabled__c, Public_Join_Token__c, ' +
                      'Prize_Description__c, Winner_Player__r.Display_Name__c, Winner_Player__r.Google_Name__c, ' +
                      'Certification_Exam__r.Name, Certification_Exam__r.Certification_Code__c ' +
                      'FROM Tournament__c WITH SYSTEM_MODE';
        if (String.isNotBlank(statusFilter) && statusFilter != 'All') {
            soql += ' WHERE Status__c = :statusFilter';
        }
        soql += ' ORDER BY CreatedDate DESC LIMIT 200';
        List<Tournament__c> rows = Database.query(soql);

        Map<Id, Integer> partAll = countByTournament(rows);
        Map<Id, Integer> partActive = countByTournamentStatus(rows, new Set<String>{'Active', 'Registered'});
        Map<Id, Integer> partDone = countByTournamentStatus(rows, new Set<String>{'Completed', 'Winner'});

        List<TournamentSummary> out = new List<TournamentSummary>();
        for (Tournament__c t : rows) {
            out.add(toSummary(t, partAll, partActive, partDone));
        }
        return out;
    }

    @AuraEnabled(cacheable=true)
    public static TournamentDetail getTournamentDetail(Id tournamentId) {
        if (tournamentId == null) throw new AuraHandledException('Tournament Id is required.');
        List<Tournament__c> ts = [SELECT Id, Name, Status__c, Bracket_Type__c, Start_At__c, End_At__c, Completed_At__c,
                                         Questions_Per_Match__c, Max_Participants__c, Public_Join_Enabled__c, Public_Join_Token__c,
                                         Prize_Description__c, Description__c, Certification_Exam__c,
                                         Winner_Player__r.Display_Name__c, Winner_Player__r.Google_Name__c,
                                         Certification_Exam__r.Name, Certification_Exam__r.Certification_Code__c
                                  FROM Tournament__c WHERE Id = :tournamentId WITH SYSTEM_MODE LIMIT 1];
        if (ts.isEmpty()) throw new AuraHandledException('Tournament not found.');
        Tournament__c t = ts[0];

        List<ParticipantRow> participants = loadParticipants(tournamentId);

        TournamentDetail d = new TournamentDetail();
        Map<Id, Integer> partAll = new Map<Id, Integer>{ t.Id => participants.size() };
        Map<Id, Integer> partActive = new Map<Id, Integer>{ t.Id => 0 };
        Map<Id, Integer> partDone = new Map<Id, Integer>{ t.Id => 0 };
        Integer totalAns = 0, totalCor = 0;
        for (ParticipantRow p : participants) {
            if (p.status == 'Active' || p.status == 'Registered') partActive.put(t.Id, partActive.get(t.Id) + 1);
            if (p.status == 'Completed' || p.status == 'Winner') partDone.put(t.Id, partDone.get(t.Id) + 1);
            totalAns += (p.answered == null ? 0 : p.answered);
            totalCor += (p.correct == null ? 0 : p.correct);
        }
        d.tournament = toSummary(t, partAll, partActive, partDone);
        d.participants = participants;
        d.totalAnswers = totalAns;
        d.totalCorrect = totalCor;
        d.description = t.Description__c;
        d.examId = t.Certification_Exam__c;
        return d;
    }

    @AuraEnabled
    public static List<PlayerSearchRow> searchPlayers(Id tournamentId, String query) {
        Set<Id> enrolled = new Set<Id>();
        if (tournamentId != null) {
            for (Tournament_Participant__c tp : [SELECT Player__c FROM Tournament_Participant__c
                                                  WHERE Tournament__c = :tournamentId WITH SYSTEM_MODE]) {
                enrolled.add(tp.Player__c);
            }
        }
        List<Player__c> players;
        if (String.isBlank(query)) {
            players = [SELECT Id, Display_Name__c, Google_Name__c, Google_Email__c, Google_Picture_URL__c
                       FROM Player__c WITH SYSTEM_MODE
                       ORDER BY LastModifiedDate DESC LIMIT 50];
        } else {
            String pattern = '%' + query.toLowerCase() + '%';
            players = [SELECT Id, Display_Name__c, Google_Name__c, Google_Email__c, Google_Picture_URL__c
                       FROM Player__c
                       WHERE Google_Email__c LIKE :pattern OR Google_Name__c LIKE :pattern OR Display_Name__c LIKE :pattern
                       WITH SYSTEM_MODE
                       ORDER BY LastModifiedDate DESC LIMIT 50];
        }
        List<PlayerSearchRow> out = new List<PlayerSearchRow>();
        for (Player__c p : players) {
            PlayerSearchRow r = new PlayerSearchRow();
            r.id = p.Id;
            r.name = String.isBlank(p.Google_Name__c) ? p.Display_Name__c : p.Google_Name__c;
            r.email = p.Google_Email__c;
            r.pictureUrl = p.Google_Picture_URL__c;
            r.alreadyEnrolled = enrolled.contains(p.Id);
            out.add(r);
        }
        return out;
    }

    // ----------------------------- Write -----------------------------

    @AuraEnabled
    public static Id createTournamentFull(TournamentInput input) {
        if (input == null || String.isBlank(input.name) || String.isBlank(input.bracketType) || input.examId == null) {
            throw new AuraHandledException('Name, bracket type, and exam are required.');
        }
        Tournament__c t = new Tournament__c(
            Name = input.name,
            Description__c = input.description,
            Bracket_Type__c = input.bracketType,
            Certification_Exam__c = input.examId,
            Start_At__c = input.startAt,
            End_At__c = input.endAt,
            Questions_Per_Match__c = input.questionsPerMatch == null ? DEFAULT_QUESTIONS : input.questionsPerMatch,
            Max_Participants__c = input.maxParticipants,
            Public_Join_Enabled__c = input.publicJoinEnabled == null ? true : input.publicJoinEnabled,
            Prize_Description__c = input.prizeDescription,
            Public_Join_Token__c = generateToken(),
            Status__c = 'Scheduled'
        );
        insert as system t;
        AuditLogger.log('tournament_create', 'Tournament__c', t.Id, null, JSON.serialize(t), null);
        return t.Id;
    }

    @AuraEnabled
    public static void updateTournament(Id tournamentId, TournamentInput input) {
        if (tournamentId == null || input == null) throw new AuraHandledException('Missing input.');
        Tournament__c t = new Tournament__c(
            Id = tournamentId,
            Name = input.name,
            Description__c = input.description,
            Bracket_Type__c = input.bracketType,
            Certification_Exam__c = input.examId,
            Start_At__c = input.startAt,
            End_At__c = input.endAt,
            Questions_Per_Match__c = input.questionsPerMatch == null ? DEFAULT_QUESTIONS : input.questionsPerMatch,
            Max_Participants__c = input.maxParticipants,
            Public_Join_Enabled__c = input.publicJoinEnabled == null ? true : input.publicJoinEnabled,
            Prize_Description__c = input.prizeDescription
        );
        update as system t;
        AuditLogger.log('tournament_update', 'Tournament__c', tournamentId, null, JSON.serialize(t), null);
    }

    @AuraEnabled
    public static Id enrollPlayer(Id tournamentId, Id playerId) {
        if (tournamentId == null || playerId == null) throw new AuraHandledException('Tournament and player are required.');
        return upsertParticipant(tournamentId, playerId, 'Admin');
    }

    @AuraEnabled
    public static EnrollResult enrollPlayersByEmail(Id tournamentId, List<String> emails) {
        if (tournamentId == null) throw new AuraHandledException('Tournament is required.');
        EnrollResult r = new EnrollResult();
        r.added = 0; r.existing = 0; r.notFound = 0;
        r.notFoundEmails = new List<String>();
        if (emails == null || emails.isEmpty()) return r;
        List<String> cleaned = new List<String>();
        for (String e : emails) {
            if (String.isBlank(e)) continue;
            cleaned.add(e.trim().toLowerCase());
            if (cleaned.size() >= MAX_BULK_EMAILS) break;
        }
        if (cleaned.isEmpty()) return r;

        Map<String, Player__c> byEmail = new Map<String, Player__c>();
        for (Player__c p : [SELECT Id, Google_Email__c FROM Player__c
                            WHERE Google_Email__c IN :cleaned WITH SYSTEM_MODE]) {
            if (p.Google_Email__c != null) byEmail.put(p.Google_Email__c.toLowerCase(), p);
        }
        Set<Id> existing = new Set<Id>();
        for (Tournament_Participant__c tp : [SELECT Player__c FROM Tournament_Participant__c
                                              WHERE Tournament__c = :tournamentId WITH SYSTEM_MODE]) {
            existing.add(tp.Player__c);
        }
        List<Tournament_Participant__c> toInsert = new List<Tournament_Participant__c>();
        for (String e : cleaned) {
            Player__c p = byEmail.get(e);
            if (p == null) { r.notFound++; r.notFoundEmails.add(e); continue; }
            if (existing.contains(p.Id)) { r.existing++; continue; }
            existing.add(p.Id);
            toInsert.add(buildParticipant(tournamentId, p.Id, 'Admin'));
        }
        if (!toInsert.isEmpty()) {
            insert as system toInsert;
            r.added = toInsert.size();
            AuditLogger.log('tournament_bulk_enroll', 'Tournament__c', tournamentId, null,
                            new Map<String,Object>{ 'added' => r.added, 'notFound' => r.notFound }, null);
        }
        return r;
    }

    @AuraEnabled
    public static void removeParticipant(Id participantId) {
        if (participantId == null) return;
        delete as system new Tournament_Participant__c(Id = participantId);
        AuditLogger.log('tournament_remove_participant', 'Tournament_Participant__c', participantId, null, null, null);
    }

    @AuraEnabled
    public static void startTournament(Id tournamentId) {
        Tournament__c t = loadForUpdate(tournamentId);
        if (t.Status__c == 'Active') return;
        if (t.Status__c == 'Complete' || t.Status__c == 'Cancelled') {
            throw new AuraHandledException('Tournament already ' + t.Status__c.toLowerCase() + '.');
        }
        t.Status__c = 'Active';
        if (t.Start_At__c == null) t.Start_At__c = System.now();
        if (String.isBlank(t.Public_Join_Token__c)) t.Public_Join_Token__c = generateToken();
        update as system t;

        // Move Registered participants to Active so they can play
        List<Tournament_Participant__c> regs = [SELECT Id, Status__c FROM Tournament_Participant__c
                                                 WHERE Tournament__c = :tournamentId AND Status__c = 'Registered'
                                                 WITH SYSTEM_MODE];
        for (Tournament_Participant__c tp : regs) tp.Status__c = 'Active';
        if (!regs.isEmpty()) update as system regs;
        AuditLogger.log('tournament_start', 'Tournament__c', tournamentId, null, null, null);
    }

    @AuraEnabled
    public static void completeTournament(Id tournamentId) {
        Tournament__c t = loadForUpdate(tournamentId);
        if (t.Status__c == 'Complete') return;
        recomputeStandings(tournamentId);

        List<Tournament_Participant__c> participants = [SELECT Id, Player__c, Status__c, Total_Points__c, Rank__c
                                                         FROM Tournament_Participant__c
                                                         WHERE Tournament__c = :tournamentId
                                                         WITH SYSTEM_MODE
                                                         ORDER BY Rank__c ASC NULLS LAST];
        Id winnerPlayerId;
        List<Tournament_Participant__c> toUpdate = new List<Tournament_Participant__c>();
        for (Tournament_Participant__c tp : participants) {
            if (tp.Rank__c == 1 && winnerPlayerId == null) {
                winnerPlayerId = tp.Player__c;
                tp.Status__c = 'Winner';
                toUpdate.add(tp);
            } else if (tp.Status__c == 'Active' || tp.Status__c == 'Registered') {
                tp.Status__c = 'Completed';
                toUpdate.add(tp);
            }
        }
        if (!toUpdate.isEmpty()) update as system toUpdate;

        t.Status__c = 'Complete';
        t.Completed_At__c = System.now();
        t.Winner_Player__c = winnerPlayerId;
        update as system t;
        AuditLogger.log('tournament_complete', 'Tournament__c', tournamentId, null,
                        new Map<String,Object>{ 'winnerPlayerId' => winnerPlayerId }, null);
    }

    @AuraEnabled
    public static void cancelTournament(Id tournamentId) {
        Tournament__c t = loadForUpdate(tournamentId);
        t.Status__c = 'Cancelled';
        update as system t;
        AuditLogger.log('tournament_cancel', 'Tournament__c', tournamentId, null, null, null);
    }

    @AuraEnabled
    public static void recomputeStandings(Id tournamentId) {
        if (tournamentId == null) return;
        // Pull all participants and roll up scores from their game sessions.
        Map<Id, Tournament_Participant__c> byId = new Map<Id, Tournament_Participant__c>(
            [SELECT Id, Player__c, Status__c, Total_Points__c, Questions_Answered__c, Questions_Correct__c,
                    Last_Played_At__c, Rank__c
             FROM Tournament_Participant__c WHERE Tournament__c = :tournamentId WITH SYSTEM_MODE]
        );
        if (byId.isEmpty()) return;

        Set<Id> playerIds = new Set<Id>();
        for (Tournament_Participant__c tp : byId.values()) playerIds.add(tp.Player__c);

        // Aggregate Player_Answer__c only for sessions that belong to this tournament.
        Map<Id, Integer> ptsByPlayer = new Map<Id, Integer>();
        Map<Id, Integer> ansByPlayer = new Map<Id, Integer>();
        Map<Id, Integer> corByPlayer = new Map<Id, Integer>();
        Map<Id, DateTime> lastByPlayer = new Map<Id, DateTime>();

        for (AggregateResult ar : [
            SELECT Player__c pid,
                   SUM(Points_Awarded__c) pts,
                   COUNT(Id) cnt,
                   MAX(Answered_At__c) lastAns
            FROM Player_Answer__c
            WHERE Player__c IN :playerIds
              AND Game_Session__r.Tournament__c = :tournamentId
            GROUP BY Player__c
        ]) {
            Id pid = (Id) ar.get('pid');
            ptsByPlayer.put(pid, ar.get('pts') == null ? 0 : ((Decimal) ar.get('pts')).intValue());
            ansByPlayer.put(pid, ((Integer) ar.get('cnt')));
            lastByPlayer.put(pid, (DateTime) ar.get('lastAns'));
        }
        for (AggregateResult ar : [
            SELECT Player__c pid, COUNT(Id) cnt
            FROM Player_Answer__c
            WHERE Player__c IN :playerIds
              AND Game_Session__r.Tournament__c = :tournamentId
              AND Is_Correct__c = true
            GROUP BY Player__c
        ]) {
            corByPlayer.put((Id) ar.get('pid'), ((Integer) ar.get('cnt')));
        }

        // Rank by points DESC tiebreak by correct DESC then earliest last-played ASC
        List<Tournament_Participant__c> ordered = new List<Tournament_Participant__c>();
        for (Tournament_Participant__c tp : byId.values()) {
            tp.Total_Points__c = ptsByPlayer.containsKey(tp.Player__c) ? ptsByPlayer.get(tp.Player__c) : 0;
            tp.Questions_Answered__c = ansByPlayer.containsKey(tp.Player__c) ? ansByPlayer.get(tp.Player__c) : 0;
            tp.Questions_Correct__c = corByPlayer.containsKey(tp.Player__c) ? corByPlayer.get(tp.Player__c) : 0;
            tp.Last_Played_At__c = lastByPlayer.containsKey(tp.Player__c) ? lastByPlayer.get(tp.Player__c) : tp.Last_Played_At__c;
            ordered.add(tp);
        }
        ordered.sort(new ParticipantRanker());
        Integer rank = 0;
        Decimal lastPts = null;
        Integer lastCor = null;
        Integer seen = 0;
        for (Tournament_Participant__c tp : ordered) {
            seen++;
            if (lastPts == null || tp.Total_Points__c != lastPts || tp.Questions_Correct__c != lastCor) {
                rank = seen;
                lastPts = tp.Total_Points__c;
                lastCor = (Integer) tp.Questions_Correct__c;
            }
            tp.Rank__c = rank;
        }
        update as system ordered;
    }

    public class ParticipantRanker implements Comparator<Tournament_Participant__c> {
        public Integer compare(Tournament_Participant__c a, Tournament_Participant__c b) {
            Decimal ap = a.Total_Points__c == null ? 0 : a.Total_Points__c;
            Decimal bp = b.Total_Points__c == null ? 0 : b.Total_Points__c;
            if (ap != bp) return ap > bp ? -1 : 1;
            Decimal ac = a.Questions_Correct__c == null ? 0 : a.Questions_Correct__c;
            Decimal bc = b.Questions_Correct__c == null ? 0 : b.Questions_Correct__c;
            if (ac != bc) return ac > bc ? -1 : 1;
            DateTime al = a.Last_Played_At__c;
            DateTime bl = b.Last_Played_At__c;
            if (al == null && bl == null) return 0;
            if (al == null) return 1;
            if (bl == null) return -1;
            if (al.getTime() == bl.getTime()) return 0;
            return al.getTime() < bl.getTime() ? -1 : 1;
        }
    }

    // ----------------------------- Helpers for shared logic with WebTournamentService -----------

    public static Id upsertParticipant(Id tournamentId, Id playerId, String source) {
        String key = tournamentId + ':' + playerId;
        List<Tournament_Participant__c> existing = [SELECT Id FROM Tournament_Participant__c
                                                     WHERE Unique_Key__c = :key WITH SYSTEM_MODE LIMIT 1];
        if (!existing.isEmpty()) return existing[0].Id;
        Tournament__c t = [SELECT Id, Status__c, Max_Participants__c FROM Tournament__c
                            WHERE Id = :tournamentId WITH SYSTEM_MODE LIMIT 1];
        if (t.Status__c == 'Cancelled' || t.Status__c == 'Complete') {
            throw new AuraHandledException('Cannot enroll: tournament is ' + t.Status__c.toLowerCase() + '.');
        }
        if (t.Max_Participants__c != null) {
            Integer count = [SELECT COUNT() FROM Tournament_Participant__c WHERE Tournament__c = :tournamentId];
            if (count >= t.Max_Participants__c) {
                throw new AuraHandledException('Tournament is full.');
            }
        }
        Tournament_Participant__c tp = buildParticipant(tournamentId, playerId, source);
        if (t.Status__c == 'Active') tp.Status__c = 'Active';
        insert as system tp;
        AuditLogger.log('tournament_enroll', 'Tournament_Participant__c', tp.Id,
                        null, new Map<String,Object>{ 'tournamentId' => tournamentId, 'playerId' => playerId, 'source' => source }, null);
        return tp.Id;
    }

    public static Tournament_Participant__c buildParticipant(Id tournamentId, Id playerId, String source) {
        Tournament_Participant__c tp = new Tournament_Participant__c();
        tp.Tournament__c = tournamentId;
        tp.Player__c = playerId;
        tp.Status__c = 'Registered';
        tp.Source__c = source;
        tp.Joined_At__c = System.now();
        tp.Total_Points__c = 0;
        tp.Questions_Answered__c = 0;
        tp.Questions_Correct__c = 0;
        tp.Unique_Key__c = tournamentId + ':' + playerId;
        return tp;
    }

    public static String generateToken() {
        Blob b = Crypto.generateAesKey(128);
        String s = EncodingUtil.base64Encode(b).replace('+','').replace('/','').replace('=','');
        return s.substring(0, Math.min(20, s.length())).toLowerCase();
    }

    private static Tournament__c loadForUpdate(Id tournamentId) {
        List<Tournament__c> ts = [SELECT Id, Status__c, Start_At__c, Public_Join_Token__c, Completed_At__c, Winner_Player__c
                                  FROM Tournament__c WHERE Id = :tournamentId WITH SYSTEM_MODE LIMIT 1];
        if (ts.isEmpty()) throw new AuraHandledException('Tournament not found.');
        return ts[0];
    }

    private static List<ParticipantRow> loadParticipants(Id tournamentId) {
        List<Tournament_Participant__c> rows = [SELECT Id, Player__c, Status__c, Source__c, Total_Points__c,
                                                       Questions_Answered__c, Questions_Correct__c, Rank__c,
                                                       Joined_At__c, Last_Played_At__c,
                                                       Player__r.Display_Name__c, Player__r.Google_Name__c,
                                                       Player__r.Google_Email__c, Player__r.Google_Picture_URL__c
                                                FROM Tournament_Participant__c
                                                WHERE Tournament__c = :tournamentId
                                                WITH SYSTEM_MODE
                                                ORDER BY Rank__c ASC NULLS LAST, Total_Points__c DESC, Joined_At__c ASC
                                                LIMIT 500];
        List<ParticipantRow> out = new List<ParticipantRow>();
        for (Tournament_Participant__c tp : rows) {
            ParticipantRow r = new ParticipantRow();
            r.id = tp.Id;
            r.playerId = tp.Player__c;
            r.name = String.isBlank(tp.Player__r.Google_Name__c) ? tp.Player__r.Display_Name__c : tp.Player__r.Google_Name__c;
            r.email = tp.Player__r.Google_Email__c;
            r.pictureUrl = tp.Player__r.Google_Picture_URL__c;
            r.status = tp.Status__c;
            r.source = tp.Source__c;
            r.points = tp.Total_Points__c == null ? 0 : tp.Total_Points__c.intValue();
            r.answered = tp.Questions_Answered__c == null ? 0 : tp.Questions_Answered__c.intValue();
            r.correct = tp.Questions_Correct__c == null ? 0 : tp.Questions_Correct__c.intValue();
            r.accuracy = r.answered == 0 ? 0 : (Decimal.valueOf(r.correct) / r.answered);
            r.rank = tp.Rank__c == null ? null : tp.Rank__c.intValue();
            r.joinedAt = tp.Joined_At__c;
            r.lastPlayedAt = tp.Last_Played_At__c;
            out.add(r);
        }
        return out;
    }

    private static Map<Id, Integer> countByTournament(List<Tournament__c> rows) {
        Set<Id> ids = new Set<Id>();
        for (Tournament__c t : rows) ids.add(t.Id);
        Map<Id, Integer> m = new Map<Id, Integer>();
        for (Id i : ids) m.put(i, 0);
        for (AggregateResult ar : [SELECT Tournament__c tid, COUNT(Id) cnt FROM Tournament_Participant__c
                                    WHERE Tournament__c IN :ids GROUP BY Tournament__c]) {
            m.put((Id) ar.get('tid'), ((Integer) ar.get('cnt')));
        }
        return m;
    }

    private static Map<Id, Integer> countByTournamentStatus(List<Tournament__c> rows, Set<String> statuses) {
        Set<Id> ids = new Set<Id>();
        for (Tournament__c t : rows) ids.add(t.Id);
        Map<Id, Integer> m = new Map<Id, Integer>();
        for (Id i : ids) m.put(i, 0);
        for (AggregateResult ar : [SELECT Tournament__c tid, COUNT(Id) cnt FROM Tournament_Participant__c
                                    WHERE Tournament__c IN :ids AND Status__c IN :statuses GROUP BY Tournament__c]) {
            m.put((Id) ar.get('tid'), ((Integer) ar.get('cnt')));
        }
        return m;
    }

    private static TournamentSummary toSummary(Tournament__c t,
                                               Map<Id, Integer> all,
                                               Map<Id, Integer> active,
                                               Map<Id, Integer> done) {
        TournamentSummary s = new TournamentSummary();
        s.id = t.Id;
        s.name = t.Name;
        s.status = t.Status__c;
        s.bracketType = t.Bracket_Type__c;
        s.examName = t.Certification_Exam__r == null ? null : t.Certification_Exam__r.Name;
        s.examCode = t.Certification_Exam__r == null ? null : t.Certification_Exam__r.Certification_Code__c;
        s.startAt = t.Start_At__c;
        s.endAt = t.End_At__c;
        s.completedAt = t.Completed_At__c;
        s.participantCount = all.containsKey(t.Id) ? all.get(t.Id) : 0;
        s.activeCount = active.containsKey(t.Id) ? active.get(t.Id) : 0;
        s.completedCount = done.containsKey(t.Id) ? done.get(t.Id) : 0;
        s.questionsPerMatch = t.Questions_Per_Match__c == null ? DEFAULT_QUESTIONS : t.Questions_Per_Match__c.intValue();
        s.maxParticipants = t.Max_Participants__c == null ? null : t.Max_Participants__c.intValue();
        s.publicJoinEnabled = t.Public_Join_Enabled__c;
        s.publicJoinToken = t.Public_Join_Token__c;
        if (t.Winner_Player__r != null) {
            s.winnerName = String.isBlank(t.Winner_Player__r.Google_Name__c)
                ? t.Winner_Player__r.Display_Name__c
                : t.Winner_Player__r.Google_Name__c;
        }
        s.prizeDescription = t.Prize_Description__c;
        return s;
    }

    // ----------------------------- Legacy methods (kept for compatibility) -----------

    @AuraEnabled
    public static Id createTournament(String name, String bracketType, Id examId, DateTime startAt, DateTime endAt) {
        if (String.isBlank(name) || String.isBlank(bracketType)) {
            throw new AuraHandledException('Name and bracket type are required.');
        }
        if (examId == null) {
            throw new AuraHandledException('Pick a certification exam before creating a tournament.');
        }
        Tournament__c t = new Tournament__c(
            Name = name,
            Bracket_Type__c = bracketType,
            Certification_Exam__c = examId,
            Start_At__c = startAt,
            End_At__c = endAt,
            Status__c = 'Scheduled',
            Public_Join_Token__c = generateToken(),
            Public_Join_Enabled__c = true,
            Questions_Per_Match__c = DEFAULT_QUESTIONS
        );
        insert as system t;
        AuditLogger.log('tournament_create', 'Tournament__c', t.Id, null, JSON.serialize(t), null);
        return t.Id;
    }

    @AuraEnabled
    public static String buildBracket(Id tournamentId, List<Id> playerIds) {
        List<Tournament__c> ts = [SELECT Id, Bracket_Type__c FROM Tournament__c
                                  WHERE Id = :tournamentId WITH SYSTEM_MODE LIMIT 1];
        if (ts.isEmpty()) throw new AuraHandledException('Tournament not found.');
        List<String> ids = new List<String>();
        for (Id pid : playerIds) ids.add(String.valueOf(pid));
        List<CertGameBracketGenerator.Pairing> pairings = CertGameBracketGenerator.generate(ts[0].Bracket_Type__c, ids);
        String json = JSON.serialize(pairings);
        ts[0].Bracket_Json__c = json.left(131000);
        update as system ts[0];
        return json;
    }

    public static String joinFromSlack(String slackTeamId, String slackUserId, String tournamentId) {
        if (String.isBlank(tournamentId)) return CertGameSlackRenderService.text(CertGameStrings.GENERIC_ERROR, true);
        Tenant__c t = CertGameTenantService.getOrCreateTenant(slackTeamId);
        Player__c p = CertGameTenantService.getOrCreatePlayer(t.Id, slackUserId);

        List<Tournament__c> ts = [SELECT Id, Status__c, Tenant__c FROM Tournament__c
                                  WHERE Id = :tournamentId AND Tenant__c = :t.Id WITH SYSTEM_MODE LIMIT 1];
        if (ts.isEmpty()) return CertGameSlackRenderService.text(CertGameStrings.TOURNAMENT_NOT_FOUND, true);

        try {
            upsertParticipant(ts[0].Id, p.Id, 'Slack');
        } catch (Exception e) { /* ignore */ }

        AuditLogger.log('tournament_join', 'Tournament__c', ts[0].Id, null, p.Id, slackUserId);
        return CertGameSlackRenderService.text('Joined tournament. Brackets will open at start time.', true);
    }

    public static String handleCreateSubmission(String slackTeamId, String slackUserId, Map<String, Object> view) {
        Tenant__c t = CertGameTenantService.getOrCreateTenant(slackTeamId);
        if (!EntitlementGuard.canCreateTournament(t.Id)) {
            return CertGameSlackRenderService.text(CertGameStrings.LOCKED_PREMIUM, true);
        }
        if (view == null) return '';
        Map<String, Object> stateWrap = (Map<String, Object>) view.get('state');
        if (stateWrap == null) return '';
        Map<String, Object> state = (Map<String, Object>) stateWrap.get('values');
        String examId = readVal(state, 'exam_block', 'exam');
        String name = readVal(state, 'name_block', 'name');
        if (String.isBlank(examId) || String.isBlank(name)) return '';
        Tournament__c tn = new Tournament__c(
            Tenant__c = t.Id,
            Certification_Exam__c = examId,
            Name = name,
            Bracket_Type__c = readVal(state, 'format_block', 'format'),
            Status__c = 'Scheduled',
            Public_Join_Token__c = generateToken(),
            Public_Join_Enabled__c = true,
            Questions_Per_Match__c = DEFAULT_QUESTIONS
        );
        insert as system tn;
        AuditLogger.log('tournament_create', 'Tournament__c', tn.Id, null, JSON.serialize(tn), slackUserId);
        return '';
    }

    private static String readVal(Map<String, Object> state, String block, String action) {
        if (state == null || !state.containsKey(block)) return null;
        Map<String, Object> b = (Map<String, Object>) state.get(block);
        if (!b.containsKey(action)) return null;
        Map<String, Object> a = (Map<String, Object>) b.get(action);
        if (a.containsKey('value')) return (String) a.get('value');
        Object sel = a.get('selected_option');
        if (sel instanceof Map<String, Object>) return (String) ((Map<String, Object>) sel).get('value');
        return null;
    }
}
