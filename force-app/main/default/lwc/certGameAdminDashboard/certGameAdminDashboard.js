import { LightningElement, api, track } from 'lwc';
import load from '@salesforce/apex/CertGameAdminDashboardController.load';

export default class CertGameAdminDashboard extends LightningElement {
    @api tenantId;
    @track data;
    @track error;
    @track loading = false;

    connectedCallback() { this.fetch(); }

    async fetch() {
        this.loading = true;
        this.error = undefined;
        try {
            this.data = await load({ tenantId: this.tenantId || null });
        } catch (e) {
            this.error = this.msg(e);
            this.data = undefined;
        } finally {
            this.loading = false;
        }
    }

    handleRefresh() { this.fetch(); }

    get kpiTiles() {
        const k = this.data && this.data.kpis ? this.data.kpis : {};
        return [
            { label: 'Total players', value: k.totalPlayers || 0 },
            { label: 'Active (7d)', value: k.activePlayers7d || 0, sub: 'players who answered' },
            { label: 'Games started (7d)', value: k.gamesStarted7d || 0 },
            { label: 'Answers (7d)', value: k.questionsAnswered7d || 0, sub: `${k.accuracy7d || 0}% accuracy` },
            { label: 'Answers (30d)', value: k.questionsAnswered30d || 0 },
            { label: 'Published Qs', value: (this.data && this.data.questionHealth ? this.data.questionHealth.published : 0) || 0 },
            { label: 'Draft Qs', value: (this.data && this.data.questionHealth ? this.data.questionHealth.draft : 0) || 0 }
        ];
    }

    get healthTiles() {
        const h = this.data && this.data.questionHealth ? this.data.questionHealth : {};
        return [
            { label: 'Draft', value: h.draft || 0 },
            { label: 'Reviewed', value: h.reviewed || 0 },
            { label: 'Published', value: h.published || 0 },
            { label: 'Retired', value: h.retired || 0 },
            { label: 'Broken citations', value: h.brokenCitations || 0 },
            { label: 'Low quality', value: h.lowQuality || 0 }
        ];
    }

    get usageBars() {
        const u = this.data && this.data.usage ? this.data.usage : {};
        const bars = [];
        const push = (label, val, quota) => {
            if (!quota || quota <= 0) {
                bars.push({ label, text: `${val || 0}`, pct: 0, variant: 'base' });
                return;
            }
            const pct = Math.min(100, Math.round(((val || 0) * 100) / quota));
            const variant = pct >= 90 ? 'expired' : pct >= 70 ? 'warning' : 'base';
            bars.push({ label, text: `${val || 0} / ${quota}`, pct, variant });
        };
        push('Questions served', u.questionsServed, u.questionsServedQuota);
        push('Games started', u.gamesStarted, u.gamesQuota);
        push('Active players', u.activePlayers, 0);
        return bars;
    }

    get hasTopExams() { return this.data && this.data.topExams && this.data.topExams.length > 0; }
    get hasLicense() { return this.data && this.data.recentLicense && this.data.recentLicense.length > 0; }
    get hasErrors() { return this.data && this.data.recentErrors && this.data.recentErrors.length > 0; }
    get hasGenerations() { return this.data && this.data.recentGenerations && this.data.recentGenerations.length > 0; }
    get hasTenants() { return !this.tenantId && this.data && this.data.tenants && this.data.tenants.length > 0; }

    msg(e) { return e && e.body && e.body.message ? e.body.message : (e.message || 'Unknown error'); }
}