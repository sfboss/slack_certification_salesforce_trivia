// Mint signed Study Guide URLs for the first Player on file - one per active theme.
// Drop the printed URLs into a browser to confirm the rendered HTML.
List<Player__c> players = [SELECT Id, Display_Name__c, Tenant__c FROM Player__c LIMIT 1];
if (players.isEmpty()) {
    System.debug('No Player records yet - cannot mint a URL.');
    return;
}
Player__c p = players[0];
System.debug('Player: ' + p.Id + ' (' + p.Display_Name__c + ')');

List<Study_Guide_Theme__c> themes = [
    SELECT Theme_Key__c, Name FROM Study_Guide_Theme__c
    WHERE Active__c = true ORDER BY Is_Default__c DESC, Sort_Order__c ASC NULLS LAST
];
System.debug('=== Signed URLs (7-day expiry) ===');
System.debug('Default (no theme): ' + CertGameReadinessReportController.mintReportUrl(p.Id, null));
for (Study_Guide_Theme__c t : themes) {
    System.debug(t.Name + ' [' + t.Theme_Key__c + ']: ' + CertGameReadinessReportController.mintReportUrl(p.Id, null, t.Theme_Key__c));
}
System.debug('=== Demo preview (no token) ===');
String demoBase = Site.getBaseSecureUrl();
if (String.isBlank(demoBase)) demoBase = URL.getOrgDomainUrl().toExternalForm() + '/certgame';
System.debug('Demo URL: ' + demoBase + '/CertGameReadinessReport?demo=1');
