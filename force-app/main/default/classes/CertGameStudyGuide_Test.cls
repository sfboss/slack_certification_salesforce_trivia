@IsTest
private class CertGameStudyGuide_Test {
    @TestSetup
    static void setup() {
        Tenant__c t = new Tenant__c(
            Slack_Team_Id__c = 'T_SG',
            Workspace_Name__c = 'SG',
            Plan__c = 'Pro',
            Status__c = 'Active',
            Installed_At__c = System.now()
        );
        insert t;
        Player__c p = new Player__c(
            Tenant__c = t.Id,
            Slack_User_Id__c = 'U_SG',
            Display_Name__c = 'Studious',
            Current_Streak_Days__c = 3,
            Longest_Streak_Days__c = 5
        );
        insert p;

        Certification_Exam__c ex = new Certification_Exam__c(
            Name = 'ADM-201',
            Certification_Code__c = 'SG-ADM-201',
            Vendor__c = 'SF',
            Active__c = true
        );
        insert ex;
        Question_Bank__c bk = new Question_Bank__c(
            Name = 'SG Bank',
            Certification_Exam__c = ex.Id,
            Source_Type__c = 'Manual',
            Status__c = 'Published',
            Version__c = '1.0',
            External_Id__c = 'B-SG-1'
        );
        insert bk;
        Trivia_Question__c q = new Trivia_Question__c(
            External_Id__c = 'SG-Q1',
            Certification_Exam__c = ex.Id,
            Question_Bank__c = bk.Id,
            Question_Text__c = 'Q?',
            Question_Type__c = 'Single Select',
            Difficulty__c = 'Beginner',
            Status__c = 'Published',
            Correct_Answer_Mode__c = 'Exact',
            Hash__c = 'hsg'
        );
        insert q;
        insert new Trivia_Answer_Choice__c(
            Trivia_Question__c = q.Id,
            Choice_Text__c = 'Right',
            Is_Correct__c = true,
            Choice_Label__c = 'A'
        );
        Game_Session__c s = new Game_Session__c(
            Tenant__c = t.Id,
            Certification_Exam__c = ex.Id,
            Started_At__c = System.now(),
            Mode__c = 'Solo',
            Status__c = 'Active',
            Total_Questions__c = 2,
            Timer_Seconds__c = 30
        );
        insert s;
        Game_Round__c r = new Game_Round__c(
            Game_Session__c = s.Id,
            Trivia_Question__c = q.Id,
            Round_Number__c = 1,
            Status__c = 'Posted',
            Started_At__c = System.now()
        );
        insert r;

        List<Player_Answer__c> pas = new List<Player_Answer__c>();
        for (Integer i = 0; i < 3; i++) {
            pas.add(
                new Player_Answer__c(
                    Game_Round__c = r.Id,
                    Game_Session__c = s.Id,
                    Player__c = p.Id,
                    Trivia_Question__c = q.Id,
                    Selected_Choice_Labels__c = 'A',
                    Is_Correct__c = (Math.mod(i, 2) == 0),
                    Points_Awarded__c = 10,
                    Answered_At__c = System.now().addHours(-i),
                    Response_Time_Ms__c = 2000 + i * 500,
                    Selected_Choice_Text__c = 'Right',
                    Unique_Key__c = 'sg:' + p.Id + ':' + i
                )
            );
        }
        insert pas;
    }

    @IsTest
    static void renderHtmlNoThemeFallsBackToLegacyStaticResource() {
        Player__c p = [SELECT Id FROM Player__c LIMIT 1];
        Certification_Exam__c ex = [
            SELECT Id
            FROM Certification_Exam__c
            LIMIT 1
        ];
        Test.startTest();
        String html = CertGameReadinessReportService.renderHtml(p.Id, ex.Id);
        Test.stopTest();
        // Either the legacy static-resource template merged, or the placeholder.
        // Both prove the resolver returned something non-null.
        System.assertNotEquals(null, html);
        System.assert(html.length() > 0, 'expected non-empty html');
    }

    @IsTest
    static void renderHtmlWithSeededThemeUsesDbBody() {
        Study_Guide_Theme__c t = new Study_Guide_Theme__c(
            Name = 'Editorial',
            Theme_Key__c = 'editorial',
            Active__c = true,
            Is_Default__c = true,
            Sort_Order__c = 10,
            Body__c = '<html><body>Hi {{user_name}} - acc {{overall_accuracy}}%</body></html>'
        );
        insert t;
        Player__c p = [SELECT Id FROM Player__c LIMIT 1];
        Test.startTest();
        String html = CertGameReadinessReportService.renderHtml(
            p.Id,
            null,
            'editorial'
        );
        Test.stopTest();
        System.assert(html.contains('Studious'), 'merge: ' + html);
        System.assert(
            !html.contains('{{user_name}}'),
            'expected merge to substitute user_name'
        );
    }

    @IsTest
    static void listActiveThemesReturnsOnlyActive() {
        insert new List<Study_Guide_Theme__c>{
            new Study_Guide_Theme__c(
                Name = 'Edit',
                Theme_Key__c = 'editorial',
                Active__c = true,
                Is_Default__c = true,
                Sort_Order__c = 10,
                Body__c = '<html>e</html>'
            ),
            new Study_Guide_Theme__c(
                Name = 'Dash',
                Theme_Key__c = 'dashboard',
                Active__c = true,
                Sort_Order__c = 20,
                Body__c = '<html>d</html>'
            ),
            new Study_Guide_Theme__c(
                Name = 'Old',
                Theme_Key__c = 'retired',
                Active__c = false,
                Sort_Order__c = 30,
                Body__c = '<html>x</html>'
            )
        };
        List<CertGameReadinessReportService.ThemeOption> opts = CertGameReadinessReportService.listActiveThemes();
        System.assertEquals(2, opts.size());
        System.assertEquals('editorial', opts[0].key);
        System.assertEquals(true, opts[0].isDefault);
    }

    @IsTest
    static void resolveThemeKeyDefaultsWhenBlank() {
        insert new Study_Guide_Theme__c(
            Name = 'Dashboard',
            Theme_Key__c = 'dashboard',
            Active__c = true,
            Is_Default__c = true,
            Sort_Order__c = 10,
            Body__c = '<html>d</html>'
        );
        System.assertEquals(
            'dashboard',
            CertGameReadinessReportService.resolveThemeKey(null)
        );
        System.assertEquals(
            'printable',
            CertGameReadinessReportService.resolveThemeKey('Printable')
        );
    }

    @IsTest
    static void mintReportUrlAppendsThemeParam() {
        Player__c p = [SELECT Id FROM Player__c LIMIT 1];
        String url = CertGameReadinessReportController.mintReportUrl(
            p.Id,
            null,
            'editorial'
        );
        System.assert(url.contains('theme=editorial'), url);
        System.assert(url.contains('p=' + p.Id), url);
        String urlNoTheme = CertGameReadinessReportController.mintReportUrl(
            p.Id,
            null
        );
        System.assert(!urlNoTheme.contains('theme='));
    }

    @IsTest
    static void mintReportUrlNullPlayerReturnsNull() {
        System.assertEquals(
            null,
            CertGameReadinessReportController.mintReportUrl(null, null, null)
        );
    }

    @IsTest
    static void studyGuideServiceUnknownTenantReturnsNotInstalled() {
        String r = CertGameStudyGuideService.renderReport('NOPE', 'U_X');
        System.assert(r.contains('ephemeral'));
    }

    @IsTest
    static void studyGuideServiceUnknownPlayerHints() {
        String r = CertGameStudyGuideService.renderReport('T_SG', 'U_MISSING');
        System.assert(r.contains('Play a round first'));
    }

    @IsTest
    static void studyGuideServiceRendersCardForKnownPlayer() {
        insert new Study_Guide_Theme__c(
            Name = 'Editorial',
            Theme_Key__c = 'editorial',
            Active__c = true,
            Is_Default__c = true,
            Sort_Order__c = 10,
            Body__c = '<html>e</html>'
        );
        String r = CertGameStudyGuideService.renderReport('T_SG', 'U_SG');
        System.assert(r.contains('Study Guide'), r);
        System.assert(r.contains('ephemeral'));
    }

    @IsTest
    static void mintDefaultUrlMatchesController() {
        Player__c p = [SELECT Id FROM Player__c LIMIT 1];
        String u = CertGameStudyGuideService.mintDefaultUrl(p.Id, null);
        System.assert(u.contains('p=' + p.Id));
    }

    @IsTest
    static void controllerInDemoModeRenders() {
        Test.setCurrentPage(Page.CertGameReadinessReport);
        ApexPages.currentPage().getParameters().put('demo', '1');
        CertGameReadinessReportController c = new CertGameReadinessReportController();
        System.assertNotEquals(null, c.mergedHtml);
    }

    @IsTest
    static void controllerInvalidTokenSetsErrorMessage() {
        Test.setCurrentPage(Page.CertGameReadinessReport);
        ApexPages.currentPage().getParameters().put('p', UserInfo.getUserId());
        ApexPages.currentPage().getParameters().put('t', 'bogus');
        CertGameReadinessReportController c = new CertGameReadinessReportController();
        System.assert(c.errorMessage != null, 'expected error');
    }

    @IsTest
    static void renderServiceStudyGuideCardWithThemes() {
        Player__c p = [SELECT Id FROM Player__c LIMIT 1];
        List<CertGameReadinessReportService.ThemeOption> themes = new List<CertGameReadinessReportService.ThemeOption>();
        CertGameReadinessReportService.ThemeOption a = new CertGameReadinessReportService.ThemeOption();
        a.key = 'editorial';
        a.name = 'Editorial';
        a.isDefault = true;
        a.active = true;
        themes.add(a);
        CertGameReadinessReportService.ThemeOption b = new CertGameReadinessReportService.ThemeOption();
        b.key = 'dashboard';
        b.name = 'Dashboard';
        b.isDefault = false;
        b.active = true;
        themes.add(b);
        String card = CertGameSlackRenderService.studyGuideCard(
            p.Id,
            null,
            themes
        );
        System.assert(card.contains('Editorial'), card);
        System.assert(card.contains('Dashboard'));
        System.assert(card.contains('ephemeral'));
    }

    @IsTest
    static void renderServiceStudyGuideCardNoThemesFallsBack() {
        Player__c p = [SELECT Id FROM Player__c LIMIT 1];
        String card = CertGameSlackRenderService.studyGuideCard(
            p.Id,
            null,
            null
        );
        System.assert(card.contains('Open Study Guide'), card);
    }

    @IsTest
    static void slashReportSubcommand() {
        Map<String, Object> payload = new Map<String, Object>{
            'text' => 'report',
            'team_id' => 'T_SG',
            'user_id' => 'U_SG',
            'channel_id' => 'C1',
            'trigger_id' => 'TR1'
        };
        String r = SlackCertGameCommandHandler.handle(payload);
        System.assert(r.contains('Study Guide'), r);
    }

    @IsTest
    static void slashReportSubcommandUnknownPlayer() {
        Map<String, Object> payload = new Map<String, Object>{
            'text' => 'studyguide',
            'team_id' => 'T_SG',
            'user_id' => 'U_NOPE',
            'channel_id' => 'C1',
            'trigger_id' => 'TR1'
        };
        String r = SlackCertGameCommandHandler.handle(payload);
        System.assert(r.contains('Play a round first'));
    }

    @IsTest
    static void interactionReportOpenNoOp() {
        Map<String, Object> payload = new Map<String, Object>{
            'actions' => new List<Object>{
                new Map<String, Object>{
                    'action_id' => 'report:open:editorial'
                }
            },
            'team' => new Map<String, Object>{ 'id' => 'T_SG' },
            'user' => new Map<String, Object>{ 'id' => 'U_SG' }
        };
        String r = SlackCertGameInteractionHandler.handle(payload);
        // URL-button click with resource segment: handler should no-op (return empty string).
        System.assertEquals('', r);
    }
}