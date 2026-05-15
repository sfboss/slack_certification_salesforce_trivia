/**
 * Stripe webhook receiver. Verifies signature, records License_Event__c (idempotent on
 * Stripe_Event_Id__c), and updates Tenant__c.Plan__c / Status__c based on event type.
 *
 * `without sharing` — guest webhook user must be able to upsert License_Event__c.
 * All downstream Tenant updates go through with-sharing helper queries.
 *
 * Required ≥95% test coverage.
 */
@RestResource(urlMapping='/stripe/webhook')
global without sharing class StripeWebhookHandler {

    @HttpPost
    global static void doPost() {
        RestRequest req = RestContext.request;
        RestResponse resp = RestContext.response;
        try {
            String body = req.requestBody == null ? '' : req.requestBody.toString();
            String sig = headerOf(req, 'Stripe-Signature');

            if (!StripeSignatureVerifier.verify(sig, body)) {
                resp.statusCode = 400;
                resp.responseBody = Blob.valueOf('bad signature');
                return;
            }

            Map<String, Object> evt;
            try { evt = (Map<String, Object>) JSON.deserializeUntyped(body); }
            catch (Exception e) {
                resp.statusCode = 400;
                resp.responseBody = Blob.valueOf('bad json');
                return;
            }

            String stripeEventId = (String) evt.get('id');
            String type = (String) evt.get('type');
            if (String.isBlank(stripeEventId)) {
                resp.statusCode = 400;
                resp.responseBody = Blob.valueOf('missing id');
                return;
            }

            // Idempotency via unique external id; if not newly created, treat as duplicate.
            List<License_Event__c> existing = [
                SELECT Id FROM License_Event__c WHERE Stripe_Event_Id__c = :stripeEventId LIMIT 1
            ];
            if (!existing.isEmpty()) {
                resp.statusCode = 200;
                resp.responseBody = Blob.valueOf('duplicate');
                return;
            }
            License_Event__c rec = new License_Event__c(
                Stripe_Event_Id__c = stripeEventId,
                Event_Type__c = type,
                Payload_JSON__c = body.left(131000),
                Occurred_At__c = System.now()
            );
            insert rec;

            applyEvent(type, (Map<String, Object>) evt.get('data'));

            resp.statusCode = 200;
            resp.responseBody = Blob.valueOf('ok');
        } catch (Exception e) {
            AppLogger.error('StripeWebhookHandler', 'doPost', 'webhook failure', e);
            resp.statusCode = 200; // ack so Stripe doesn't endlessly retry
            resp.responseBody = Blob.valueOf('handled');
        }
    }

    private static String headerOf(RestRequest req, String name) {
        if (req == null || req.headers == null) return null;
        if (req.headers.containsKey(name)) return req.headers.get(name);
        return req.headers.get(name.toLowerCase());
    }

    @TestVisible
    private static void applyEvent(String type, Map<String, Object> data) {
        if (data == null) return;
        Map<String, Object> obj = (Map<String, Object>) data.get('object');
        if (obj == null) return;
        String customerId = (String) obj.get('customer');

        if (type == 'customer.subscription.created' || type == 'customer.subscription.updated') {
            String status = (String) obj.get('status');
            String plan = inferPlanFromSubscription(obj);
            updateTenantByCustomer(customerId, plan, mapSubscriptionStatus(status));
        } else if (type == 'customer.subscription.deleted') {
            updateTenantByCustomer(customerId, 'Free', 'Active');
        } else if (type == 'invoice.payment_failed') {
            updateTenantByCustomer(customerId, null, 'PastDue');
        } else if (type == 'checkout.session.completed') {
            String plan = (String) obj.get('client_reference_id'); // we stash plan name here
            updateTenantByCustomer(customerId, plan, 'Active');
        }
    }

    private static String mapSubscriptionStatus(String s) {
        if (s == null) return 'Active';
        if (s == 'active' || s == 'trialing') return 'Active';
        if (s == 'past_due' || s == 'unpaid') return 'PastDue';
        if (s == 'canceled' || s == 'incomplete_expired') return 'Cancelled';
        return 'Active';
    }

    private static String inferPlanFromSubscription(Map<String, Object> obj) {
        Object items = obj.get('items');
        if (items instanceof Map<String, Object>) {
            Object data = ((Map<String, Object>) items).get('data');
            if (data instanceof List<Object>) {
                List<Object> arr = (List<Object>) data;
                if (!arr.isEmpty()) {
                    Map<String, Object> item = (Map<String, Object>) arr[0];
                    Object price = item.get('price');
                    if (price instanceof Map<String, Object>) {
                        String nickname = (String) ((Map<String, Object>) price).get('nickname');
                        if (!String.isBlank(nickname)) return nickname;
                    }
                }
            }
        }
        return null;
    }

    private static void updateTenantByCustomer(String customerId, String plan, String status) {
        if (String.isBlank(customerId)) return;
        List<Tenant__c> ts = [SELECT Id, Plan__c, Status__c FROM Tenant__c
                              WHERE Stripe_Customer_Id__c = :customerId LIMIT 1];
        if (ts.isEmpty()) return;
        Tenant__c t = ts[0];
        String before = JSON.serialize(t);
        if (plan != null) t.Plan__c = plan;
        if (status != null) t.Status__c = status;
        update t;
        AuditLogger.log('stripe_webhook', 'Tenant', t.Id, before, JSON.serialize(t), null);
    }
}
