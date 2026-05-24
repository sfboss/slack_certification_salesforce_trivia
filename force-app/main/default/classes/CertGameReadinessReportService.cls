/**
 * Builds the HTML "Readiness Report" for a player by merging player metrics
 * into the readinessReportTemplate static resource.
 *
 * Surface: read by CertGameReadinessReportController (Visualforce page on the
 * public certgame Site). Slack final card links to that page.
 *
 * Sharing: without sharing - invoked by the public-site Guest user. All SOQL
 * uses SYSTEM_MODE (same pattern as CertGameSessionService).
 */
public without sharing class CertGameReadinessReportService {
    private static final Integer TREND_DAYS = 30;
    private static final Integer DEFAULT_PASS_THRESHOLD = 65;
    private static final Integer DEFAULT_EXAM_MINUTES = 105;
    private static final Integer DEFAULT_TOTAL_QUESTIONS = 60;

    public static String renderHtml(Id playerId, Id examId) {
        return renderHtml(playerId, examId, null);
    }

    public static String renderHtml(Id playerId, Id examId, String themeKey) {
        String template = loadTemplate(themeKey);
        Map<String, String> mergeFields = gather(playerId, examId);
        mergeFields.put('theme_key', escape(resolveThemeKey(themeKey)));
        return applyMerge(template, mergeFields);
    }

    /**
     * Lightweight DTO surfaced to the admin LWC and Slack pickers.
     */
    public class ThemeOption {
        @AuraEnabled
        public Id id;
        @AuraEnabled
        public String key;
        @AuraEnabled
        public String name;
        @AuraEnabled
        public String description;
        @AuraEnabled
        public Boolean isDefault;
        @AuraEnabled
        public Boolean active;
        @AuraEnabled
        public Integer sortOrder;
    }

    public static List<ThemeOption> listActiveThemes() {
        List<ThemeOption> out = new List<ThemeOption>();
        for (Study_Guide_Theme__c t : [
            SELECT
                Id,
                Name,
                Theme_Key__c,
                Description__c,
                Active__c,
                Is_Default__c,
                Sort_Order__c
            FROM Study_Guide_Theme__c
            WHERE Active__c = TRUE
            WITH SYSTEM_MODE
            ORDER BY Is_Default__c DESC, Sort_Order__c ASC NULLS LAST, Name ASC
            LIMIT 100
        ]) {
            ThemeOption o = new ThemeOption();
            o.id = t.Id;
            o.key = t.Theme_Key__c;
            o.name = t.Name;
            o.description = t.Description__c;
            o.isDefault = t.Is_Default__c == true;
            o.active = t.Active__c == true;
            o.sortOrder = t.Sort_Order__c == null
                ? null
                : t.Sort_Order__c.intValue();
            out.add(o);
        }
        return out;
    }

    public static String resolveThemeKey(String requested) {
        if (String.isNotBlank(requested))
            return requested.toLowerCase();
        List<Study_Guide_Theme__c> defs = [
            SELECT Theme_Key__c
            FROM Study_Guide_Theme__c
            WHERE Active__c = TRUE AND Is_Default__c = TRUE
            WITH SYSTEM_MODE
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        if (!defs.isEmpty() && String.isNotBlank(defs[0].Theme_Key__c)) {
            return defs[0].Theme_Key__c.toLowerCase();
        }
        return 'editorial';
    }

    public static Map<String, String> gather(Id playerId, Id examId) {
        Map<String, String> m = new Map<String, String>();

        Player__c player = readPlayer(playerId);
        Certification_Exam__c exam = readExam(examId, player);

        String userName = player == null
            ? 'Candidate'
            : (String.isNotBlank(player.Display_Name__c)
                  ? player.Display_Name__c
                  : (String.isNotBlank(player.Google_Name__c)
                        ? player.Google_Name__c
                        : 'Candidate'));
        String certName = exam == null
            ? 'Salesforce Certification'
            : (String.isNotBlank(exam.Name)
                  ? exam.Name
                  : exam.Certification_Code__c);

        Date today = Date.today();
        m.put('user_name', escape(userName));
        m.put('cert_name', escape(certName));
        m.put('report_date', today.format());
        m.put(
            'report_number',
            String.valueOf(
                Math.mod(
                    today.toStartOfWeek().daysBetween(today) +
                    (today.year() * 52),
                    999
                ) + 1
            )
        );
        m.put('next_report_date', today.addDays(7).format());

        Date examDate = today.addDays(30);
        m.put('exam_date', examDate.format());
        m.put(
            'days_until_exam',
            String.valueOf(Math.max(0, today.daysBetween(examDate)))
        );

        m.put('pass_threshold', String.valueOf(DEFAULT_PASS_THRESHOLD));
        m.put('exam_minutes', String.valueOf(DEFAULT_EXAM_MINUTES));
        m.put(
            'exam_seconds_per_q',
            String.valueOf(
                (DEFAULT_EXAM_MINUTES * 60) / DEFAULT_TOTAL_QUESTIONS
            )
        );

        // ---- Headline stats ----
        Integer totalAnswered = 0;
        Integer totalCorrect = 0;
        Integer totalSessions = 0;
        List<TimingPoint> correctPts = new List<TimingPoint>();
        List<TimingPoint> wrongPts = new List<TimingPoint>();
        Map<Date, Integer> dailyCorrect = new Map<Date, Integer>();
        Map<Date, Integer> dailyTotal = new Map<Date, Integer>();
        List<Decimal> timesSec = new List<Decimal>();
        DateTime cutoff = DateTime.now().addDays(-TREND_DAYS);
        Set<Id> sessionIds = new Set<Id>();

        for (Player_Answer__c pa : [
            SELECT
                Answered_At__c,
                Is_Correct__c,
                Response_Time_Ms__c,
                Game_Session__c
            FROM Player_Answer__c
            WHERE Player__c = :playerId AND Answered_At__c >= :cutoff
            WITH SYSTEM_MODE
            ORDER BY Answered_At__c ASC
            LIMIT 5000
        ]) {
            totalAnswered++;
            if (pa.Is_Correct__c)
                totalCorrect++;
            if (pa.Game_Session__c != null)
                sessionIds.add(pa.Game_Session__c);
            Date d = pa.Answered_At__c == null
                ? today
                : pa.Answered_At__c.date();
            dailyTotal.put(
                d,
                (dailyTotal.containsKey(d) ? dailyTotal.get(d) : 0) + 1
            );
            if (pa.Is_Correct__c) {
                dailyCorrect.put(
                    d,
                    (dailyCorrect.containsKey(d) ? dailyCorrect.get(d) : 0) + 1
                );
            }
            Decimal secs = pa.Response_Time_Ms__c == null
                ? null
                : (pa.Response_Time_Ms__c / 1000);
            if (secs != null && secs > 0 && secs < 600) {
                timesSec.add(secs);
                Decimal y = pa.Is_Correct__c ? 1 : 0;
                TimingPoint tp = new TimingPoint();
                tp.x = secs;
                tp.y = y;
                if (pa.Is_Correct__c)
                    correctPts.add(tp);
                else
                    wrongPts.add(tp);
            }
        }
        totalSessions = sessionIds.size();
        Integer overallAcc = totalAnswered == 0
            ? 0
            : (totalCorrect * 100) / totalAnswered;

        m.put('overall_accuracy', String.valueOf(overallAcc));
        m.put('total_questions', String.valueOf(totalAnswered));
        m.put('total_sessions', String.valueOf(totalSessions));
        m.put(
            'streak_days',
            String.valueOf(
                player == null ||
                    player.Current_Streak_Days__c == null
                    ? 0
                    : player.Current_Streak_Days__c.intValue()
            )
        );
        m.put(
            'longest_streak',
            String.valueOf(
                player == null ||
                    player.Longest_Streak_Days__c == null
                    ? 0
                    : player.Longest_Streak_Days__c.intValue()
            )
        );

        // Week-over-week delta
        Integer prevAcc = computeWindowAccuracy(
            playerId,
            cutoff.addDays(-7),
            cutoff
        );
        Integer recentAcc = computeWindowAccuracy(
            playerId,
            DateTime.now().addDays(-7),
            DateTime.now()
        );
        Integer delta = recentAcc - prevAcc;
        m.put('accuracy_delta', String.valueOf(Math.abs(delta)));
        if (delta > 0) {
            m.put('accuracy_delta_arrow', '\u25B2');
            m.put('accuracy_delta_class', 'up');
        } else if (delta < 0) {
            m.put('accuracy_delta_arrow', '\u25BC');
            m.put('accuracy_delta_class', 'down');
        } else {
            m.put('accuracy_delta_arrow', '\u2500');
            m.put('accuracy_delta_class', 'flat');
        }

        // ---- Trend (30 day rolling 7-day accuracy) ----
        List<String> trendLabels = new List<String>();
        List<Integer> trendData = new List<Integer>();
        for (Integer i = TREND_DAYS - 1; i >= 0; i--) {
            Date d = today.addDays(-i);
            Integer wCorrect = 0, wTotal = 0;
            for (Integer j = 0; j < 7; j++) {
                Date d2 = d.addDays(-j);
                wTotal += dailyTotal.containsKey(d2) ? dailyTotal.get(d2) : 0;
                wCorrect += dailyCorrect.containsKey(d2)
                    ? dailyCorrect.get(d2)
                    : 0;
            }
            Integer acc = wTotal == 0
                ? (trendData.isEmpty()
                      ? overallAcc
                      : trendData[trendData.size() - 1])
                : (wCorrect * 100) / wTotal;
            trendData.add(acc);
            trendLabels.add(formatShortDate(d));
        }
        m.put('trend_labels_json', JSON.serialize(trendLabels));
        m.put('trend_data_json', JSON.serialize(trendData));

        // ---- Difficulty breakdown ----
        Map<String, Player_Topic_Stat__c> diffStats = new Map<String, Player_Topic_Stat__c>();
        for (Player_Topic_Stat__c s : [
            SELECT
                Topic_Value__c,
                Times_Seen__c,
                Times_Correct__c,
                Accuracy_Pct__c
            FROM Player_Topic_Stat__c
            WHERE Player__c = :playerId AND Topic_Type__c = 'Difficulty'
            WITH SYSTEM_MODE
        ]) {
            diffStats.put(s.Topic_Value__c, s);
        }
        List<String> diffLabels = new List<String>{ 'Easy', 'Medium', 'Hard' };
        List<Integer> diffData = new List<Integer>();
        for (String lbl : diffLabels) {
            Player_Topic_Stat__c s = diffStats.get(lbl);
            diffData.add(
                s == null ||
                    s.Accuracy_Pct__c == null
                    ? 0
                    : s.Accuracy_Pct__c.intValue()
            );
        }
        m.put('difficulty_labels_json', JSON.serialize(diffLabels));
        m.put('difficulty_data_json', JSON.serialize(diffData));

        // ---- Timing scatter ----
        m.put('timing_correct_json', JSON.serialize(correctPts));
        m.put('timing_wrong_json', JSON.serialize(wrongPts));

        Decimal median = medianOf(timesSec);
        m.put(
            'median_time',
            median == null ? '-' : String.valueOf(median.setScale(0))
        );
        Integer wrongAvg = wrongPts.isEmpty()
            ? 0
            : averageX(wrongPts).intValue();
        Integer rightAvg = correctPts.isEmpty()
            ? 0
            : averageX(correctPts).intValue();
        String commentary = (rightAvg > 0 &&
            wrongAvg > rightAvg)
            ? 'Questions you eventually get wrong consume on average ' +
              Math.round(((wrongAvg - rightAvg) * 100.0) / rightAvg) +
              '% more time than ones you answer correctly. That delta is your hesitation tax.'
            : 'Keep building a steady rhythm - you have not yet logged enough timed data for a hesitation analysis.';
        m.put('timing_commentary', escape(commentary));

        // ---- Domain rows ----
        List<Player_Topic_Stat__c> domainStats = [
            SELECT
                Topic_Value__c,
                Times_Seen__c,
                Times_Correct__c,
                Accuracy_Pct__c
            FROM Player_Topic_Stat__c
            WHERE
                Player__c = :playerId
                AND Topic_Type__c = 'Domain'
                AND Times_Seen__c > 0
            WITH SYSTEM_MODE
            ORDER BY Accuracy_Pct__c DESC NULLS LAST
            LIMIT 12
        ];
        m.put('domain_rows_html', renderDomainRows(domainStats));

        // ---- Weak questions ----
        m.put('weak_q_html', renderWeakQuestions(playerId));

        // ---- Streak calendar ----
        List<Integer> streakSeed = new List<Integer>();
        for (Integer i = 0; i < 91; i++)
            streakSeed.add(0);
        Map<Date, Integer> all91 = new Map<Date, Integer>();
        for (Player_Answer__c pa : [
            SELECT Answered_At__c
            FROM Player_Answer__c
            WHERE
                Player__c = :playerId
                AND Answered_At__c >= :DateTime.now().addDays(-91)
            WITH SYSTEM_MODE
        ]) {
            Date d = pa.Answered_At__c == null
                ? today
                : pa.Answered_At__c.date();
            all91.put(d, (all91.containsKey(d) ? all91.get(d) : 0) + 1);
        }
        for (Integer i = 0; i < 91; i++) {
            Date d = today.addDays(-(90 - i));
            Integer cnt = all91.containsKey(d) ? all91.get(d) : 0;
            Integer lvl = cnt == 0
                ? 0
                : (cnt < 5 ? 1 : (cnt < 15 ? 2 : (cnt < 30 ? 3 : 4)));
            // Map index i (chronological) into the 7-row x 13-col grid the JS expects.
            Integer row = Math.mod(i, 7);
            Integer col = i / 7;
            if (col < 13)
                streakSeed.set(row * 13 + col, lvl);
        }
        m.put('streak_seed_json', JSON.serialize(streakSeed));

        // ---- Verdict + summary prose ----
        Integer readiness = computeReadiness(overallAcc, domainStats, player);
        m.put('readiness_score', String.valueOf(readiness));
        m.put(
            'readiness_label',
            readiness >= 80
                ? 'Ready to sit'
                : readiness >= 65
                      ? 'On track'
                      : readiness >= 50 ? 'Needs work' : 'Not yet'
        );

        m.put(
            'headline_verdict',
            escape(buildHeadline(overallAcc, readiness, totalAnswered))
        );
        m.put(
            'summary_paragraph_1',
            escape(
                buildSummaryP1(userName, overallAcc, totalAnswered, domainStats)
            )
        );
        m.put(
            'summary_paragraph_2',
            escape(buildSummaryP2(overallAcc, delta, totalSessions))
        );
        m.put('summary_pullquote', escape(buildPullquote(domainStats)));
        m.put(
            'verdict_paragraph',
            escape(buildVerdict(readiness, examDate, domainStats))
        );

        // ---- Recommendations ----
        m.put(
            'recommendations_html',
            renderRecommendations(domainStats, overallAcc)
        );

        // ---- chart.js src ----
        m.put('chartjs_src', chartJsUrl());

        return m;
    }

    // ---------------- private helpers ----------------

    public class TimingPoint {
        public Decimal x;
        public Decimal y;
    }

    private static Player__c readPlayer(Id playerId) {
        if (playerId == null)
            return null;
        List<Player__c> ps = [
            SELECT
                Id,
                Display_Name__c,
                Google_Name__c,
                Current_Streak_Days__c,
                Longest_Streak_Days__c,
                Total_Games__c,
                Total_Points__c,
                Tenant__c
            FROM Player__c
            WHERE Id = :playerId
            WITH SYSTEM_MODE
            LIMIT 1
        ];
        return ps.isEmpty() ? null : ps[0];
    }

    private static Certification_Exam__c readExam(Id examId, Player__c player) {
        if (examId != null) {
            List<Certification_Exam__c> es = [
                SELECT Id, Name, Certification_Code__c
                FROM Certification_Exam__c
                WHERE Id = :examId
                WITH SYSTEM_MODE
                LIMIT 1
            ];
            if (!es.isEmpty())
                return es[0];
        }
        if (player != null) {
            List<Game_Session__c> gs = [
                SELECT
                    Certification_Exam__c,
                    Certification_Exam__r.Name,
                    Certification_Exam__r.Certification_Code__c
                FROM Game_Session__c
                WHERE
                    Tenant__c = :player.Tenant__c
                    AND Certification_Exam__c != NULL
                WITH SYSTEM_MODE
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            if (!gs.isEmpty()) {
                Certification_Exam__c e = new Certification_Exam__c(
                    Id = gs[0].Certification_Exam__c,
                    Name = gs[0].Certification_Exam__r.Name,
                    Certification_Code__c = gs[0]
                        .Certification_Exam__r.Certification_Code__c
                );
                return e;
            }
        }
        return null;
    }

    private static Integer computeWindowAccuracy(
        Id playerId,
        DateTime fromDt,
        DateTime toDt
    ) {
        AggregateResult[] ars = [
            SELECT Is_Correct__c isCorrect, COUNT(Id) cnt
            FROM Player_Answer__c
            WHERE
                Player__c = :playerId
                AND Answered_At__c >= :fromDt
                AND Answered_At__c < :toDt
            WITH SYSTEM_MODE
            GROUP BY Is_Correct__c
        ];
        Integer total = 0, ok = 0;
        for (AggregateResult ar : ars) {
            Integer c = ((Decimal) ar.get('cnt')).intValue();
            total += c;
            if (((Boolean) ar.get('isCorrect')) == true)
                ok += c;
        }
        return total == 0 ? 0 : (ok * 100) / total;
    }

    private static String renderDomainRows(List<Player_Topic_Stat__c> stats) {
        if (stats == null || stats.isEmpty()) {
            return '<div class="domain-row"><div class="domain-name">No domain data yet<small>play a few rounds</small></div><div class="domain-bar"></div><div class="domain-pct">-</div><div class="domain-trend">-</div><div class="domain-status">-</div></div>';
        }
        String html = '';
        for (Player_Topic_Stat__c s : stats) {
            Integer acc = s.Accuracy_Pct__c == null
                ? 0
                : s.Accuracy_Pct__c.intValue();
            String klass = acc >= 75
                ? 'strong'
                : acc >= DEFAULT_PASS_THRESHOLD ? 'mid' : 'weak';
            String statusLabel = acc >= 75
                ? 'Strong'
                : acc >= DEFAULT_PASS_THRESHOLD
                      ? 'Stable'
                      : (acc >= 50 ? 'At Risk' : 'Critical');
            String statusKlass = klass == 'strong'
                ? 'status-strong'
                : klass == 'mid' ? 'status-mid' : 'status-weak';
            Integer seen = s.Times_Seen__c == null
                ? 0
                : s.Times_Seen__c.intValue();
            html +=
                '<div class="domain-row">' +
                '<div class="domain-name">' +
                escape(s.Topic_Value__c) +
                '<small>' +
                seen +
                ' questions</small></div>' +
                '<div class="domain-bar"><div class="domain-bar-fill ' +
                klass +
                '" style="width: ' +
                acc +
                '%;"></div>' +
                '<div class="domain-bar-target" style="left: ' +
                DEFAULT_PASS_THRESHOLD +
                '%;"></div></div>' +
                '<div class="domain-pct">' +
                acc +
                '%</div>' +
                '<div class="domain-trend" style="color: var(--muted);">-</div>' +
                '<div class="domain-status ' +
                statusKlass +
                '">' +
                statusLabel +
                '</div>' +
                '</div>';
        }
        return html;
    }

    private static String renderWeakQuestions(Id playerId) {
        AggregateResult[] groups = [
            SELECT
                Trivia_Question__c qid,
                COUNT(Id) misses,
                MAX(Answered_At__c) lastSeen
            FROM Player_Answer__c
            WHERE Player__c = :playerId AND Is_Correct__c = FALSE
            WITH SYSTEM_MODE
            GROUP BY Trivia_Question__c
            HAVING COUNT(Id) >= 2
            ORDER BY COUNT(Id) DESC
            LIMIT 5
        ];
        if (groups.isEmpty()) {
            return '<div class="weak-q"><div class="weak-q-text">No repeat-miss pattern yet - keep playing to surface your sticky questions.</div></div>';
        }
        Set<Id> qIds = new Set<Id>();
        for (AggregateResult ar : groups)
            qIds.add((Id) ar.get('qid'));

        Map<Id, Trivia_Question__c> qMap = new Map<Id, Trivia_Question__c>(
            [
                SELECT Id, Question_Text__c, Exam_Domain__r.Name
                FROM Trivia_Question__c
                WHERE Id IN :qIds
                WITH SYSTEM_MODE
            ]
        );
        // Last picked + correct choice text per question for this player
        Map<Id, String> pickedById = new Map<Id, String>();
        for (Player_Answer__c pa : [
            SELECT Trivia_Question__c, Selected_Choice_Text__c, Answered_At__c
            FROM Player_Answer__c
            WHERE
                Player__c = :playerId
                AND Trivia_Question__c IN :qIds
                AND Is_Correct__c = FALSE
            WITH SYSTEM_MODE
            ORDER BY Answered_At__c DESC
        ]) {
            if (!pickedById.containsKey(pa.Trivia_Question__c)) {
                pickedById.put(
                    pa.Trivia_Question__c,
                    pa.Selected_Choice_Text__c
                );
            }
        }
        Map<Id, String> correctById = new Map<Id, String>();
        for (Trivia_Answer_Choice__c c : [
            SELECT Trivia_Question__c, Choice_Text__c
            FROM Trivia_Answer_Choice__c
            WHERE Trivia_Question__c IN :qIds AND Is_Correct__c = TRUE
            WITH SYSTEM_MODE
        ]) {
            correctById.put(c.Trivia_Question__c, c.Choice_Text__c);
        }

        String html = '';
        for (AggregateResult ar : groups) {
            Id qid = (Id) ar.get('qid');
            Trivia_Question__c q = qMap.get(qid);
            if (q == null)
                continue;
            Integer misses = ((Decimal) ar.get('misses')).intValue();
            DateTime lastSeen = (DateTime) ar.get('lastSeen');
            String domain = q.Exam_Domain__r == null
                ? 'General'
                : q.Exam_Domain__r.Name;
            String picked = pickedById.containsKey(qid)
                ? pickedById.get(qid)
                : '-';
            String correct = correctById.containsKey(qid)
                ? correctById.get(qid)
                : '-';
            html +=
                '<div class="weak-q">' +
                '<div class="weak-q-meta">' +
                '<span>' +
                escape(domain) +
                '</span>' +
                '<span class="miss">Missed ' +
                misses +
                '\u00D7</span>' +
                '<span>Last seen: ' +
                relativeTime(lastSeen) +
                '</span>' +
                '</div>' +
                '<div class="weak-q-text">' +
                escape(q.Question_Text__c) +
                '</div>' +
                '<div class="weak-q-answers">' +
                '<span class="picked">' +
                escape(truncate(picked, 80)) +
                '</span>' +
                '<span class="correct">' +
                escape(truncate(correct, 80)) +
                '</span>' +
                '</div></div>';
        }
        return html;
    }

    private static String renderRecommendations(
        List<Player_Topic_Stat__c> domains,
        Integer overallAcc
    ) {
        List<String> items = new List<String>();
        // 1. Weakest domain drill
        Player_Topic_Stat__c weakest;
        for (Player_Topic_Stat__c s : domains) {
            Integer acc = s.Accuracy_Pct__c == null
                ? 0
                : s.Accuracy_Pct__c.intValue();
            if (
                acc < DEFAULT_PASS_THRESHOLD &&
                (weakest == null ||
                acc <
                (weakest.Accuracy_Pct__c == null
                    ? 0
                    : weakest.Accuracy_Pct__c.intValue()))
            ) {
                weakest = s;
            }
        }
        if (weakest != null) {
            Integer acc = weakest.Accuracy_Pct__c == null
                ? 0
                : weakest.Accuracy_Pct__c.intValue();
            items.add(
                recItem(
                    'i.',
                    'Drill the ' +
                        escape(weakest.Topic_Value__c) +
                        ' domain to ' +
                        DEFAULT_PASS_THRESHOLD +
                        '% before the exam.',
                    'You are ' +
                        (DEFAULT_PASS_THRESHOLD - acc) +
                        ' points below the pass line on this domain. Target 40 practice questions focused on this area.',
                    new List<String>{
                        'Domain - ' + weakest.Topic_Value__c,
                        '40 questions',
                        '~90 minutes'
                    }
                )
            );
        } else {
            items.add(
                recItem(
                    'i.',
                    'Keep your strong domains warm.',
                    'You are above the pass line on every measured domain. Light, daily review prevents regression.',
                    new List<String>{ 'Maintenance', '15 questions/day' }
                )
            );
        }
        // 2. Generic study
        items.add(
            recItem(
                'ii.',
                'Revisit your most-missed question explanations.',
                'Your misses cluster on a handful of questions. Re-read the explanation and primary reference for each one - most are conceptual, not edge-case.',
                new List<String>{ 'Review', 'Read & watch', '~60 minutes' }
            )
        );
        // 3. Full mock
        items.add(
            recItem(
                'iii.',
                'Schedule one full-length timed practice exam.',
                'Stamina and pacing under pressure are skills distinct from per-question accuracy. Block ' +
                    DEFAULT_EXAM_MINUTES +
                    ' minutes this week.',
                new List<String>{
                    'Format - Full mock',
                    DEFAULT_TOTAL_QUESTIONS + ' questions',
                    DEFAULT_EXAM_MINUTES + ' minutes'
                }
            )
        );
        return String.join(items, '\n');
    }

    private static String recItem(
        String num,
        String h,
        String p,
        List<String> tags
    ) {
        String t = '';
        for (String tag : tags)
            t += '<span class="rec-tag">' + escape(tag) + '</span>';
        return '<div class="rec-item"><div class="rec-num">' +
            num +
            '</div><div class="rec-content"><h4>' +
            h +
            '</h4><p>' +
            p +
            '</p>' +
            t +
            '</div></div>';
    }

    private static String buildHeadline(
        Integer acc,
        Integer readiness,
        Integer answered
    ) {
        if (answered == 0)
            return 'No data yet - play a session to unlock your first reading.';
        if (readiness >= 80)
            return 'You are tracking ahead of pace. Stay disciplined and you walk in confident.';
        if (readiness >= 65)
            return 'Solid trajectory - a few targeted drills tighten the floor.';
        if (readiness >= 50)
            return 'Foundation is there. The work this week is closing the weak domains.';
        return 'Too early to call ready - invest in the fundamentals before sitting the exam.';
    }

    private static String buildSummaryP1(
        String name,
        Integer acc,
        Integer answered,
        List<Player_Topic_Stat__c> domains
    ) {
        if (answered == 0) {
            return name +
                ', this is your inaugural diagnostic. Play a few rounds and the report fills in.';
        }
        Integer weakCount = 0;
        for (Player_Topic_Stat__c s : domains) {
            Integer a = s.Accuracy_Pct__c == null
                ? 0
                : s.Accuracy_Pct__c.intValue();
            if (a < DEFAULT_PASS_THRESHOLD)
                weakCount++;
        }
        String shape = acc >= 75
            ? 'in strong shape'
            : acc >= 60 ? 'on the cusp' : 'below the line';
        String wcText = weakCount == 0
            ? 'no domains'
            : (weakCount + ' domain' + (weakCount == 1 ? '' : 's'));
        return name +
            ', after ' +
            answered +
            ' questions you sit at ' +
            acc +
            '% overall - ' +
            shape +
            ' with ' +
            wcText +
            ' currently under the pass threshold.';
    }

    private static String buildSummaryP2(
        Integer acc,
        Integer delta,
        Integer sessions
    ) {
        String dir = delta > 0
            ? 'climbing ' + delta + ' points'
            : delta < 0 ? 'down ' + Math.abs(delta) + ' points' : 'flat';
        return 'Week over week you are ' +
            dir +
            '. ' +
            sessions +
            ' sessions logged - ' +
            (sessions >= 5
                ? 'cadence is healthy.'
                : 'a touch more volume would sharpen the signal.');
    }

    private static String buildPullquote(List<Player_Topic_Stat__c> domains) {
        for (Player_Topic_Stat__c s : domains) {
            Integer a = s.Accuracy_Pct__c == null
                ? 0
                : s.Accuracy_Pct__c.intValue();
            if (a < DEFAULT_PASS_THRESHOLD) {
                return s.Topic_Value__c +
                    ' is where this exam will be won or lost for you.';
            }
        }
        return 'Consistency beats cramming - keep the streak alive.';
    }

    private static String buildVerdict(
        Integer readiness,
        Date examDate,
        List<Player_Topic_Stat__c> domains
    ) {
        Integer daysLeft = Math.max(0, Date.today().daysBetween(examDate));
        if (readiness >= 80) {
            return 'You are inside the confidence band. With ' +
                daysLeft +
                ' days remaining, the smart play is taper-and-maintain, not pile-on. Sleep wins exams.';
        }
        if (readiness >= 65) {
            return 'You are within striking distance. ' +
                daysLeft +
                ' days is enough to close the gap if you spend them on weak domains rather than re-reading what you already know.';
        }
        return 'Honest read: you are not there yet. ' +
            daysLeft +
            ' days is enough only if you change the mix - more focused drills on the red domains, fewer comfort questions.';
    }

    private static Integer computeReadiness(
        Integer overallAcc,
        List<Player_Topic_Stat__c> domains,
        Player__c player
    ) {
        Integer base = overallAcc;
        Integer weakPenalty = 0;
        for (Player_Topic_Stat__c s : domains) {
            Integer a = s.Accuracy_Pct__c == null
                ? 0
                : s.Accuracy_Pct__c.intValue();
            if (a < DEFAULT_PASS_THRESHOLD)
                weakPenalty += (DEFAULT_PASS_THRESHOLD - a) / 5;
        }
        Integer streakBoost = (player == null ||
            player.Current_Streak_Days__c == null)
            ? 0
            : Math.min(10, player.Current_Streak_Days__c.intValue());
        Integer score = base + streakBoost - weakPenalty;
        return Math.max(0, Math.min(100, score));
    }

    private static Decimal medianOf(List<Decimal> vals) {
        if (vals == null || vals.isEmpty())
            return null;
        vals.sort();
        Integer n = vals.size();
        return Math.mod(n, 2) == 1
            ? vals[n / 2]
            : ((vals[n / 2 - 1] + vals[n / 2]) / 2);
    }

    private static Decimal averageX(List<TimingPoint> pts) {
        if (pts == null || pts.isEmpty())
            return 0;
        Decimal sum = 0;
        for (TimingPoint p : pts)
            sum += p.x;
        return sum / pts.size();
    }

    private static String relativeTime(DateTime dt) {
        if (dt == null)
            return 'recently';
        Long diff = (DateTime.now().getTime() - dt.getTime()) / 1000;
        if (diff < 3600)
            return Math.max(1, ((Decimal) diff / 60).intValue()) + ' min ago';
        if (diff < 86400)
            return ((Decimal) diff / 3600).intValue() + ' hours ago';
        return ((Decimal) diff / 86400).intValue() + ' days ago';
    }

    private static String formatShortDate(Date d) {
        return DateTime.newInstance(d.year(), d.month(), d.day())
            .format('MMM d');
    }

    private static String truncate(String s, Integer n) {
        if (s == null)
            return '';
        return s.length() <= n ? s : s.substring(0, n - 1) + '\u2026';
    }

    @TestVisible
    private static String escape(String s) {
        if (s == null)
            return '';
        return s.replace('&', '&amp;')
            .replace('<', '&lt;')
            .replace('>', '&gt;')
            .replace('"', '&quot;')
            .replace('\'', '&#39;');
    }

    private static String chartJsUrl() {
        // Site-prefixed static resource path. Works under guest site context.
        String prefix = (Site.getPathPrefix() == null
            ? ''
            : Site.getPathPrefix());
        return prefix + '/resource/chartJs/chart.umd.js';
    }

    @TestVisible
    private static String loadTemplate() {
        return loadTemplate(null);
    }

    /**
     * Resolution order:
     *  1) Active Study_Guide_Theme__c whose Theme_Key__c matches `themeKey`.
     *  2) Active Study_Guide_Theme__c flagged Is_Default__c (if `themeKey` blank or no match).
     *  3) Static resource whose Name matches the resolved key (legacy path).
     *  4) Original `readinessReportTemplate` static resource (legacy compatibility).
     */
    @TestVisible
    private static String loadTemplate(String themeKey) {
        String key = String.isBlank(themeKey) ? null : themeKey.toLowerCase();
        if (String.isNotBlank(key)) {
            List<Study_Guide_Theme__c> byKey = [
                SELECT Body__c
                FROM Study_Guide_Theme__c
                WHERE Active__c = TRUE AND Theme_Key__c = :key
                WITH SYSTEM_MODE
                LIMIT 1
            ];
            if (!byKey.isEmpty() && String.isNotBlank(byKey[0].Body__c))
                return byKey[0].Body__c;
        }
        List<Study_Guide_Theme__c> defaults = [
            SELECT Body__c, Theme_Key__c
            FROM Study_Guide_Theme__c
            WHERE Active__c = TRUE AND Is_Default__c = TRUE
            WITH SYSTEM_MODE
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        if (!defaults.isEmpty() && String.isNotBlank(defaults[0].Body__c))
            return defaults[0].Body__c;

        // Static-resource fallback. Try keyed name first, then the legacy fixed name.
        if (String.isNotBlank(key)) {
            List<StaticResource> srs = [
                SELECT Body
                FROM StaticResource
                WHERE Name = :key
                LIMIT 1
            ];
            if (!srs.isEmpty())
                return srs[0].Body.toString();
        }
        List<StaticResource> legacy = [
            SELECT Body
            FROM StaticResource
            WHERE Name = 'readinessReportTemplate'
            LIMIT 1
        ];
        if (legacy.isEmpty())
            return '<html><body><h1>Template missing</h1></body></html>';
        return legacy[0].Body.toString();
    }

    @TestVisible
    private static String applyMerge(
        String template,
        Map<String, String> mergeFields
    ) {
        String out = template;
        for (String key : mergeFields.keySet()) {
            String val = mergeFields.get(key);
            out = out.replace('{{' + key + '}}', val == null ? '' : val);
        }
        return out;
    }
}