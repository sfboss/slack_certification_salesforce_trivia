List<Trivia_Question__c> qs = [SELECT Id, Status__c FROM Trivia_Question__c WHERE Status__c = 'Reviewed'];
for (Trivia_Question__c q : qs) q.Status__c = 'Published';
update qs;
System.debug('Published ' + qs.size() + ' questions');
