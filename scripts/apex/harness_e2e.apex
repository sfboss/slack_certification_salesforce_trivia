/**
 * Local end-to-end harness for every /certgame subcommand.
 *
 * Invokes the SAME path Slack uses (SlackRequestRouter.dispatch with a Slack-token
 * verification fallback) and prints the exact response body Slack would receive.
 *
 * Run:
 *   sf apex run -f scripts/apex/harness_e2e.apex -o certgame
 */

String TEAM_ID = 'T01EZ4J1T8F';
String USER_ID = 'U_HARNESS';
String CHANNEL = 'C_HARNESS';

// Use the same verification token configured in the Slack app — required for the
// router's token-based fallback (HMAC fails because Sites strips the raw body).
String VERIFICATION_TOKEN = 'kNrZKYvNP23ZthaI0PS7YdBO';

List<String> SUBCOMMANDS = new List<String>{
    'help', 'play', 'leaderboard', 'stats', 'plan', 'billing', 'debug', 'garbage'
};

System.debug('================ HARNESS START ================');

for (String sub : SUBCOMMANDS) {
    String triggerId = String.valueOf(DateTime.now().getTime()) + '.harness.' + sub;
    Map<String, String> form = new Map<String, String>{
        'token' => VERIFICATION_TOKEN,
        'team_id' => TEAM_ID,
        'team_domain' => 'sfdcbossworkspace',
        'channel_id' => CHANNEL,
        'channel_name' => 'directmessage',
        'user_id' => USER_ID,
        'user_name' => 'harness',
        'command' => '/certgame',
        'text' => sub,
        'api_app_id' => 'A_HARNESS',
        'response_url' => 'https://hooks.slack.example/x',
        'trigger_id' => triggerId
    };
    List<String> parts = new List<String>();
    for (String k : form.keySet()) {
        parts.add(EncodingUtil.urlEncode(k, 'UTF-8') + '=' + EncodingUtil.urlEncode(form.get(k), 'UTF-8'));
    }
    String body = String.join(parts, '&');
    Map<String, String> headers = new Map<String, String>{
        'X-Slack-Request-Timestamp' => String.valueOf(DateTime.now().getTime() / 1000),
        'X-Slack-Signature' => 'v0=invalid_will_fall_back_to_token',
        'Content-Type' => 'application/x-www-form-urlencoded'
    };

    System.debug('---------- /certgame ' + sub + ' ----------');
    Long t0 = System.currentTimeMillis();
    SlackRequestRouter.RouterResult r;
    try {
        r = SlackRequestRouter.dispatch(headers, body, 'application/x-www-form-urlencoded');
    } catch (Exception e) {
        System.debug('HARNESS EXCEPTION: ' + e.getTypeName() + ': ' + e.getMessage());
        continue;
    }
    Long elapsed = System.currentTimeMillis() - t0;
    System.debug('status=' + r.statusCode + ' elapsedMs=' + elapsed);
    String preview = r.body == null ? '<null>' : r.body;
    if (preview.length() > 1200) preview = preview.substring(0, 1200) + '...[truncated ' + (r.body.length() - 1200) + ' chars]';
    System.debug('body=' + preview);

    // Quick assertions to flag obvious failures
    if (r.statusCode != 200) System.debug('  !! non-200 statusCode');
    if (r.body == null || r.body == '') {
        // plan/billing return '' on success because they callout to views.open. That's fine.
        if (sub != 'plan' && sub != 'billing') System.debug('  !! empty body for sub=' + sub);
    } else {
        try {
            Object parsed = JSON.deserializeUntyped(r.body);
            if (parsed instanceof Map<String, Object>) {
                Map<String, Object> m = (Map<String, Object>) parsed;
                System.debug('  parsed: response_type=' + m.get('response_type')
                    + ' has_blocks=' + (m.get('blocks') != null)
                    + ' text=' + m.get('text'));
            }
        } catch (Exception je) {
            System.debug('  !! body is not JSON: ' + je.getMessage());
        }
    }
}

System.debug('================ HARNESS END ================');
System.debug('Last 10 App_Log__c rows:');
for (App_Log__c a : [
    SELECT Occurred_At__c, Level__c, Class_Name__c, Method_Name__c, Message__c, Correlation_Id__c
    FROM App_Log__c
    ORDER BY Occurred_At__c DESC LIMIT 10
]) {
    System.debug('[' + a.Level__c + '] ' + a.Class_Name__c + '.' + a.Method_Name__c
        + ' | ' + a.Message__c + ' | corr=' + a.Correlation_Id__c);
}
