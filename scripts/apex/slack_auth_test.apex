HttpRequest req = new HttpRequest();
req.setEndpoint('callout:Slack_Bot/api/auth.test');
req.setMethod('POST');
req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
req.setBody('');
HttpResponse resp = new Http().send(req);
System.debug(resp.getStatusCode() + ' :: ' + resp.getBody());
