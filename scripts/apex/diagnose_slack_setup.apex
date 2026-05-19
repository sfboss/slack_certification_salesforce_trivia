// Diagnose Slack endpoint setup
System.debug('=== MY DOMAIN ===');
System.debug(URL.getOrgDomainURL().toExternalForm());

System.debug('=== SITES ===');
for (Site s : [SELECT Id, Name, Subdomain, UrlPathPrefix, Status, GuestUserId, MasterLabel FROM Site]) {
  System.debug(s);
}
for (Domain d : [SELECT Id, DomainType, Domain FROM Domain]) {
  System.debug('Domain: ' + d.Domain + ' (' + d.DomainType + ')');
}

System.debug('=== GUEST USERS ===');
for (User u : [SELECT Id, Name, Username, IsActive, ProfileId, UserType FROM User WHERE UserType = 'Guest']) {
  System.debug(u);
}

System.debug('=== GUEST PERMSET ASSIGNMENTS ===');
for (PermissionSetAssignment psa : [
  SELECT Id, PermissionSet.Name, AssigneeId, Assignee.Name, Assignee.UserType
  FROM PermissionSetAssignment
  WHERE Assignee.UserType = 'Guest'
]) {
  System.debug(psa.Assignee.Name + ' -> ' + psa.PermissionSet.Name);
}

System.debug('=== APP SETTING CMDT ===');
App_Setting__mdt s = App_Setting__mdt.getInstance('Default');
System.debug('Signing Secret set? ' + (String.isNotBlank(s.Slack_Signing_Secret__c)));
System.debug('Signing Secret length: ' + (s.Slack_Signing_Secret__c == null ? 0 : s.Slack_Signing_Secret__c.length()));
System.debug('Slack_Bot_NC: ' + s.Slack_Bot_Named_Credential__c);
System.debug('Slack_Signing_NC: ' + s.Slack_Signing_Secret_Named_Credential__c);
System.debug('Skew: ' + s.Slack_Timestamp_Skew_Seconds__c);

System.debug('=== RECENT APP LOGS ===');
for (App_Log__c log : [SELECT Name, Level__c, Class_Name__c, Message__c, Stack__c, CreatedDate
                       FROM App_Log__c
                       ORDER BY CreatedDate DESC LIMIT 20]) {
  System.debug(log.CreatedDate + ' [' + log.Level__c + '] ' + log.Class_Name__c + ': ' + log.Message__c);
  if (log.Stack__c != null) System.debug('  stack: ' + log.Stack__c.left(300));
}

System.debug('=== RECENT SLACK EVENT LOGS ===');
for (Slack_Event_Log__c e : [SELECT Slack_Event_Id__c, Event_Type__c, Processed__c, Processing_Error__c, Slack_Team_Id__c, CreatedDate
                             FROM Slack_Event_Log__c
                             ORDER BY CreatedDate DESC LIMIT 10]) {
  System.debug(e.CreatedDate + ' type=' + e.Event_Type__c + ' processed=' + e.Processed__c + ' id=' + e.Slack_Event_Id__c + ' team=' + e.Slack_Team_Id__c + ' err=' + e.Processing_Error__c);
}
