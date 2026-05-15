/**
 * Study Plan management. Creates/updates Study_Plan__c records.
 * Slack modal flow: /certgame plan → modal → submit → upsert plan → schedule nudges.
 */
public with sharing class CertGameStudyPlanService {

    public static String openPlanModal(String slackTeamId, String slackUserId, String triggerId) {
        Map<String, Object> view = new Map<String, Object>{
            'type' => 'modal',
            'callback_id' => 'plan:create',
            'title' => new Map<String, Object>{ 'type' => 'plain_text', 'text' => 'Study Plan' },
            'submit' => new Map<String, Object>{ 'type' => 'plain_text', 'text' => 'Save' },
            'close' => new Map<String, Object>{ 'type' => 'plain_text', 'text' => 'Cancel' },
            'blocks' => new List<Object>{
                new Map<String, Object>{
                    'type' => 'input',
                    'block_id' => 'exam_block',
                    'label' => new Map<String, Object>{ 'type' => 'plain_text', 'text' => 'Certification code' },
                    'element' => new Map<String, Object>{ 'type' => 'plain_text_input', 'action_id' => 'exam' }
                },
                new Map<String, Object>{
                    'type' => 'input',
                    'block_id' => 'target_block',
                    'label' => new Map<String, Object>{ 'type' => 'plain_text', 'text' => 'Target exam date (YYYY-MM-DD)' },
                    'element' => new Map<String, Object>{ 'type' => 'plain_text_input', 'action_id' => 'target' }
                },
                new Map<String, Object>{
                    'type' => 'input',
                    'block_id' => 'daily_block',
                    'label' => new Map<String, Object>{ 'type' => 'plain_text', 'text' => 'Daily question goal' },
                    'element' => new Map<String, Object>{ 'type' => 'plain_text_input', 'action_id' => 'daily' }
                }
            }
        };
        try { SlackApiClient.openView(triggerId, view); }
        catch (Exception e) { AppLogger.warn('Plan', 'openView', e.getMessage()); }
        return '';
    }

    public static String handlePlanSubmission(String slackTeamId, String slackUserId, Map<String, Object> view) {
        Map<String, Object> state = (Map<String, Object>)((Map<String, Object>) view.get('state')).get('values');
        String examCode = readVal(state, 'exam_block', 'exam');
        String targetStr = readVal(state, 'target_block', 'target');
        String dailyStr = readVal(state, 'daily_block', 'daily');

        Tenant__c t = CertGameTenantService.getOrCreateTenant(slackTeamId);
        Player__c p = CertGameTenantService.getOrCreatePlayer(t.Id, slackUserId);

        List<Certification_Exam__c> exams = [SELECT Id FROM Certification_Exam__c
                                              WHERE Certification_Code__c = :examCode WITH USER_MODE LIMIT 1];
        if (exams.isEmpty()) return CertGameSlackRenderService.text(CertGameStrings.NO_EXAM, true);

        Study_Plan__c sp = new Study_Plan__c(
            Player__c = p.Id,
            Certification_Exam__c = exams[0].Id,
            Target_Exam_Date__c = parseDate(targetStr),
            Daily_Question_Goal__c = parseInt(dailyStr, 5),
            Status__c = 'Active'
        );
        insert as user sp;
        AuditLogger.log('plan_create', 'Study_Plan__c', sp.Id, null, JSON.serialize(sp), slackUserId);
        return '';
    }

    private static String readVal(Map<String, Object> state, String block, String action) {
        if (!state.containsKey(block)) return null;
        Map<String, Object> b = (Map<String, Object>) state.get(block);
        if (!b.containsKey(action)) return null;
        Map<String, Object> a = (Map<String, Object>) b.get(action);
        return (String) a.get('value');
    }
    private static Date parseDate(String s) {
        try { return Date.valueOf(s); } catch (Exception e) { return null; }
    }
    private static Integer parseInt(String s, Integer fallback) {
        try { return Integer.valueOf(s); } catch (Exception e) { return fallback; }
    }
}
