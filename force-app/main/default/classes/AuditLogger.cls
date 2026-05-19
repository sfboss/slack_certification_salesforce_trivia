/**
 * Centralized audit logger. Target_Id__c is a Text field so it accepts both Salesforce ids
 * and external identifiers (e.g., Slack user ids).
 */
public with sharing class AuditLogger {

    public static void log(String action, String targetType, String targetId, Object beforeObj, Object afterObj) {
        log(action, targetType, targetId, beforeObj, afterObj, null);
    }

    public static void log(String action, String targetType, String targetId, Object beforeObj, Object afterObj, String slackUserId) {
        try {
            Audit_Log__c row = new Audit_Log__c(
                Actor_Salesforce_User__c = UserInfo.getUserId(),
                Actor_Slack_User_Id__c = slackUserId,
                Action__c = action,
                Target_Type__c = targetType,
                Target_Id__c = targetId,
                Before_JSON__c = beforeObj == null ? null : JSON.serialize(beforeObj).left(32700),
                After_JSON__c = afterObj == null ? null : JSON.serialize(afterObj).left(32700),
                Occurred_At__c = System.now()
            );
            insert as system row;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, '[AuditLogger fallback] ' + action + ' ' + targetType + ' ' + targetId + ': ' + e.getMessage());
        }
    }

    // Convenience overload for Id-typed targets
    public static void log(String action, String targetType, Id targetId, Object beforeObj, Object afterObj, String slackUserId) {
        log(action, targetType, targetId == null ? null : String.valueOf(targetId), beforeObj, afterObj, slackUserId);
    }
}