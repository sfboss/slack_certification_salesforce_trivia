/**
 * Billing entry points: open billing modal, capture upgrade selection, hand off to Stripe.
 * Detailed Stripe webhook handling lives in StripeWebhookHandler.
 */
public with sharing class CertGameBillingService {
    public static String openBillingModal(
        String slackTeamId,
        String slackUserId,
        String triggerId
    ) {
        Tenant__c t = CertGameTenantService.getOrCreateTenant(slackTeamId);
        Map<String, Object> view = new Map<String, Object>{
            'type' => 'modal',
            'callback_id' => 'billing:upgrade',
            'title' => new Map<String, Object>{
                'type' => 'plain_text',
                'text' => 'Cert Game Billing'
            },
            'submit' => new Map<String, Object>{
                'type' => 'plain_text',
                'text' => 'Continue'
            },
            'close' => new Map<String, Object>{
                'type' => 'plain_text',
                'text' => 'Close'
            },
            'blocks' => new List<Object>{
                CertGameSlackRenderService.section(
                    'Current plan: *' + t.Plan__c + '*'
                ),
                new Map<String, Object>{
                    'type' => 'input',
                    'block_id' => 'plan_block',
                    'label' => new Map<String, Object>{
                        'type' => 'plain_text',
                        'text' => 'Select plan'
                    },
                    'element' => new Map<String, Object>{
                        'type' => 'static_select',
                        'action_id' => 'plan',
                        'options' => new List<Object>{
                            opt('Free', 'Free'),
                            opt('Pro', 'Pro'),
                            opt('Enterprise', 'Enterprise')
                        }
                    }
                }
            }
        };
        SlackApiClient.openView(triggerId, view);
        return '';
    }

    public static String handleUpgradeSubmission(
        String slackTeamId,
        String slackUserId,
        Map<String, Object> view
    ) {
        if (view == null)
            return '';
        Map<String, Object> stateWrap = (Map<String, Object>) view.get('state');
        if (stateWrap == null)
            return '';
        Map<String, Object> state = (Map<String, Object>) stateWrap.get(
            'values'
        );
        if (state == null)
            return '';
        Map<String, Object> planBlock = (Map<String, Object>) state.get(
            'plan_block'
        );
        if (planBlock == null)
            return '';
        Map<String, Object> plan = (Map<String, Object>) planBlock.get('plan');
        if (plan == null)
            return '';
        Map<String, Object> selected = (Map<String, Object>) plan.get(
            'selected_option'
        );
        String chosen = selected == null
            ? null
            : (String) selected.get('value');
        if (String.isBlank(chosen))
            return '';

        Tenant__c t = CertGameTenantService.getOrCreateTenant(slackTeamId);
        // For Free we update locally. For paid plans we record the intent; the Stripe Checkout link
        // is returned via DM. Actual plan change happens when the Stripe webhook fires.
        if (chosen == 'Free') {
            t.Plan__c = 'Free';
            update as system t;
            AuditLogger.log(
                'plan_change',
                'Tenant',
                t.Id,
                null,
                'Free',
                slackUserId
            );
        } else {
            AuditLogger.log(
                'plan_intent',
                'Tenant',
                t.Id,
                t.Plan__c,
                chosen,
                slackUserId
            );
        }
        return '';
    }

    private static Map<String, Object> opt(String label, String value) {
        return new Map<String, Object>{
            'text' => new Map<String, Object>{
                'type' => 'plain_text',
                'text' => label
            },
            'value' => value
        };
    }
}