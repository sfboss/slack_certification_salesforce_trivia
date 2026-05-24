/**
 * Aggregator for the player profile dashboard.
 *
 * Two entry points:
 *  - load(playerId): explicit Player__c id (used by record page or admin views).
 *  - loadCurrentUser(): resolves Player__c for the running user via
 *    Player__c.Salesforce_User__c, otherwise via Mapped_Contact__c.
 */
public with sharing class CertGamePlayerDashboardController {
    public class PlayerDto {
        @AuraEnabled
        public Id id;
        @AuraEnabled
        public String displayName;
        @AuraEnabled
        public String tenantName;
        @AuraEnabled
        public Id tenantId;
        @AuraEnabled
        public String timezone;
        @AuraEnabled
        public Decimal totalPoints;
        @AuraEnabled
        public Integer totalGames;
        @AuraEnabled
        public Decimal accuracy;
        @AuraEnabled
        public Integer currentStreakDays;
        @AuraEnabled
        public Integer longestStreakDays;
        @AuraEnabled
        public Datetime lastPlayedAt;
        @AuraEnabled
        public Integer rank;
        @AuraEnabled
        public Integer rankPool;
        @AuraEnabled
        public Decimal accuracyLast50;
    }

    public class DomainAccuracyDto {
        @AuraEnabled
        public Id domainId;
        @AuraEnabled
        public String domainName;
        @AuraEnabled
        public Integer answered;
        @AuraEnabled
        public Integer correct;
        @AuraEnabled
        public Decimal accuracy;
    }

    public class RecentAnswerDto {
        @AuraEnabled
        public Id id;
        @AuraEnabled
        public Datetime answeredAt;
        @AuraEnabled
        public String questionText;
        @AuraEnabled
        public Boolean isCorrect;
        @AuraEnabled
        public Decimal points;
        @AuraEnabled
        public Integer responseMs;
        @AuraEnabled
        public String examName;
    }

    public class AchievementDto {
        @AuraEnabled
        public Id id;
        @AuraEnabled
        public Datetime awardedAt;
        @AuraEnabled
        public String name;
        @AuraEnabled
        public String description;
        @AuraEnabled
        public String iconEmoji;
        @AuraEnabled
        public Decimal points;
    }

    public class StudyPlanDto {
        @AuraEnabled
        public Id id;
        @AuraEnabled
        public String examName;
        @AuraEnabled
        public Date targetExamDate;
        @AuraEnabled
        public Decimal dailyQuestions;
        @AuraEnabled
        public Boolean active;
        @AuraEnabled
        public Datetime nextNudgeAt;
    }

    public class DashboardDto {
        @AuraEnabled
        public PlayerDto player;
        @AuraEnabled
        public List<DomainAccuracyDto> domains;
        @AuraEnabled
        public List<RecentAnswerDto> recentAnswers;
        @AuraEnabled
        public List<AchievementDto> achievements;
        @AuraEnabled
        public List<StudyPlanDto> studyPlans;
    }

    @AuraEnabled(cacheable=true)
    public static DashboardDto loadCurrentUser() {
        Id me = UserInfo.getUserId();
        List<Player__c> ps = [
            SELECT Id
            FROM Player__c
            WHERE Salesforce_User__c = :me
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (ps.isEmpty()) {
            // Try via mapped contact: User.ContactId -> Player.Mapped_Contact__c
            Id contactId;
            for (User u : [
                SELECT ContactId
                FROM User
                WHERE Id = :me
                WITH SYSTEM_MODE
                LIMIT 1
            ]) {
                contactId = u.ContactId;
            }
            if (contactId != null) {
                ps = [
                    SELECT Id
                    FROM Player__c
                    WHERE Mapped_Contact__c = :contactId
                    WITH SYSTEM_MODE
                    LIMIT 1
                ];
            }
        }
        if (ps.isEmpty())
            return new DashboardDto();
        return load(ps[0].Id);
    }

    @AuraEnabled(cacheable=true)
    public static DashboardDto load(Id playerId) {
        DashboardDto out = new DashboardDto();
        out.domains = new List<DomainAccuracyDto>();
        out.recentAnswers = new List<RecentAnswerDto>();
        out.achievements = new List<AchievementDto>();
        out.studyPlans = new List<StudyPlanDto>();

        List<Player__c> players = [
            SELECT
                Id,
                Display_Name__c,
                Tenant__c,
                Tenant__r.Workspace_Name__c,
                Timezone__c,
                Total_Points__c,
                Total_Games__c,
                Accuracy__c,
                Current_Streak_Days__c,
                Longest_Streak_Days__c,
                Last_Played_At__c
            FROM Player__c
            WHERE Id = :playerId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        if (players.isEmpty())
            return out;
        Player__c p = players[0];

        PlayerDto pd = new PlayerDto();
        pd.id = p.Id;
        pd.displayName = p.Display_Name__c;
        pd.tenantId = p.Tenant__c;
        pd.tenantName = p.Tenant__r == null
            ? ''
            : p.Tenant__r.Workspace_Name__c;
        pd.timezone = p.Timezone__c;
        pd.totalPoints = p.Total_Points__c == null ? 0 : p.Total_Points__c;
        pd.totalGames = p.Total_Games__c == null
            ? 0
            : p.Total_Games__c.intValue();
        pd.accuracy = p.Accuracy__c == null ? 0 : p.Accuracy__c;
        pd.currentStreakDays = p.Current_Streak_Days__c == null
            ? 0
            : p.Current_Streak_Days__c.intValue();
        pd.longestStreakDays = p.Longest_Streak_Days__c == null
            ? 0
            : p.Longest_Streak_Days__c.intValue();
        pd.lastPlayedAt = p.Last_Played_At__c;

        // Rank within tenant
        if (p.Tenant__c != null) {
            pd.rankPool = [
                SELECT COUNT()
                FROM Player__c
                WHERE Tenant__c = :p.Tenant__c
                WITH SYSTEM_MODE
            ];
            Integer ahead = [
                SELECT COUNT()
                FROM Player__c
                WHERE
                    Tenant__c = :p.Tenant__c
                    AND Total_Points__c > :pd.totalPoints
                WITH SYSTEM_MODE
            ];
            pd.rank = ahead + 1;
        }

        // Per-domain accuracy
        Map<Id, DomainAccuracyDto> dmap = new Map<Id, DomainAccuracyDto>();
        for (AggregateResult ar : [
            SELECT
                Trivia_Question__r.Exam_Domain__c d,
                Is_Correct__c c,
                COUNT(Id) n
            FROM Player_Answer__c
            WHERE
                Player__c = :playerId
                AND Trivia_Question__r.Exam_Domain__c != NULL
            WITH SYSTEM_MODE
            GROUP BY Trivia_Question__r.Exam_Domain__c, Is_Correct__c
        ]) {
            Id did = (Id) ar.get('d');
            Integer n = (Integer) ar.get('n');
            DomainAccuracyDto d = dmap.get(did);
            if (d == null) {
                d = new DomainAccuracyDto();
                d.domainId = did;
                d.answered = 0;
                d.correct = 0;
                dmap.put(did, d);
            }
            d.answered += n;
            if (ar.get('c') == true)
                d.correct += n;
        }
        if (!dmap.isEmpty()) {
            for (Exam_Domain__c ed : [
                SELECT Id, Name
                FROM Exam_Domain__c
                WHERE Id IN :dmap.keySet()
                WITH SYSTEM_MODE
            ]) {
                dmap.get(ed.Id).domainName = ed.Name;
            }
            for (DomainAccuracyDto d : dmap.values()) {
                d.accuracy = d.answered == 0
                    ? 0
                    : (Decimal.valueOf(d.correct) *
                          100 /
                          d.answered)
                          .setScale(1);
                out.domains.add(d);
            }
        }

        // Recent answers (last 25)
        List<Player_Answer__c> ans = [
            SELECT
                Id,
                Answered_At__c,
                Is_Correct__c,
                Points_Awarded__c,
                Response_Time_Ms__c,
                Trivia_Question__r.Question_Text__c,
                Trivia_Question__r.Certification_Exam__r.Name
            FROM Player_Answer__c
            WHERE Player__c = :playerId
            WITH SYSTEM_MODE
            ORDER BY Answered_At__c DESC
            LIMIT 25
        ];
        Integer totalRecent = 0;
        Integer correctRecent = 0;
        for (Player_Answer__c a : ans) {
            RecentAnswerDto r = new RecentAnswerDto();
            r.id = a.Id;
            r.answeredAt = a.Answered_At__c;
            r.isCorrect = a.Is_Correct__c;
            r.points = a.Points_Awarded__c;
            r.responseMs = a.Response_Time_Ms__c == null
                ? null
                : a.Response_Time_Ms__c.intValue();
            if (a.Trivia_Question__r != null) {
                r.questionText = a.Trivia_Question__r.Question_Text__c;
                if (a.Trivia_Question__r.Certification_Exam__r != null) {
                    r.examName = a.Trivia_Question__r.Certification_Exam__r.Name;
                }
            }
            out.recentAnswers.add(r);
            totalRecent++;
            if (a.Is_Correct__c == true)
                correctRecent++;
        }
        pd.accuracyLast50 = totalRecent == 0
            ? 0
            : (Decimal.valueOf(correctRecent) * 100 / totalRecent).setScale(1);

        // Achievements
        for (Player_Achievement__c pa : [
            SELECT
                Id,
                Awarded_At__c,
                Achievement__r.Name,
                Achievement__r.Description__c,
                Achievement__r.Icon_Emoji__c,
                Achievement__r.Points__c
            FROM Player_Achievement__c
            WHERE Player__c = :playerId
            WITH SYSTEM_MODE
            ORDER BY Awarded_At__c DESC NULLS LAST
            LIMIT 25
        ]) {
            AchievementDto a = new AchievementDto();
            a.id = pa.Id;
            a.awardedAt = pa.Awarded_At__c;
            if (pa.Achievement__r != null) {
                a.name = pa.Achievement__r.Name;
                a.description = pa.Achievement__r.Description__c;
                a.iconEmoji = pa.Achievement__r.Icon_Emoji__c;
                a.points = pa.Achievement__r.Points__c;
            }
            out.achievements.add(a);
        }

        // Study plans
        for (Study_Plan__c sp : [
            SELECT
                Id,
                Active__c,
                Daily_Questions__c,
                Next_Nudge_At__c,
                Target_Exam_Date__c,
                Certification_Exam__r.Name
            FROM Study_Plan__c
            WHERE Player__c = :playerId
            WITH SYSTEM_MODE
            ORDER BY Active__c DESC, CreatedDate DESC
            LIMIT 10
        ]) {
            StudyPlanDto s = new StudyPlanDto();
            s.id = sp.Id;
            s.active = sp.Active__c;
            s.dailyQuestions = sp.Daily_Questions__c;
            s.nextNudgeAt = sp.Next_Nudge_At__c;
            s.targetExamDate = sp.Target_Exam_Date__c;
            if (sp.Certification_Exam__r != null)
                s.examName = sp.Certification_Exam__r.Name;
            out.studyPlans.add(s);
        }

        out.player = pd;
        return out;
    }
}