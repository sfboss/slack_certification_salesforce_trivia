public with sharing class AppLogger {
    public enum Level { DEBUG_LVL, INFO_LVL, WARN_LVL, ERROR_LVL }

    public static void info(String cls, String method, String msg) { write('INFO', cls, method, msg, null, null); }
    public static void warn(String cls, String method, String msg) { write('WARN', cls, method, msg, null, null); }
    public static void error(String cls, String method, String msg, Exception e) {
        write('ERROR', cls, method, msg, e == null ? null : e.getStackTraceString(), null);
    }
    public static void info(String cls, String method, String msg, Id tenantId) { write('INFO', cls, method, msg, null, tenantId); }

    private static void write(String level, String cls, String method, String msg, String stack, Id tenantId) {
        try {
            App_Log__c row = new App_Log__c(
                Level__c = level,
                Class_Name__c = cls,
                Method_Name__c = method,
                Message__c = msg == null ? null : msg.left(32700),
                Stack__c = stack == null ? null : stack.left(32700),
                Tenant__c = tenantId,
                Correlation_Id__c = Request.getCurrent() == null ? null : Request.getCurrent().getRequestId(),
                Occurred_At__c = System.now()
            );
            insert as system row;
        } catch (Exception ignored) {
            System.debug(LoggingLevel.ERROR, '[AppLogger fallback] ' + level + ' ' + cls + '.' + method + ': ' + msg);
        }
    }
}
