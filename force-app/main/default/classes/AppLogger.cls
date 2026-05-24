public with sharing class AppLogger {
    public enum Level {
        DEBUG_LVL,
        INFO_LVL,
        WARN_LVL,
        ERROR_LVL
    }

    public static void info(String cls, String method, String msg) {
        write('INFO', cls, method, msg, null, null);
    }
    public static void warn(String cls, String method, String msg) {
        write('WARN', cls, method, msg, null, null);
    }

    public static String currentCorrelationId() {
        return Request.getCurrent() == null
            ? null
            : Request.getCurrent().getRequestId();
    }
    public static void error(
        String cls,
        String method,
        String msg,
        Exception e
    ) {
        String fullMsg = msg;
        String stack = null;
        if (e != null) {
            fullMsg =
                (msg == null ? '' : msg + ' :: ') +
                e.getTypeName() +
                ': ' +
                e.getMessage();
            stack = e.getStackTraceString();
        }
        write('ERROR', cls, method, fullMsg, stack, null);
    }
    public static void info(
        String cls,
        String method,
        String msg,
        Id tenantId
    ) {
        write('INFO', cls, method, msg, null, tenantId);
    }

    /**
     * Async logger safe to call from inside a callout chain. Use this from code that
     * makes Slack/HTTP callouts where a synchronous insert would trip "uncommitted
     * work pending" on a follow-up retry or sibling callout.
     */
    @future
    public static void writeAsync(
        String level,
        String cls,
        String method,
        String msg,
        String stack
    ) {
        write(level, cls, method, msg, stack, null);
    }

    /**
     * Logs synchronously if already in an async context (where @future cannot be
     * invoked), otherwise enqueues writeAsync. Use this from code that may run
     * either sync or async (e.g., SlackApiClient.call which runs from REST and
     * from @future callout wrappers).
     */
    public static void writeSafe(
        String level,
        String cls,
        String method,
        String msg,
        String stack
    ) {
        if (
            System.isFuture() ||
            System.isBatch() ||
            System.isQueueable() ||
            System.isScheduled()
        ) {
            write(level, cls, method, msg, stack, null);
        } else {
            writeAsync(level, cls, method, msg, stack);
        }
    }

    private static void write(
        String level,
        String cls,
        String method,
        String msg,
        String stack,
        Id tenantId
    ) {
        try {
            App_Log__c row = new App_Log__c(
                Level__c = level,
                Class_Name__c = cls,
                Method_Name__c = method,
                Message__c = msg == null ? null : msg.left(32700),
                Stack__c = stack == null ? null : stack.left(32700),
                Tenant__c = tenantId,
                Correlation_Id__c = Request.getCurrent() == null
                    ? null
                    : Request.getCurrent().getRequestId(),
                Occurred_At__c = System.now()
            );
            insert as system row;
        } catch (Exception ignored) {
            System.debug(
                LoggingLevel.ERROR,
                '[AppLogger fallback] ' +
                    level +
                    ' ' +
                    cls +
                    '.' +
                    method +
                    ': ' +
                    msg
            );
        }
    }
}