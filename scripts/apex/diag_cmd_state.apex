// 1. Data check for /certgame play
Integer exams = [SELECT COUNT() FROM Certification_Exam__c WHERE Active__c = true];
Integer pubQs = [SELECT COUNT() FROM Trivia_Question__c WHERE Status__c = 'Published'];
System.debug('ACTIVE_EXAMS=' + exams + ' PUBLISHED_QUESTIONS=' + pubQs);

// 2. Recent App_Log__c entries (errors when user ran commands)
for (App_Log__c l : [
    SELECT CreatedDate, Level__c, Class_Name__c, Method_Name__c, Message__c
    FROM App_Log__c ORDER BY CreatedDate DESC LIMIT 10
]) {
    System.debug('LOG ' + l.CreatedDate + ' ' + l.Level__c + ' ' + l.Class_Name__c + '.' + l.Method_Name__c + ' :: ' + l.Message__c);
}

// 3. Slack_Event_Log__c — proves slash command + button events actually reached Apex
for (Slack_Event_Log__c e : [
    SELECT CreatedDate, Event_Type__c, Slack_Team_Id__c FROM Slack_Event_Log__c
    ORDER BY CreatedDate DESC LIMIT 10
]) {
    System.debug('EV ' + e.CreatedDate + ' ' + e.Event_Type__c + ' team=' + e.Slack_Team_Id__c);
}
