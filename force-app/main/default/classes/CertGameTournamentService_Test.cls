@IsTest
private class CertGameTournamentService_Test {
    @TestSetup
    static void setup() {
        Tenant__c team = new Tenant__c(
            Slack_Team_Id__c = 'T_TOUR',
            Workspace_Name__c = 'Tour WS',
            Plan__c = 'Pro',
            Status__c = 'Active',
            Installed_At__c = System.now()
        );
        Tenant__c free = new Tenant__c(
            Slack_Team_Id__c = 'T_TOUR_FREE',
            Workspace_Name__c = 'Free Tour',
            Plan__c = 'Free',
            Status__c = 'Active',
            Installed_At__c = System.now()
        );
        insert new List<Tenant__c>{ team, free };
        Certification_Exam__c ex = new Certification_Exam__c(
            Name = 'Tour Exam',
            Certification_Code__c = 'TOUR-1',
            Vendor__c = 'SF',
            Active__c = true
        );
        insert ex;
    }

    @IsTest
    static void createAndBuildBracket() {
        Certification_Exam__c ex = [
            SELECT Id
            FROM Certification_Exam__c
            WHERE Certification_Code__c = 'TOUR-1'
        ];
        Id tid = CertGameTournamentService.createTournament(
            'Spring Cup',
            'Elimination',
            ex.Id,
            System.now(),
            System.now().addDays(7)
        );
        System.assertNotEquals(null, tid);

        List<Id> players = new List<Id>();
        Tenant__c t = [
            SELECT Id
            FROM Tenant__c
            WHERE Slack_Team_Id__c = 'T_TOUR'
        ];
        for (Integer i = 0; i < 4; i++) {
            Player__c p = new Player__c(
                Tenant__c = t.Id,
                Slack_User_Id__c = 'U' + i,
                Display_Name__c = 'P' + i
            );
            insert p;
            players.add(p.Id);
        }
        String json = CertGameTournamentService.buildBracket(tid, players);
        System.assert(json.contains('round'));
    }

    @IsTest
    static void createTournamentValidatesArgs() {
        try {
            CertGameTournamentService.createTournament(
                '',
                'Elimination',
                null,
                null,
                null
            );
            System.assert(false, 'expected');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }

    @IsTest
    static void joinUnknownReturnsNotFound() {
        String res = CertGameTournamentService.joinFromSlack(
            'T_TOUR',
            'U_J',
            null
        );
        System.assert(res != null);
        String res2 = CertGameTournamentService.joinFromSlack(
            'T_TOUR',
            'U_J',
            '0Q0000000000000'
        );
        System.assert(res2 != null);
    }

    @IsTest
    static void joinExistingTournament() {
        Tenant__c t = [
            SELECT Id
            FROM Tenant__c
            WHERE Slack_Team_Id__c = 'T_TOUR'
        ];
        Certification_Exam__c ex = [
            SELECT Id
            FROM Certification_Exam__c
            WHERE Certification_Code__c = 'TOUR-1'
        ];
        Tournament__c tn = new Tournament__c(
            Tenant__c = t.Id,
            Certification_Exam__c = ex.Id,
            Name = 'X',
            Bracket_Type__c = 'Elimination',
            Status__c = 'Scheduled'
        );
        insert tn;
        String res = CertGameTournamentService.joinFromSlack(
            'T_TOUR',
            'U_J',
            tn.Id
        );
        System.assert(res != null);
    }

    @IsTest
    static void createSubmissionFreePlanBlocked() {
        Map<String, Object> view = new Map<String, Object>{
            'state' => new Map<String, Object>{
                'values' => new Map<String, Object>{
                    'name_block' => new Map<String, Object>{
                        'name' => new Map<String, Object>{ 'value' => 'Cup' }
                    },
                    'format_block' => new Map<String, Object>{
                        'format' => new Map<String, Object>{
                            'selected_option' => new Map<String, Object>{
                                'value' => 'Elimination'
                            }
                        }
                    }
                }
            }
        };
        String res = CertGameTournamentService.handleCreateSubmission(
            'T_TOUR_FREE',
            'U_X',
            view
        );
        System.assert(
            res.contains('Pro plan') ||
                res.contains('premium') ||
                res.contains('Premium') ||
                res.contains('upgrade')
        );
    }

    @IsTest
    static void createSubmissionPaidSucceeds() {
        Certification_Exam__c ex = [
            SELECT Id
            FROM Certification_Exam__c
            WHERE Certification_Code__c = 'TOUR-1'
        ];
        Map<String, Object> view = new Map<String, Object>{
            'state' => new Map<String, Object>{
                'values' => new Map<String, Object>{
                    'exam_block' => new Map<String, Object>{
                        'exam' => new Map<String, Object>{
                            'selected_option' => new Map<String, Object>{
                                'value' => (String) ex.Id
                            }
                        }
                    },
                    'name_block' => new Map<String, Object>{
                        'name' => new Map<String, Object>{ 'value' => 'Cup' }
                    },
                    'format_block' => new Map<String, Object>{
                        'format' => new Map<String, Object>{
                            'selected_option' => new Map<String, Object>{
                                'value' => 'Elimination'
                            }
                        }
                    }
                }
            }
        };
        CertGameTournamentService.handleCreateSubmission('T_TOUR', 'U_X', view);
        Tenant__c t = [
            SELECT Id
            FROM Tenant__c
            WHERE Slack_Team_Id__c = 'T_TOUR'
        ];
        System.assertEquals(
            1,
            [
                SELECT COUNT()
                FROM Tournament__c
                WHERE Tenant__c = :t.Id AND Name = 'Cup'
            ]
        );
    }

    // ----------------- New async point-race flow -----------------

    private static Player__c newPlayer(
        Tenant__c t,
        String sub,
        String email,
        String name
    ) {
        Player__c p = new Player__c(
            Tenant__c = t.Id,
            Slack_User_Id__c = 'SU_' + sub,
            Display_Name__c = name,
            Google_Sub__c = sub,
            Google_Email__c = email,
            Google_Name__c = name
        );
        insert p;
        return p;
    }

    private static Id makeTournament(Certification_Exam__c ex) {
        CertGameTournamentService.TournamentInput inp = new CertGameTournamentService.TournamentInput();
        inp.name = 'Cup A';
        inp.description = 'desc';
        inp.bracketType = 'Elimination';
        inp.examId = ex.Id;
        inp.startAt = System.now();
        inp.endAt = System.now().addDays(3);
        inp.questionsPerMatch = 5;
        inp.maxParticipants = 50;
        inp.publicJoinEnabled = true;
        inp.prizeDescription = 'Glory';
        return CertGameTournamentService.createTournamentFull(inp);
    }

    @IsTest
    static void fullLifecycleAdminFlow() {
        Tenant__c t = [
            SELECT Id
            FROM Tenant__c
            WHERE Slack_Team_Id__c = 'T_TOUR'
        ];
        Certification_Exam__c ex = [
            SELECT Id
            FROM Certification_Exam__c
            WHERE Certification_Code__c = 'TOUR-1'
        ];

        Test.startTest();
        Id tid = makeTournament(ex);
        Tournament__c stored = [
            SELECT Public_Join_Token__c, Status__c
            FROM Tournament__c
            WHERE Id = :tid
        ];
        System.assert(String.isNotBlank(stored.Public_Join_Token__c));
        System.assertEquals('Scheduled', stored.Status__c);

        // Edit
        CertGameTournamentService.TournamentInput inp = new CertGameTournamentService.TournamentInput();
        inp.name = 'Cup A2';
        inp.bracketType = 'Elimination';
        inp.examId = ex.Id;
        inp.questionsPerMatch = 7;
        inp.publicJoinEnabled = false;
        CertGameTournamentService.updateTournament(tid, inp);

        // Direct enroll
        Player__c p1 = newPlayer(t, 'g1', 'a@x.com', 'Alice');
        Player__c p2 = newPlayer(t, 'g2', 'b@x.com', 'Bob');
        Id tp1 = CertGameTournamentService.enrollPlayer(tid, p1.Id);
        System.assertNotEquals(null, tp1);
        // Re-enroll same player → no dup
        CertGameTournamentService.enrollPlayer(tid, p1.Id);
        System.assertEquals(
            1,
            [
                SELECT COUNT()
                FROM Tournament_Participant__c
                WHERE Tournament__c = :tid AND Player__c = :p1.Id
            ]
        );

        // Bulk by email
        CertGameTournamentService.EnrollResult er = CertGameTournamentService.enrollPlayersByEmail(
            tid,
            new List<String>{ 'B@X.COM', 'nope@x.com', 'a@x.com' }
        );
        System.assertEquals(1, er.added);
        System.assertEquals(1, er.existing);
        System.assertEquals(1, er.notFound);

        // Search
        List<CertGameTournamentService.PlayerSearchRow> rows = CertGameTournamentService.searchPlayers(
            tid,
            'a@'
        );
        System.assert(!rows.isEmpty());

        // Detail + list
        CertGameTournamentService.TournamentDetail det = CertGameTournamentService.getTournamentDetail(
            tid
        );
        System.assertEquals(2, det.participants.size());
        List<CertGameTournamentService.TournamentSummary> lst = CertGameTournamentService.listTournaments(
            'Scheduled'
        );
        System.assert(!lst.isEmpty());

        // Start → Active and registered participants flipped
        CertGameTournamentService.startTournament(tid);
        System.assertEquals(
            'Active',
            [SELECT Status__c FROM Tournament__c WHERE Id = :tid].Status__c
        );

        // Remove one participant
        CertGameTournamentService.removeParticipant(tp1);
        System.assertEquals(
            1,
            [
                SELECT COUNT()
                FROM Tournament_Participant__c
                WHERE Tournament__c = :tid
            ]
        );

        // Complete (no points yet — winner may be null but should not throw)
        CertGameTournamentService.completeTournament(tid);
        System.assertEquals(
            'Complete',
            [SELECT Status__c FROM Tournament__c WHERE Id = :tid].Status__c
        );
        Test.stopTest();
    }

    @IsTest
    static void cancelAndStartGuards() {
        Certification_Exam__c ex = [
            SELECT Id
            FROM Certification_Exam__c
            WHERE Certification_Code__c = 'TOUR-1'
        ];
        Id tid = makeTournament(ex);
        CertGameTournamentService.cancelTournament(tid);
        try {
            CertGameTournamentService.startTournament(tid);
            System.assert(false, 'expected guard');
        } catch (Exception e) {
            System.assert(true);
        }
    }

    @IsTest
    static void recomputeStandingsRanksByPoints() {
        Tenant__c t = [
            SELECT Id
            FROM Tenant__c
            WHERE Slack_Team_Id__c = 'T_TOUR'
        ];
        Certification_Exam__c ex = [
            SELECT Id
            FROM Certification_Exam__c
            WHERE Certification_Code__c = 'TOUR-1'
        ];
        Id tid = makeTournament(ex);

        Player__c a = newPlayer(t, 'rg1', 'r1@x.com', 'R1');
        Player__c b = newPlayer(t, 'rg2', 'r2@x.com', 'R2');
        CertGameTournamentService.enrollPlayer(tid, a.Id);
        CertGameTournamentService.enrollPlayer(tid, b.Id);

        // Build sessions stamped with this tournament for both players, then synthesize answers.
        Game_Session__c sa = new Game_Session__c(
            Certification_Exam__c = ex.Id,
            Tournament__c = tid,
            Status__c = 'Complete',
            Mode__c = 'Tournament'
        );
        Game_Session__c sb = new Game_Session__c(
            Certification_Exam__c = ex.Id,
            Tournament__c = tid,
            Status__c = 'Complete',
            Mode__c = 'Tournament'
        );
        insert new List<Game_Session__c>{ sa, sb };

        // Need round + answers; minimal answer records carrying points.
        Trivia_Question__c q = new Trivia_Question__c(
            Certification_Exam__c = ex.Id,
            Question_Text__c = 'Q',
            Difficulty__c = 'Easy'
        );
        insert q;
        Game_Round__c ra = new Game_Round__c(
            Game_Session__c = sa.Id,
            Trivia_Question__c = q.Id,
            Round_Number__c = 1
        );
        Game_Round__c rb = new Game_Round__c(
            Game_Session__c = sb.Id,
            Trivia_Question__c = q.Id,
            Round_Number__c = 1
        );
        insert new List<Game_Round__c>{ ra, rb };

        Player_Answer__c pa = new Player_Answer__c(
            Player__c = a.Id,
            Game_Session__c = sa.Id,
            Game_Round__c = ra.Id,
            Trivia_Question__c = q.Id,
            Points_Awarded__c = 100,
            Is_Correct__c = true,
            Answered_At__c = System.now()
        );
        Player_Answer__c pb = new Player_Answer__c(
            Player__c = b.Id,
            Game_Session__c = sb.Id,
            Game_Round__c = rb.Id,
            Trivia_Question__c = q.Id,
            Points_Awarded__c = 50,
            Is_Correct__c = true,
            Answered_At__c = System.now()
        );
        insert new List<Player_Answer__c>{ pa, pb };

        Test.startTest();
        CertGameTournamentService.recomputeStandings(tid);
        Test.stopTest();

        Map<Id, Tournament_Participant__c> tps = new Map<Id, Tournament_Participant__c>(
            [
                SELECT Id, Player__c, Total_Points__c, Rank__c
                FROM Tournament_Participant__c
                WHERE Tournament__c = :tid
            ]
        );
        Tournament_Participant__c top, bot;
        for (Tournament_Participant__c x : tps.values()) {
            if (x.Player__c == a.Id)
                top = x;
            else
                bot = x;
        }
        System.assertEquals(100, top.Total_Points__c.intValue());
        System.assertEquals(1, top.Rank__c.intValue());
        System.assertEquals(2, bot.Rank__c.intValue());
    }

    @IsTest
    static void webTournamentJoinAndDetail() {
        Tenant__c t = [
            SELECT Id
            FROM Tenant__c
            WHERE Slack_Team_Id__c = 'T_TOUR'
        ];
        Certification_Exam__c ex = [
            SELECT Id
            FROM Certification_Exam__c
            WHERE Certification_Code__c = 'TOUR-1'
        ];
        Id tid = makeTournament(ex);
        String token = [
            SELECT Public_Join_Token__c
            FROM Tournament__c
            WHERE Id = :tid
        ]
        .Public_Join_Token__c;
        Player__c p = newPlayer(t, 'wg1', 'w@x.com', 'Web');

        Test.startTest();
        // listOpenTournaments
        List<WebTournamentService.TournamentPublicDTO> open = WebTournamentService.listOpenTournaments(
            p.Id
        );
        System.assert(!open.isEmpty());

        // getByToken before join
        WebTournamentService.TournamentPublicDTO d0 = WebTournamentService.getTournamentByToken(
            p.Id,
            token
        );
        System.assertEquals(false, d0.joined);

        // join
        WebTournamentService.JoinResult jr = WebTournamentService.join(
            p.Id,
            token
        );
        System.assertEquals(true, jr.joined);

        // getByToken after join
        WebTournamentService.TournamentPublicDTO d1 = WebTournamentService.getTournamentByToken(
            p.Id,
            token
        );
        System.assertEquals(true, d1.joined);

        // start (tournament must be Active)
        CertGameTournamentService.startTournament(tid);
        // No questions available, startTournamentSession will throw — exercise guard via catch.
        try {
            WebTournamentService.startTournamentSession(p.Id, token);
        } catch (Exception e) {
            /* expected: no questions / play layer */
        }
        Test.stopTest();
    }

    @IsTest
    static void webTournamentBadTokenAndDisabled() {
        Tenant__c t = [
            SELECT Id
            FROM Tenant__c
            WHERE Slack_Team_Id__c = 'T_TOUR'
        ];
        Player__c p = newPlayer(t, 'wg2', 'w2@x.com', 'Web2');
        try {
            WebTournamentService.getTournamentByToken(p.Id, 'BOGUS');
            System.assert(false);
        } catch (Exception e) {
            System.assert(true);
        }
        try {
            WebTournamentService.join(p.Id, 'BOGUS');
            System.assert(false);
        } catch (Exception e) {
            System.assert(true);
        }
        try {
            WebTournamentService.join(null, 'anything');
            System.assert(false);
        } catch (Exception e) {
            System.assert(true);
        }
    }
}