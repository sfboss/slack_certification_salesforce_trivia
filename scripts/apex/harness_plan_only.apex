// Isolated: only invoke /certgame plan. Confirms no DML occurs before the views.open callout
// (any failure here would mean a real prod bug, not a harness ordering artifact).
String TEAM_ID = 'T01EZ4J1T8F';
String VTOKEN = 'kNrZKYvNP23ZthaI0PS7YdBO';
Map<String, String> form = new Map<String, String>{
    'token' => VTOKEN, 'team_id' => TEAM_ID, 'channel_id' => 'C_ISO', 'user_id' => 'U_ISO',
    'command' => '/certgame', 'text' => 'plan',
    'trigger_id' => String.valueOf(DateTime.now().getTime()) + '.iso.plan'
};
List<String> parts = new List<String>();
for (String k : form.keySet()) parts.add(EncodingUtil.urlEncode(k,'UTF-8')+'='+EncodingUtil.urlEncode(form.get(k),'UTF-8'));
String body = String.join(parts,'&');
Map<String,String> headers = new Map<String,String>{
    'X-Slack-Request-Timestamp'=>String.valueOf(DateTime.now().getTime()/1000),
    'X-Slack-Signature'=>'v0=fallback',
    'Content-Type'=>'application/x-www-form-urlencoded'
};
SlackRequestRouter.RouterResult r = SlackRequestRouter.dispatch(headers, body, 'application/x-www-form-urlencoded');
System.debug('STATUS=' + r.statusCode);
System.debug('BODY=' + r.body);
