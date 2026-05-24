import { LightningElement, api, track } from "lwc";
import load from "@salesforce/apex/CertGameBillingController.load";

export default class CertGameBilling extends LightningElement {
    @api recordId;
    @api tenantId;

    @track data;
    @track error;
    @track loading = false;

    connectedCallback() {
        this.fetch();
    }

    async fetch() {
        const id = this.recordId || this.tenantId;
        if (!id) {
            this.error =
                "No Tenant Id provided. Place this component on a Tenant__c record page or set the Tenant Id property.";
            return;
        }
        this.loading = true;
        this.error = undefined;
        try {
            this.data = await load({ tenantId: id });
        } catch (e) {
            this.error = this.msg(e);
            this.data = undefined;
        } finally {
            this.loading = false;
        }
    }

    get hasEvents() {
        return this.data && this.data.events && this.data.events.length > 0;
    }

    get planTiles() {
        if (!this.data || !this.data.plans) return [];
        const current = this.data.currentPlan;
        return this.data.plans.map((p) => ({
            ...p,
            isCurrent: p.plan === current,
            boxClass: `slds-col slds-size_1-of-1 slds-medium-size_1-of-3 slds-box ${p.plan === current ? "slds-theme_shade" : ""}`,
            tournamentsLabel: `Tournaments: ${p.tournaments ? "yes" : "no"}`,
            dynamicLabel: `Dynamic generation: ${p.dynamicGeneration ? "yes" : "no"}`,
            sponsorLabel: `Sponsor branding: ${p.sponsorBranding ? "yes" : "no"}`,
            ssoLabel: `SSO/SAML: ${p.ssoSaml ? "yes" : "no"}`,
            supportLabel: `Priority support: ${p.prioritySupport ? "yes" : "no"}`
        }));
    }

    get usageTiles() {
        const u = (this.data && this.data.usage) || {};
        return [
            { label: "Questions served", value: u.questionsServed || 0 },
            { label: "Games started", value: u.gamesStarted || 0 },
            { label: "Active players", value: u.activePlayers || 0 },
            { label: "LLM cost (USD)", value: `$${u.llmCostUsd || 0}` }
        ];
    }

    openPortal() {
        if (this.data && this.data.stripePortalUrl) {
            window.open(this.data.stripePortalUrl, "_blank", "noopener");
        }
    }

    msg(e) {
        return e && e.body && e.body.message
            ? e.body.message
            : e.message || "Unknown error";
    }
}