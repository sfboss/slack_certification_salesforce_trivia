@IsTest
private class StripeWebhookHandler_Test {

    private static String hex(String secret, String data) {
        Blob mac = Crypto.generateMac('HmacSHA256', Blob.valueOf(data), Blob.valueOf(secret));
        return EncodingUtil.convertToHex(mac);
    }

    private static RestRequest buildRequest(String body, String sig) {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/stripe/webhook';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(body);
        req.headers.put('Stripe-Signature', sig);
        RestContext.request = req;
        RestContext.response = new RestResponse();
        return req;
    }

    private static String signedHeader(String body) {
        Long ts = System.currentTimeMillis() / 1000L;
        return 't=' + ts + ',v1=' + hex('whsec', ts + '.' + body);
    }

    @TestSetup static void setup() {
        insert new Tenant__c(
            Slack_Team_Id__c = 'T_STRIPE', Workspace_Name__c = 'Stripe WS', Plan__c = 'Free',
            Status__c = 'Active', Installed_At__c = System.now(),
            Stripe_Customer_Id__c = 'cus_abc'
        );
    }

    @IsTest static void badSignatureReturns400() {
        StripeSignatureVerifier.secretOverride = 'whsec';
        buildRequest('{"id":"evt_1","type":"x"}', 't=1,v1=deadbeef');
        StripeWebhookHandler.doPost();
        System.assertEquals(400, RestContext.response.statusCode);
    }

    @IsTest static void badJsonReturns400() {
        StripeSignatureVerifier.secretOverride = 'whsec';
        String body = 'not-json';
        buildRequest(body, signedHeader(body));
        StripeWebhookHandler.doPost();
        System.assertEquals(400, RestContext.response.statusCode);
    }

    @IsTest static void missingEventIdReturns400() {
        StripeSignatureVerifier.secretOverride = 'whsec';
        String body = '{"type":"x"}';
        buildRequest(body, signedHeader(body));
        StripeWebhookHandler.doPost();
        System.assertEquals(400, RestContext.response.statusCode);
    }

    @IsTest static void subscriptionCreatedUpdatesPlan() {
        StripeSignatureVerifier.secretOverride = 'whsec';
        Map<String,Object> evt = new Map<String,Object>{
            'id' => 'evt_sub_1',
            'type' => 'customer.subscription.created',
            'data' => new Map<String,Object>{
                'object' => new Map<String,Object>{
                    'customer' => 'cus_abc',
                    'status' => 'active',
                    'items' => new Map<String,Object>{
                        'data' => new List<Object>{ new Map<String,Object>{
                            'price' => new Map<String,Object>{ 'nickname' => 'Pro' }
                        }}
                    }
                }
            }
        };
        String body = JSON.serialize(evt);
        buildRequest(body, signedHeader(body));
        Test.startTest();
        StripeWebhookHandler.doPost();
        Test.stopTest();
        System.assertEquals(200, RestContext.response.statusCode);
        Tenant__c t = [SELECT Plan__c, Status__c FROM Tenant__c WHERE Stripe_Customer_Id__c = 'cus_abc'];
        System.assertEquals('Pro', t.Plan__c);
        System.assertEquals('Active', t.Status__c);
    }

    @IsTest static void duplicateEventIsAck() {
        StripeSignatureVerifier.secretOverride = 'whsec';
        insert new License_Event__c(
            Stripe_Event_Id__c = 'evt_dup_1', Event_Type__c = 'Other',
            Payload_JSON__c = '{}', Occurred_At__c = System.now()
        );
        String body = JSON.serialize(new Map<String,Object>{ 'id' => 'evt_dup_1', 'type' => 'customer.subscription.deleted', 'data' => new Map<String,Object>{ 'object' => new Map<String,Object>{ 'customer' => 'cus_abc' } } });
        buildRequest(body, signedHeader(body));
        StripeWebhookHandler.doPost();
        System.assertEquals(200, RestContext.response.statusCode);
        System.assertEquals('duplicate', RestContext.response.responseBody.toString());
    }

    @IsTest static void subscriptionDeletedDowngradesToFree() {
        StripeSignatureVerifier.secretOverride = 'whsec';
        String body = JSON.serialize(new Map<String,Object>{
            'id' => 'evt_del_1', 'type' => 'customer.subscription.deleted',
            'data' => new Map<String,Object>{ 'object' => new Map<String,Object>{ 'customer' => 'cus_abc' } }
        });
        buildRequest(body, signedHeader(body));
        StripeWebhookHandler.doPost();
        Tenant__c t = [SELECT Plan__c FROM Tenant__c WHERE Stripe_Customer_Id__c = 'cus_abc'];
        System.assertEquals('Free', t.Plan__c);
    }

    @IsTest static void invoicePaymentFailedMarksPastDue() {
        StripeSignatureVerifier.secretOverride = 'whsec';
        String body = JSON.serialize(new Map<String,Object>{
            'id' => 'evt_fail_1', 'type' => 'invoice.payment_failed',
            'data' => new Map<String,Object>{ 'object' => new Map<String,Object>{ 'customer' => 'cus_abc' } }
        });
        buildRequest(body, signedHeader(body));
        StripeWebhookHandler.doPost();
        Tenant__c t = [SELECT Status__c FROM Tenant__c WHERE Stripe_Customer_Id__c = 'cus_abc'];
        System.assertEquals('PastDue', t.Status__c);
    }

    @IsTest static void subscriptionPastDueStatusMapped() {
        StripeSignatureVerifier.secretOverride = 'whsec';
        String body = JSON.serialize(new Map<String,Object>{
            'id' => 'evt_pd_1', 'type' => 'customer.subscription.updated',
            'data' => new Map<String,Object>{ 'object' => new Map<String,Object>{
                'customer' => 'cus_abc', 'status' => 'past_due'
            }}
        });
        buildRequest(body, signedHeader(body));
        StripeWebhookHandler.doPost();
        Tenant__c t = [SELECT Status__c FROM Tenant__c WHERE Stripe_Customer_Id__c = 'cus_abc'];
        System.assertEquals('PastDue', t.Status__c);
    }

    @IsTest static void subscriptionCanceledStatusMapped() {
        StripeSignatureVerifier.secretOverride = 'whsec';
        String body = JSON.serialize(new Map<String,Object>{
            'id' => 'evt_cx_1', 'type' => 'customer.subscription.updated',
            'data' => new Map<String,Object>{ 'object' => new Map<String,Object>{
                'customer' => 'cus_abc', 'status' => 'canceled'
            }}
        });
        buildRequest(body, signedHeader(body));
        StripeWebhookHandler.doPost();
        Tenant__c t = [SELECT Status__c FROM Tenant__c WHERE Stripe_Customer_Id__c = 'cus_abc'];
        System.assertEquals('Cancelled', t.Status__c);
    }

    @IsTest static void applyEventBlankCustomerNoop() {
        // Hits updateTenantByCustomer early return for blank customerId, and applyEvent null guards.
        StripeWebhookHandler.applyEvent('customer.subscription.deleted',
            new Map<String,Object>{ 'object' => new Map<String,Object>{ 'customer' => '' } });
        StripeWebhookHandler.applyEvent('customer.subscription.deleted', null);
        StripeWebhookHandler.applyEvent('customer.subscription.deleted',
            new Map<String,Object>{ 'object' => null });
    }

    @IsTest static void nullRequestCaughtAsHandled() {
        // Exercises catch block: request is null, response captures 'handled' ack.
        RestContext.request = null;
        RestContext.response = new RestResponse();
        StripeWebhookHandler.doPost();
        System.assertEquals(200, RestContext.response.statusCode);
        System.assertEquals('handled', RestContext.response.responseBody.toString());
    }

    @IsTest static void checkoutCompletedSetsPlan() {
        StripeSignatureVerifier.secretOverride = 'whsec';
        String body = JSON.serialize(new Map<String,Object>{
            'id' => 'evt_co_1', 'type' => 'checkout.session.completed',
            'data' => new Map<String,Object>{ 'object' => new Map<String,Object>{
                'customer' => 'cus_abc', 'client_reference_id' => 'Enterprise'
            }}
        });
        buildRequest(body, signedHeader(body));
        StripeWebhookHandler.doPost();
        Tenant__c t = [SELECT Plan__c FROM Tenant__c WHERE Stripe_Customer_Id__c = 'cus_abc'];
        System.assertEquals('Enterprise', t.Plan__c);
    }
}
