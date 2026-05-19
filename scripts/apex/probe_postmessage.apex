// Direct probe: call SlackApiClient.postMessage to the real user and dump Slack's response.
String userId = 'U01FAPQL1L5';
try {
    Map<String, Object> resp = SlackApiClient.postMessage(userId, 'probe ok',
        new List<Object>{
            new Map<String, Object>{
                'type' => 'section',
                'text' => new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => ':bell: probe at ' + System.now().format() }
            }
        }
    );
    System.debug('PROBE_RESP=' + JSON.serialize(resp));
} catch (Exception e) {
    System.debug('PROBE_EX=' + e.getTypeName() + ': ' + e.getMessage());
}
