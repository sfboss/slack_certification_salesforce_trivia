// Verify our HMAC math matches what we sent over curl.
String secret = AppSettings.get().Slack_Signing_Secret__c;
System.debug('SECRET_LEN=' + (secret == null ? 0 : secret.length()));
System.debug('SECRET=' + secret);

String ts = '1779007722';
String body = 'token=deprecated&team_id=T01EZ4J1T8F&team_domain=testworkspace&channel_id=C0000TEST&channel_name=general&user_id=U0000TEST&user_name=tester&command=%2Fcertgame&text=help&response_url=https%3A%2F%2Fhooks.slack.com%2Fcommands%2FT0%2F0%2Fx&trigger_id=trig-1779007722&api_app_id=A00000TEST';
String basestring = 'v0:' + ts + ':' + body;
Blob mac = Crypto.generateMac('HmacSHA256', Blob.valueOf(basestring), Blob.valueOf(secret));
System.debug('EXPECTED_SIG=v0=' + EncodingUtil.convertToHex(mac));
System.debug('CLIENT_SIG=  v0=3303092b9da42f8e9e9f614eb0898ae1cbcea9f8819cd8c39187971995ca34f6');
