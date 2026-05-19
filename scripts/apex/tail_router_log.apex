List<App_Log__c> rows = [SELECT Occurred_At__c, Level__c, Class_Name__c, Method_Name__c, Message__c
                          FROM App_Log__c
                          WHERE Class_Name__c = 'SlackRequestRouter'
                          ORDER BY Occurred_At__c DESC
                          LIMIT 3];
for (App_Log__c r : rows) {
    System.debug('---');
    System.debug(r.Occurred_At__c + ' ' + r.Level__c + ' ' + r.Method_Name__c);
    System.debug(r.Message__c);
}
