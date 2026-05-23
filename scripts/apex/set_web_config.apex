// Sets Web_Google_Client_Id__c and Web_Session_Secret__c on App_Setting.Default via CMDT deployment.
String clientId = '996785802571-uiqssvghelteip5skm0f6kmcur270ih0.apps.googleusercontent.com';

Blob rnd = Crypto.generateAesKey(256);
String sessionSecret = EncodingUtil.convertToHex(rnd); // 64 hex chars

Metadata.CustomMetadata cm = new Metadata.CustomMetadata();
cm.fullName = 'App_Setting.Default';
cm.label = 'Default';

Metadata.CustomMetadataValue v1 = new Metadata.CustomMetadataValue();
v1.field = 'Web_Google_Client_Id__c';
v1.value = clientId;
cm.values.add(v1);

Metadata.CustomMetadataValue v2 = new Metadata.CustomMetadataValue();
v2.field = 'Web_Session_Secret__c';
v2.value = sessionSecret;
cm.values.add(v2);

Metadata.DeployContainer container = new Metadata.DeployContainer();
container.addMetadata(cm);

Id jobId = Metadata.Operations.enqueueDeployment(container, null);
System.debug('CMDT deployment enqueued: ' + jobId);
System.debug('clientId=' + clientId);
System.debug('sessionSecretLen=' + sessionSecret.length());
