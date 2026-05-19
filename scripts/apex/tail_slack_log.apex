List<App_Log__c> rows = [SELECT Occurred_At__c, Level__c, Class_Name__c, Method_Name__c, Message__c
                         FROM App_Log__c
                         WHERE Class_Name__c IN ('SlackEventsRestResource','SlackRequestRouter')
                         ORDER BY Occurred_At__c DESC LIMIT 20];
for (App_Log__c r : rows) {
    System.debug(r.Occurred_At__c + ' ' + r.Class_Name__c + '.' + r.Method_Name__c + ': ' + r.Message__c);
}
