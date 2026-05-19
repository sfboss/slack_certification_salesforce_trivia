@IsTest
private class AuditLogger_Test {
    @IsTest static void logsRow() {
        AuditLogger.log('TEST','Thing','x', null, new Map<String,Object>{'k'=>'v'});
        AuditLogger.log('TEST','Thing','x', null, null, 'U1');
        Integer c = [SELECT COUNT() FROM Audit_Log__c];
        System.assert(c >= 2);
    }
}