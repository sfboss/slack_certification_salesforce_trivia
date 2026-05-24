/**
 * /certgame doctor — preflight diagnostics. Runs every setup invariant the rest
 * of the app assumes, pulls the most recent server-side log rows, and emits a
 * Block Kit report with explicit next steps. Read-only; no callouts; no DML.
 */
public with sharing class CertGameDoctorService {
    public class Check {
        public String status; // OK | WARN | FAIL
        public String title;
        public String detail;
        public String nextStep;
        public Check(String s, String t, String d, String n) {
            status = s;
            title = t;
            detail = d;
            nextStep = n;
        }
    }

    public static String run(String slackTeamId, String slackUserId) {
        Reader r = new Reader();
        List<Check> checks = new List<Check>();
        String adminUrl = adminHomeUrl();

        Tenant__c tenant = r.tenantByTeam(slackTeamId);
        Boolean isAdmin = isWorkspaceAdmin(tenant, slackUserId);
        if (tenant == null) {
            checks.add(
                new Check(
                    'FAIL',
                    'Tenant record',
                    'No Tenant__c found for Slack team ' + slackTeamId + '.',
                    'Run any `/certgame help` once as a workspace admin so the Tenant is auto-created.'
                )
            );
        } else if (
            tenant.Status__c != 'Active' &&
            tenant.Status__c != 'Trial'
        ) {
            checks.add(
                new Check(
                    'FAIL',
                    'Tenant status',
                    'Tenant ' +
                        tenant.Id +
                        ' status is ' +
                        tenant.Status__c +
                        '.',
                    isAdmin
                        ? 'Open the Cert Game admin app and set this Tenant to Active or Trial: ' +
                          adminUrl
                        : 'Ask your Cert Game admin to activate this workspace in Salesforce.'
                )
            );
        } else {
            String roleTag = isAdmin ? ' (you are an admin)' : '';
            checks.add(
                new Check(
                    'OK',
                    'Tenant',
                    tenant.Plan__c + ' / ' + tenant.Status__c + roleTag,
                    null
                )
            );
        }

        App_Setting__mdt s = r.appSetting();
        if (s == null) {
            checks.add(
                new Check(
                    'FAIL',
                    'App_Setting__mdt.Default',
                    'No Default App_Setting__mdt row.',
                    'Deploy customMetadata/App_Setting.Default.md-meta.xml.'
                )
            );
        } else {
            if (String.isBlank(s.Slack_Verification_Token__c)) {
                checks.add(
                    new Check(
                        'FAIL',
                        'Slack verification token',
                        'App_Setting__mdt.Default.Slack_Verification_Token__c is blank.',
                        'Setup → Custom Metadata Types → App Setting → Default → paste Verification Token from your Slack app (Basic Information).'
                    )
                );
            } else {
                checks.add(
                    new Check(
                        'OK',
                        'Slack verification token',
                        'configured',
                        null
                    )
                );
            }
            if (String.isBlank(s.Slack_Signing_Secret__c)) {
                checks.add(
                    new Check(
                        'WARN',
                        'Slack signing secret',
                        'App_Setting__mdt.Default.Slack_Signing_Secret__c is blank — HMAC verification is skipped (token-fallback in use).',
                        'For production-grade auth: Setup → Custom Metadata → App Setting → Default → paste Signing Secret from Slack app Basic Information.'
                    )
                );
            } else {
                checks.add(
                    new Check('OK', 'Slack signing secret', 'configured', null)
                );
            }
            if (String.isBlank(s.Slack_Bot_Token__c)) {
                checks.add(
                    new Check(
                        'FAIL',
                        'Slack bot token',
                        'App_Setting__mdt.Default.Slack_Bot_Token__c is blank — outbound Slack callouts will fail for the Site Guest User (External Credential is not guest-readable).',
                        'Setup → Custom Metadata → App Setting → Default → paste the Slack app Bot User OAuth Token (starts with xoxb-) into Slack_Bot_Token__c.'
                    )
                );
            } else {
                checks.add(
                    new Check(
                        'OK',
                        'Slack bot token',
                        'configured (direct-URL callout path)',
                        null
                    )
                );
            }
        }

        Integer activeExams = r.activeExamCount();
        if (activeExams == 0) {
            checks.add(
                new Check(
                    'FAIL',
                    'Active certification exam',
                    'No Certification_Exam__c rows with Active__c=true.',
                    isAdmin
                        ? 'Open the Cert Game admin home and import a question pack (uploads activate the exam automatically): ' +
                          adminUrl
                        : 'Ask your Cert Game admin to import a question pack — it takes about a minute. Until then, no exams are available to play.'
                )
            );
        } else {
            checks.add(
                new Check('OK', 'Active exams', activeExams + ' active', null)
            );
        }

        Map<String, Integer> qByStatus = r.questionsByStatus();
        Integer published = qByStatus.containsKey('Published')
            ? qByStatus.get('Published')
            : 0;
        Integer reviewed = qByStatus.containsKey('Reviewed')
            ? qByStatus.get('Reviewed')
            : 0;
        Integer draft = qByStatus.containsKey('Draft')
            ? qByStatus.get('Draft')
            : 0;
        if (published == 0) {
            String hintMsg;
            if (isAdmin) {
                if (reviewed > 0) {
                    hintMsg =
                        reviewed +
                        ' question(s) are sitting in Reviewed status. Open the Review Drafts tab and click Publish: ' +
                        adminUrl;
                } else if (draft > 0) {
                    hintMsg =
                        draft +
                        ' question(s) are in Draft. Review and publish them here: ' +
                        adminUrl;
                } else {
                    hintMsg =
                        'Upload your first question pack (the sample ADM-201 pack ships with the repo) here: ' +
                        adminUrl;
                }
            } else {
                hintMsg = reviewed > 0 ||
                    draft > 0
                    ? 'Your admin has ' +
                      (reviewed + draft) +
                      ' question(s) waiting to be published. Give them a nudge — once published, `/certgame play` will work for you.'
                    : 'Your workspace has no questions yet. Ask your Cert Game admin to import a pack — in the meantime there is nothing to play.';
            }
            checks.add(
                new Check(
                    'FAIL',
                    'Published questions',
                    'Zero Trivia_Question__c rows with Status__c=Published.',
                    hintMsg
                )
            );
        } else {
            checks.add(
                new Check(
                    'OK',
                    'Published questions',
                    published +
                        ' published (' +
                        reviewed +
                        ' reviewed, ' +
                        draft +
                        ' draft)',
                    null
                )
            );
        }

        if (tenant != null) {
            Boolean canStart = EntitlementGuard.canStartGame(tenant.Id);
            if (!canStart) {
                checks.add(
                    new Check(
                        'FAIL',
                        'Quota / entitlement',
                        'EntitlementGuard.canStartGame(tenant) returned false.',
                        'Check Tenant__c.Plan__c and recent Usage_Metric__c rows. Free plan limit is the Default App_Setting Max_Games_Per_Day_Free__c value.'
                    )
                );
            } else {
                checks.add(
                    new Check('OK', 'Quota', 'within plan limits', null)
                );
            }
        }

        // Recent server errors — surface the source of truth.
        List<App_Log__c> errs = r.recentErrors();
        String errSummary = errs.isEmpty()
            ? 'No ERROR rows in the last hour.'
            : errs.size() + ' ERROR row(s) in the last hour.';
        checks.add(
            new Check(
                errs.isEmpty() ? 'OK' : 'WARN',
                'Recent server errors',
                errSummary,
                errs.isEmpty()
                    ? null
                    : 'Open App_Log__c list view in Salesforce and inspect Stack__c on the rows below.'
            )
        );

        List<Slack_Event_Log__c> events = r.recentEvents();

        Integer score = 0;
        Integer max = 0;
        Boolean anyFail = false;
        for (Check c : checks) {
            max++;
            if (c.status == 'OK')
                score++;
            else if (c.status == 'FAIL')
                anyFail = true;
        }

        // When everything material is healthy, give the user the one-liner that
        // gets them into a game. This is the whole point of doctor.
        if (!anyFail) {
            checks.add(
                new Check(
                    'OK',
                    'Ready to play',
                    'All prerequisites in place.',
                    'Run `/certgame play` to start a quick 5-question round, or `/certgame play CRT-403` to target a specific exam.'
                )
            );
            max++;
            score++;
        }

        return CertGameSlackRenderService.doctorReport(
            slackTeamId,
            score,
            max,
            checks,
            errs,
            events
        );
    }

    private static Boolean isWorkspaceAdmin(
        Tenant__c tenant,
        String slackUserId
    ) {
        if (
            tenant == null ||
            String.isBlank(slackUserId) ||
            String.isBlank(tenant.Admin_Slack_User_Ids__c)
        )
            return false;
        for (String id : tenant.Admin_Slack_User_Ids__c.split(';')) {
            if (id != null && id.trim() == slackUserId)
                return true;
        }
        return false;
    }

    private static String adminHomeUrl() {
        try {
            return URL.getOrgDomainUrl().toExternalForm() +
                '/lightning/n/Cert_Game_Admin_Home';
        } catch (Exception e) {
            return '/lightning/n/Cert_Game_Admin_Home';
        }
    }

    private without sharing class Reader {
        public Tenant__c tenantByTeam(String teamId) {
            List<Tenant__c> ts = [
                SELECT Id, Plan__c, Status__c, Admin_Slack_User_Ids__c
                FROM Tenant__c
                WHERE Slack_Team_Id__c = :teamId
                LIMIT 1
            ];
            return ts.isEmpty() ? null : ts[0];
        }
        public App_Setting__mdt appSetting() {
            List<App_Setting__mdt> rows = [
                SELECT
                    Slack_Verification_Token__c,
                    Slack_Signing_Secret__c,
                    Slack_Bot_Token__c,
                    Max_Games_Per_Day_Free__c
                FROM App_Setting__mdt
                WHERE DeveloperName = 'Default'
                LIMIT 1
            ];
            return rows.isEmpty() ? null : rows[0];
        }
        public Integer activeExamCount() {
            return [
                SELECT COUNT()
                FROM Certification_Exam__c
                WHERE Active__c = TRUE
            ];
        }
        public Map<String, Integer> questionsByStatus() {
            Map<String, Integer> out = new Map<String, Integer>();
            for (AggregateResult ar : [
                SELECT Status__c s, COUNT(Id) c
                FROM Trivia_Question__c
                GROUP BY Status__c
            ]) {
                out.put(
                    (String) ar.get('s'),
                    ((Decimal) ar.get('c')).intValue()
                );
            }
            return out;
        }
        public List<App_Log__c> recentErrors() {
            DateTime since = System.now().addHours(-1);
            return [
                SELECT
                    Level__c,
                    Class_Name__c,
                    Method_Name__c,
                    Message__c,
                    Correlation_Id__c,
                    Occurred_At__c
                FROM App_Log__c
                WHERE Level__c = 'ERROR' AND Occurred_At__c >= :since
                ORDER BY Occurred_At__c DESC
                LIMIT 5
            ];
        }
        public List<Slack_Event_Log__c> recentEvents() {
            DateTime since = System.now().addMinutes(-15);
            return [
                SELECT
                    Event_Type__c,
                    Received_At__c,
                    Processed__c,
                    Slack_Team_Id__c
                FROM Slack_Event_Log__c
                WHERE Received_At__c >= :since
                ORDER BY Received_At__c DESC
                LIMIT 5
            ];
        }
    }
}