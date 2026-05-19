// Verify Slack bot callout works end-to-end (auth.test reflects token validity).
HttpRequest req = new HttpRequest();
req.setEndpoint('callout:Slack_Bot/api/auth.test');
req.setMethod('POST');
req.setHeader('Content-Type', 'application/json; charset=utf-8');
req.setBody('{}');
req.setTimeout(15000);
try {
    HttpResponse resp = new Http().send(req);
    System.debug('STATUS=' + resp.getStatusCode());
    System.debug('BODY=' + resp.getBody());
} catch (Exception e) {
    System.debug('EX=' + e.getTypeName() + ' :: ' + e.getMessage());
}

// And check that guest user has the permission set assigned.
Id guestId = '005RK00000agpCfYAI';
for (PermissionSetAssignment psa : [
    SELECT PermissionSet.Name FROM PermissionSetAssignment WHERE AssigneeId = :guestId
]) {
    System.debug('PSA: ' + psa.PermissionSet.Name);
}
